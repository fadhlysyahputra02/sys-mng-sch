import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/data/student_service.dart';

class TeacherStudentViolationsPage extends StatefulWidget {
  final String teacherId;
  const TeacherStudentViolationsPage({super.key, required this.teacherId});

  @override
  State<TeacherStudentViolationsPage> createState() => _TeacherStudentViolationsPageState();
}

class _TeacherStudentViolationsPageState extends State<TeacherStudentViolationsPage> {
  final _studentService = StudentService();
  final _formKey = GlobalKey<FormState>();

  // State variables
  String? _selectedStudentId;
  String? _selectedStudentName;
  String? _selectedClassName;
  
  String _selectedJenis = 'Terlambat';
  final _searchStudentController = TextEditingController();
  final _customJenisController = TextEditingController();
  final _poinController = TextEditingController(text: '10');
  final _keteranganController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String _studentSearchQuery = '';
  XFile? _selectedImage;

  final List<String> _jenisOptions = [
    'Terlambat',
    'Atribut Tidak Lengkap',
    'Merusak Fasilitas Sekolah',
    'Berkelahi / Kekerasan',
    'Menyontek / Kecurangan Akademik',
    'Tidak Mengerjakan Tugas',
    'Membawa Barang Terlarang',
    'Lainnya (Tulis manual)'
  ];

  @override
  void dispose() {
    _searchStudentController.dispose();
    _customJenisController.dispose();
    _poinController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = AuthBackground.isDarkMode.value;
        return Theme(
          data: isDark ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Color(0xFF0F0C20),
              onSurface: Colors.white,
            ),
          ) : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E1B4B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (picked != null) {
        // Tampilkan loading dialog sederhana selama pemrosesan gambar
        Get.dialog(
          const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF8B5CF6),
            ),
          ),
          barrierDismissible: false,
        );

        final processed = await _processImage(picked);
        
        Get.back(); // Tutup loading dialog

        setState(() {
          _selectedImage = processed;
        });
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Gagal',
        'Gagal memilih gambar: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    }
  }

  Future<XFile?> _processImage(XFile originalFile) async {
    try {
      final bytes = await originalFile.readAsBytes();
      var decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return originalFile;

      // 1. Potong gambar ke aspek rasio 4:5 (portrait) jika bertipe landscape/terlalu lebar
      final currentRatio = decodedImage.width / decodedImage.height;
      const targetRatio = 0.8; // 4:5 portrait
      if (currentRatio > targetRatio) {
        final cropWidth = (decodedImage.height * targetRatio).toInt();
        final cropHeight = decodedImage.height;
        final startX = ((decodedImage.width - cropWidth) / 2).toInt();
        final startY = 0;
        decodedImage = img.copyCrop(
          decodedImage,
          x: startX,
          y: startY,
          width: cropWidth,
          height: cropHeight,
        );
      }

      // 2. Tambahkan watermark tanggal, hari, dan waktu di bagian bawah gambar
      final now = DateTime.now();
      final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      final dayName = days[now.weekday % 7];
      final dateText = '$dayName, ${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final font = decodedImage.width > 1200
          ? img.arial48
          : (decodedImage.width > 600 ? img.arial24 : img.arial14);

      final textHeight = font.lineHeight;
      final padding = 16;
      final rectHeight = textHeight + (padding * 2);

      img.fillRect(
        decodedImage,
        x1: 0,
        y1: (decodedImage.height - rectHeight).toInt(),
        x2: decodedImage.width,
        y2: decodedImage.height,
        color: img.ColorRgba8(0, 0, 0, 150),
      );

      img.drawString(
        decodedImage,
        dateText,
        font: font,
        x: padding,
        y: (decodedImage.height - rectHeight + padding).toInt(),
        color: img.ColorRgb8(255, 255, 255),
      );

      // 3. Simpan gambar hasil pemrosesan ke file sementara
      final modifiedBytes = img.encodeJpg(decodedImage, quality: 80);
      
      if (kIsWeb) {
        return XFile.fromData(
          Uint8List.fromList(modifiedBytes),
          mimeType: 'image/jpeg',
          name: originalFile.name,
        );
      } else {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(modifiedBytes);
        return XFile(tempFile.path);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      return originalFile;
    }
  }

  void _showImagePickerOptions() {
    final isDark = AuthBackground.isDarkMode.value;
    final bgColor = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih Sumber Foto Bukti',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: const Color(0xFF8B5CF6)),
              title: Text('Kamera Langsung', style: TextStyle(color: textColor)),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: const Color(0xFF8B5CF6)),
              title: Text('Pilih dari Galeri', style: TextStyle(color: textColor)),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveViolation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudentId == null) {
      Get.snackbar(
        'Peringatan',
        'Silakan pilih murid terlebih dahulu.',
        backgroundColor: Colors.amber,
        colorText: const Color(0xFF1E1B4B),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = SessionService.currentUser!;
      final jenisPelanggaran = _selectedJenis == 'Lainnya (Tulis manual)'
          ? _customJenisController.text.trim()
          : _selectedJenis;
      final poin = int.tryParse(_poinController.text) ?? 10;

      await _studentService.addStudentViolation(
        schoolId: user.schoolId,
        studentId: _selectedStudentId!,
        studentName: _selectedStudentName!,
        className: _selectedClassName ?? 'Tanpa Kelas',
        jenis: jenisPelanggaran,
        poin: poin,
        keterangan: _keteranganController.text.trim(),
        date: _selectedDate,
        recordedBy: user.nama,
        imageFile: _selectedImage,
      );

      // Reset form
      setState(() {
        _selectedStudentId = null;
        _selectedStudentName = null;
        _selectedClassName = null;
        _searchStudentController.clear();
        _studentSearchQuery = '';
        _keteranganController.clear();
        _customJenisController.clear();
        _selectedJenis = 'Terlambat';
        _poinController.text = '10';
        _selectedDate = DateTime.now();
        _selectedImage = null;
      });

      Get.snackbar(
        'Sukses',
        'Pelanggaran murid berhasil dicatat.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mencatat pelanggaran: $e',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    leading: Container(
                      margin: const EdgeInsets.only(left: 16),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    title: Text(
                      'Input Pelanggaran Murid',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. SEARCH STUDENT TEXTFIELD OR SELECTED STUDENT CARD
                            Text(
                              'Cari Murid',
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),

                            if (_selectedStudentId != null) ...[
                              // Selected Student Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                                  boxShadow: isDark ? [] : [
                                    BoxShadow(
                                      color: shadowColor,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6), size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedStudentName!,
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Kelas: ${_selectedClassName ?? "Tanpa Kelas"}',
                                            style: TextStyle(color: subTextColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear_rounded, color: Color(0xFFEF4444)),
                                      onPressed: () {
                                        setState(() {
                                          _selectedStudentId = null;
                                          _selectedStudentName = null;
                                          _selectedClassName = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ] else ...[
                              // Search Input field
                              TextField(
                                controller: _searchStudentController,
                                onChanged: (val) {
                                  setState(() {
                                    _studentSearchQuery = val.toLowerCase();
                                  });
                                },
                                style: TextStyle(color: textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Cari nama atau NIS murid...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                                  prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                                  fillColor: inputFillColor,
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Real-time Student List (Filtered)
                              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: _studentService.getStudentsBySchool(user.schoolId),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                                      ),
                                    );
                                  }

                                  final docs = snapshot.data?.docs ?? [];
                                  final filteredDocs = docs.where((doc) {
                                    final data = doc.data();
                                    final nama = (data['nama'] ?? '').toString().toLowerCase();
                                    final nis = (data['nis'] ?? '').toString().toLowerCase();
                                    return _studentSearchQuery.isNotEmpty && 
                                        (nama.contains(_studentSearchQuery) || nis.contains(_studentSearchQuery));
                                  }).take(5).toList();

                                  if (_studentSearchQuery.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'Ketikkan nama/nis murid untuk mulai mencari.',
                                        style: TextStyle(color: subTextColor, fontSize: 12, fontStyle: FontStyle.italic),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }

                                  if (filteredDocs.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'Murid tidak ditemukan.',
                                        style: TextStyle(color: subTextColor, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: cardBorderColor),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filteredDocs.length,
                                      separatorBuilder: (_, __) => Divider(color: cardBorderColor, height: 1),
                                      itemBuilder: (context, index) {
                                        final doc = filteredDocs[index];
                                        final data = doc.data();
                                        final name = data['nama'] ?? 'Tanpa Nama';
                                        final nis = data['nis'] ?? '-';
                                        final className = data['className'] ?? 'Tanpa Kelas';

                                        return ListTile(
                                          title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                          subtitle: Text('NIS: $nis • Kelas: $className', style: TextStyle(color: subTextColor, fontSize: 12)),
                                          trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
                                          onTap: () {
                                            setState(() {
                                              _selectedStudentId = doc.id;
                                              _selectedStudentName = name;
                                              _selectedClassName = className;
                                              _searchStudentController.clear();
                                              _studentSearchQuery = '';
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                            ],

                            // 2. FORM INPUTS (ONLY REVEALED WHEN STUDENT SELECTED)
                            if (_selectedStudentId != null) ...[
                              Text(
                                'Jenis Pelanggaran',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                style: TextStyle(color: textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  fillColor: inputFillColor,
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                value: _selectedJenis,
                                items: _jenisOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt,
                                    child: Text(opt),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedJenis = val!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              if (_selectedJenis == 'Lainnya (Tulis manual)') ...[
                                Text(
                                  'Tulis Pelanggaran',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _customJenisController,
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Masukkan jenis pelanggaran' : null,
                                  decoration: InputDecoration(
                                    hintText: 'Misal: Makan di kelas saat pelajaran',
                                    hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                                    fillColor: inputFillColor,
                                    filled: true,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: cardBorderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Poin Pelanggaran',
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _poinController,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(color: textColor, fontSize: 14),
                                          validator: (v) {
                                            if (v == null || v.isEmpty) return 'Masukkan poin';
                                            if (int.tryParse(v) == null) return 'Harus angka';
                                            return null;
                                          },
                                          decoration: InputDecoration(
                                            hintText: 'Misal: 10',
                                            hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                                            fillColor: inputFillColor,
                                            filled: true,
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: BorderSide(color: cardBorderColor),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Tanggal Pelanggaran',
                                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () => _selectDate(context),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                            decoration: BoxDecoration(
                                              color: inputFillColor,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: cardBorderColor),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                                  style: TextStyle(color: textColor, fontSize: 14),
                                                ),
                                                Icon(Icons.calendar_today_rounded, color: subTextColor, size: 18),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Text(
                                'Keterangan Tambahan',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _keteranganController,
                                style: TextStyle(color: textColor, fontSize: 14),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Tulis detail pelanggaran...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                                  fillColor: inputFillColor,
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Bukti Foto (Opsional)',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              if (_selectedImage != null)
                                Container(
                                  height: 180,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: cardBorderColor),
                                  ),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: double.infinity,
                                          child: kIsWeb
                                              ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                                              : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                                          child: IconButton(
                                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                                            onPressed: () {
                                              setState(() {
                                                _selectedImage = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                InkWell(
                                  onTap: _showImagePickerOptions,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    decoration: BoxDecoration(
                                      color: inputFillColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: cardBorderColor,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.add_a_photo_rounded,
                                          color: Color(0xFF8B5CF6),
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Unggah Bukti Foto',
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Kamera langsung atau pilih dari galeri',
                                          style: TextStyle(
                                            color: subTextColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 32),

                              ElevatedButton(
                                onPressed: _isSaving ? null : _saveViolation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Simpan Catatan Pelanggaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
