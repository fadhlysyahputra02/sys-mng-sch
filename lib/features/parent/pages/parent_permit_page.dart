import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';

class ParentPermitPage extends StatefulWidget {
  const ParentPermitPage({super.key});

  @override
  State<ParentPermitPage> createState() => _ParentPermitPageState();
}

class _ParentPermitPageState extends State<ParentPermitPage> {
  late String _studentId;
  late String _studentName;
  late String _classId;
  late String _className;
  late String _waliKelasId;
  late String _waliKelasName;

  bool _isArgumentsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isArgumentsLoaded) {
      final args = Get.arguments as Map<String, dynamic>? ?? {};
      _studentId = args['studentId']?.toString() ?? '';
      _studentName = args['studentName']?.toString() ?? 'Anak';
      _classId = args['classId']?.toString() ?? '';
      _className = args['className']?.toString() ?? '';
      _waliKelasId = args['waliKelasId']?.toString() ?? '';
      _waliKelasName = args['waliKelasName']?.toString() ?? 'Wali Kelas';
      _isArgumentsLoaded = true;
    }
  }

  // Permohonan Izin Form State
  final _reasonController = TextEditingController();
  String _jenisIzin = 'Sakit'; // Sakit / Izin
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? _buktiBase64;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 700,
        maxHeight: 700,
        imageQuality: 75,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _buktiBase64 = base64Encode(bytes));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih gambar: $e')),
      );
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        final isDark = AuthBackground.isDarkMode.value;
        return Theme(
          data: ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1),
              brightness: isDark ? Brightness.dark : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submitPermit() async {
    if (_reasonController.text.trim().isEmpty) {
      Get.snackbar('Validasi Gagal', 'Alasan izin wajib diisi.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    if (_waliKelasId.isEmpty) {
      Get.snackbar('Kirim Gagal', 'Anak Anda belum memiliki wali kelas. Hubungi pihak sekolah.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final parentId = SessionService.currentUser!.uid;
      final parentName = SessionService.currentUser!.nama;

      final dateRangeStr = _startDate == _endDate
          ? DateFormat('yyyy-MM-dd').format(_startDate)
          : '${DateFormat('yyyy-MM-dd').format(_startDate)} s.d ${DateFormat('yyyy-MM-dd').format(_endDate)}';

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('permits')
          .add({
        'studentId': _studentId,
        'studentName': _studentName,
        'classId': _classId,
        'className': _className,
        'parentId': parentId,
        'parentName': parentName,
        'teacherId': _waliKelasId,
        'teacherName': _waliKelasName,
        'jenis': _jenisIzin,
        'tanggalMulai': DateFormat('yyyy-MM-dd').format(_startDate),
        'tanggalSelesai': DateFormat('yyyy-MM-dd').format(_endDate),
        'alasan': _reasonController.text.trim(),
        'buktiBase64': _buktiBase64,
        'status': 'Pending', // Pending, Disetujui, Ditolak
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('notifications')
          .add({
        'title': 'Pengajuan Surat ${_jenisIzin}',
        'content': 'Siswa ${_studentName} mengajukan surat ${_jenisIzin.toLowerCase()} untuk tanggal $dateRangeStr dengan alasan: ${_reasonController.text.trim()}',
        'targetType': 'kelas',
        'targetId': _classId,
        'targetName': _className,
        'senderId': parentId,
        'senderName': parentName,
        'senderRole': 'parent',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _reasonController.clear();
      setState(() {
        _buktiBase64 = null;
        _startDate = DateTime.now();
        _endDate = DateTime.now();
        _jenisIzin = 'Sakit';
      });

      if (mounted) {
        Navigator.pop(context); // Tutup bottom sheet form
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Surat izin berhasil dikirim ke Wali Kelas.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal mengirim surat izin: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showNewPermitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = AuthBackground.isDarkMode.value;
            final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final sheetBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
            final fieldBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
            final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Buat Surat Izin Digital',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ditujukan kepada Wali Kelas: $_waliKelasName',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Divider(height: 32),

                      // Jenis Izin Selector
                      Text('Jenis Izin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Sakit')),
                              selected: _jenisIzin == 'Sakit',
                              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _jenisIzin == 'Sakit' ? const Color(0xFF6366F1) : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setSheetState(() => _jenisIzin = 'Sakit');
                                  setState(() => _jenisIzin = 'Sakit');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Izin')),
                              selected: _jenisIzin == 'Izin',
                              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _jenisIzin == 'Izin' ? const Color(0xFF6366F1) : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setSheetState(() => _jenisIzin = 'Izin');
                                  setState(() => _jenisIzin = 'Izin');
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Tanggal Selector
                      Text('Tanggal Absen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          await _selectDateRange();
                          setSheetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: fieldBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(Icons.calendar_today_rounded, color: textColor.withValues(alpha: 0.5), size: 20),
                              Text(
                                _startDate == _endDate
                                    ? DateFormat('dd MMM yyyy').format(_startDate)
                                    : '${DateFormat('dd MMM').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              ),
                              Icon(Icons.edit_calendar_rounded, color: const Color(0xFF6366F1), size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Alasan
                      Text('Alasan / Keterangan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _reasonController,
                        maxLines: 4,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Tulis alasan ketidakhadiran secara detail...',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                          filled: true,
                          fillColor: fieldBg,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                      const SizedBox(height: 20),

                      // Bukti / Lampiran Foto
                      Text('Lampiran Bukti (Opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      if (_buktiBase64 != null)
                        Stack(
                          children: [
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: fieldBorder),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(base64Decode(_buktiBase64!), fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withOpacity(0.6),
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () {
                                    setSheetState(() => _buktiBase64 = null);
                                    setState(() => _buktiBase64 = null);
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _pickImage();
                            setSheetState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                          ),
                          icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF6366F1)),
                          label: const Text('Unggah Surat Sakit / Foto Bukti', style: TextStyle(color: Color(0xFF6366F1))),
                        ),

                      const SizedBox(height: 32),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitPermit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Kirim Surat Izin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showPermitDetail(Map<String, dynamic> permit) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final isPending = permit['status'] == 'Pending';
    final isApproved = permit['status'] == 'Disetujui';
    final statusColor = isApproved
        ? const Color(0xFF10B981)
        : (isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detail Surat Izin',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  permit['status'] ?? 'Pending',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Jenis Izin', permit['jenis'] ?? '-', textColor),
                _buildInfoRow('Tanggal', '${permit['tanggalMulai']} s.d ${permit['tanggalSelesai']}', textColor),
                _buildInfoRow('Wali Kelas', permit['teacherName'] ?? '-', textColor),
                const Divider(height: 24),
                Text(
                  'Alasan / Keterangan:',
                  style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  permit['alasan'] ?? '-',
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                ),
                if (permit['buktiBase64'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Lampiran Bukti:',
                    style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        base64Decode(permit['buktiBase64']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String val, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(val, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Surat Izin Digital',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              Text(
                                'Anak: $_studentName • Wali Kelas: $_waliKelasName',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content List
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(schoolId)
                          .collection('permits')
                          .where('studentId', isEqualTo: _studentId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Gagal memuat riwayat: ${snapshot.error}',
                                style: const TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final docs = (snapshot.data?.docs ?? []).toList();

                        // Urutkan di memori (client-side) berdasarkan tanggal pembuatan terbaru
                        docs.sort((a, b) {
                          final aData = a.data();
                          final bData = b.data();
                          final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                          final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                          return bTime.compareTo(aTime);
                        });

                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mail_outline_rounded, size: 64, color: textColor.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada surat izin yang dikirim.',
                                  style: TextStyle(color: subTextColor, fontSize: 14),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _showNewPermitSheet,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Kirim Surat Izin', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final permit = docs[index].data();
                            final dateRange = permit['tanggalMulai'] == permit['tanggalSelesai']
                                ? permit['tanggalMulai']
                                : '${permit['tanggalMulai']} s.d ${permit['tanggalSelesai']}';
                            final type = permit['jenis'] ?? 'Sakit';
                            final isPending = permit['status'] == 'Pending';
                            final isApproved = permit['status'] == 'Disetujui';
                            final statusColor = isApproved
                                ? const Color(0xFF10B981)
                                : (isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorderColor),
                                boxShadow: isDark
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: (type == 'Sakit' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    type == 'Sakit' ? Icons.sick_rounded : Icons.info_rounded,
                                    color: type == 'Sakit' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      type,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        permit['status'] ?? 'Pending',
                                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tanggal: $dateRange',
                                      style: TextStyle(color: subTextColor, fontSize: 12),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ket: ${permit['alasan']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: Icon(Icons.arrow_forward_ios_rounded, color: textColor.withValues(alpha: 0.3), size: 16),
                                onTap: () => _showPermitDetail(permit),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showNewPermitSheet,
            backgroundColor: const Color(0xFF6366F1),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Kirim Surat Izin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
