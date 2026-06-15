import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import 'package:sys_mng_school/features/schools/pages/teachers/data/teacher_service.dart';
import 'package:sys_mng_school/features/authentication/widgets/auth_background.dart';

class CreateNotificationPage extends StatefulWidget {
  final String? teacherDocId;
  final Set<String>? teacherClassIds;

  const CreateNotificationPage({
    super.key,
    this.teacherDocId,
    this.teacherClassIds,
  });

  @override
  State<CreateNotificationPage> createState() => _CreateNotificationPageState();
}

class _CreateNotificationPageState extends State<CreateNotificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _targetType = 'umum'; // 'umum', 'kelas', 'guru', 'murid'
  String? _selectedTargetId;
  String? _selectedTargetName;
  String? _selectedTargetClassId;

  String? _teacherDocId;
  Set<String> _teacherClassIds = {};
  bool _isLoadingTeacherInfo = true;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _teacherDocId = widget.teacherDocId;
    _teacherClassIds = widget.teacherClassIds ?? {};

    final role = SessionService.currentUser!.role;

    if (role == 'teacher') {
      _targetType = 'kelas'; // Guru default target is kelas
      _loadTeacherInfo();
    } else {
      _isLoadingTeacherInfo = false;
    }
  }

  Future<void> _loadTeacherInfo() async {
    final user = SessionService.currentUser!;
    try {
      final schoolId = user.schoolId;
      final teacherDoc = await TeacherService().getTeacherByUid(schoolId, user.uid);
      if (teacherDoc != null) {
        _teacherDocId = teacherDoc.data()['teacherId'] ?? teacherDoc.id;

        // Fetch classes where wali kelas
        final waliKelasSnap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('classes')
            .where('teacherId', isEqualTo: _teacherDocId)
            .get();
        final waliClassIds = waliKelasSnap.docs
            .map((d) => d.id)
            .toSet();

        _teacherClassIds = waliClassIds;
      }
    } catch (e) {
      debugPrint('Error loading teacher info: $e');
    }
    if (mounted) {
      setState(() {
        _isLoadingTeacherInfo = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTargetTypeChanged(String? val) {
    if (val != null) {
      setState(() {
        _targetType = val;
        _selectedTargetId = null;
        _selectedTargetName = null;
        _selectedTargetClassId = null;
      });
    }
  }

  Future<void> _saveNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_targetType != 'umum' && _selectedTargetId == null) {
      Get.snackbar(
        'Peringatan',
        'Silakan pilih penerima spesifik terlebih dahulu',
        backgroundColor: Colors.amber.shade700,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = SessionService.currentUser!;
      final schoolId = user.schoolId;

      final Map<String, dynamic> dataToSave = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'targetType': _targetType,
        'targetId': _selectedTargetId,
        'targetName': _selectedTargetName,
        'senderId': user.uid,
        'senderName': user.nama,
        'senderRole': user.role,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_targetType == 'murid' && _selectedTargetClassId != null) {
        dataToSave['targetClassId'] = _selectedTargetClassId;
      }

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('notifications')
          .add(dataToSave);

      Get.back();
      Get.snackbar(
        'Sukses',
        'Notifikasi berhasil dipublikasikan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      Get.snackbar(
        'Error',
        'Gagal mempublikasikan notifikasi: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;
    final role = SessionService.currentUser!.role;
    const primaryIndigo = Color(0xFF8B5CF6);

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
        final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

        final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final textSecondaryColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
        final textLabelColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8);

        final fieldBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final hintColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
        final iconColor = isDark ? Colors.white54 : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final dropdownBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

        if (_isLoadingTeacherInfo) {
          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(isDark ? Colors.white : primaryIndigo),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: AuthBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: backButtonColor,
                elevation: 0,
                iconTheme: IconThemeData(color: backButtonColor),
                title: Text(
                  'Buat Notifikasi Baru',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                ),
              ),
              body: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Card Banner
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: primaryIndigo),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Notifikasi yang Anda buat akan langsung dipublikasikan kepada penerima terpilih secara real-time.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondaryColor,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Form Judul
                        Text(
                          'Judul Notifikasi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textLabelColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          style: TextStyle(color: textPrimaryColor),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Judul wajib diisi' : null,
                          decoration: InputDecoration(
                            hintText: 'Masukkan judul pengumuman...',
                            hintStyle: TextStyle(color: hintColor),
                            prefixIcon: Icon(Icons.title_rounded, color: iconColor),
                            filled: true,
                            fillColor: fieldBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: primaryIndigo, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form Isi
                        Text(
                          'Isi Notifikasi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textLabelColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _contentController,
                          style: TextStyle(color: textPrimaryColor),
                          validator: (val) => (val == null || val.trim().isEmpty) ? 'Isi notifikasi wajib diisi' : null,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Tuliskan pesan atau pengumuman secara detail di sini...',
                            hintStyle: TextStyle(color: hintColor),
                            filled: true,
                            fillColor: fieldBg,
                            contentPadding: const EdgeInsets.all(16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: primaryIndigo, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Form Tipe Penerima (Dropdown)
                        Text(
                          'Target Penerima',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textLabelColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _targetType,
                          dropdownColor: dropdownBg,
                          style: TextStyle(color: textPrimaryColor),
                          onChanged: _onTargetTypeChanged,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.people_outline_rounded, color: iconColor),
                            filled: true,
                            fillColor: fieldBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: fieldBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: primaryIndigo, width: 2),
                            ),
                          ),
                          items: role == 'teacher'
                              ? [
                                  DropdownMenuItem(value: 'kelas', child: Text('Kelas', style: TextStyle(color: textPrimaryColor))),
                                  DropdownMenuItem(value: 'murid', child: Text('Murid', style: TextStyle(color: textPrimaryColor))),
                                ]
                              : [
                                  DropdownMenuItem(value: 'umum', child: Text('Semua (Umum)', style: TextStyle(color: textPrimaryColor))),
                                  DropdownMenuItem(value: 'kelas', child: Text('Kelas', style: TextStyle(color: textPrimaryColor))),
                                  DropdownMenuItem(value: 'guru', child: Text('Guru', style: TextStyle(color: textPrimaryColor))),
                                  DropdownMenuItem(value: 'murid', child: Text('Murid', style: TextStyle(color: textPrimaryColor))),
                                ],
                        ),
                        const SizedBox(height: 20),

                        // Dynamic Recipient Selector based on _targetType
                        if (_targetType != 'umum') ...[
                          Text(
                            _targetType == 'kelas'
                                ? 'Pilih Kelas Penerima'
                                : _targetType == 'guru'
                                    ? 'Pilih Guru Penerima'
                                    : 'Pilih Murid Penerima',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textLabelColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRecipientDropdown(schoolId),
                          const SizedBox(height: 24),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryIndigo,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isSaving ? null : _saveNotification,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Publikasikan Notifikasi',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipientDropdown(String schoolId) {
    const primaryIndigo = Color(0xFF8B5CF6);
    final isDark = AuthBackground.isDarkMode.value;
    final role = SessionService.currentUser!.role;

    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondaryColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final fieldBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final hintColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final iconColor = isDark ? Colors.white54 : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
    final dropdownBg = isDark ? const Color(0xFF0F0C20) : Colors.white;

    String collection = 'classes';
    if (_targetType == 'guru') collection = 'teachers';
    if (_targetType == 'murid') collection = 'students';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection(collection)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('Gagal memuat data penerima', style: TextStyle(color: Colors.red)),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(isDark ? Colors.white : primaryIndigo),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        var filteredDocs = docs;

        if (role == 'teacher') {
          if (_targetType == 'kelas') {
            filteredDocs = docs.where((doc) => _teacherClassIds.contains(doc.id)).toList();
          } else if (_targetType == 'murid') {
            filteredDocs = docs.where((doc) => _teacherClassIds.contains(doc.data()['classId'] ?? '')).toList();
          }
        }

        if (filteredDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Text(
              _targetType == 'kelas'
                  ? 'Belum ada kelas yang Anda ajar'
                  : _targetType == 'guru'
                      ? 'Belum ada data guru terdaftar'
                      : 'Belum ada murid di kelas Anda',
              style: TextStyle(color: textSecondaryColor),
            ),
          );
        }

        // Map data to display text and values
        return DropdownButtonFormField<String>(
          value: filteredDocs.any((doc) => doc.id == _selectedTargetId) ? _selectedTargetId : null,
          dropdownColor: dropdownBg,
          style: TextStyle(color: textPrimaryColor),
          hint: Text(
            _targetType == 'kelas'
                ? 'Pilih Kelas'
                : _targetType == 'guru'
                    ? 'Pilih Guru'
                    : 'Pilih Murid',
            style: TextStyle(color: hintColor),
          ),
          onChanged: (val) {
            if (val != null) {
              final selectedDoc = filteredDocs.firstWhere((doc) => doc.id == val);
              setState(() {
                _selectedTargetId = val;
                if (_targetType == 'kelas') {
                  _selectedTargetName = selectedDoc.data()['namaKelas'] ?? '';
                  _selectedTargetClassId = null;
                } else if (_targetType == 'murid') {
                  _selectedTargetName = selectedDoc.data()['nama'] ?? '';
                  _selectedTargetClassId = selectedDoc.data()['classId'] ?? '';
                } else {
                  _selectedTargetName = selectedDoc.data()['nama'] ?? '';
                  _selectedTargetClassId = null;
                }
              });
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(
              _targetType == 'kelas'
                  ? Icons.class_rounded
                  : _targetType == 'guru'
                      ? Icons.person_pin_rounded
                      : Icons.portrait_rounded,
              color: iconColor,
            ),
            filled: true,
            fillColor: fieldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryIndigo, width: 2),
            ),
          ),
          items: filteredDocs.map((doc) {
            String name = '';
            if (_targetType == 'kelas') {
              name = doc.data()['namaKelas'] ?? '';
            } else {
              name = doc.data()['nama'] ?? '';
            }
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(name, style: TextStyle(color: textPrimaryColor)),
            );
          }).toList(),
        );
      },
    );
  }
}
