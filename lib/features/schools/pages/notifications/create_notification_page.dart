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

  // Untuk Multi-Select Murid
  Set<String> _selectedStudentIds = {};
  List<Map<String, dynamic>> _selectedStudentDetails = [];

  // Untuk Multi-Select Guru
  Set<String> _selectedTeacherIds = {};
  List<Map<String, dynamic>> _selectedTeacherDetails = [];

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
        _selectedStudentIds.clear();
        _selectedStudentDetails.clear();
        _selectedTeacherIds.clear();
        _selectedTeacherDetails.clear();
      });
    }
  }

  Future<void> _saveNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_targetType != 'umum') {
      if (_targetType == 'murid' && _selectedStudentIds.isEmpty) {
        Get.snackbar(
          'Peringatan',
          'Silakan pilih minimal satu murid penerima',
          backgroundColor: Colors.amber.shade700,
          colorText: Colors.white,
        );
        return;
      } else if (_targetType == 'guru' && _selectedTeacherIds.isEmpty) {
        Get.snackbar(
          'Peringatan',
          'Silakan pilih minimal satu guru penerima',
          backgroundColor: Colors.amber.shade700,
          colorText: Colors.white,
        );
        return;
      } else if (_targetType != 'murid' && _targetType != 'guru' && _selectedTargetId == null) {
        Get.snackbar(
          'Peringatan',
          'Silakan pilih penerima spesifik terlebih dahulu',
          backgroundColor: Colors.amber.shade700,
          colorText: Colors.white,
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = SessionService.currentUser!;
      final schoolId = user.schoolId;
      final firestore = FirebaseFirestore.instance;

      if (_targetType == 'murid') {
        // Menggunakan Batch Write karena mengirim ke banyak murid sekaligus
        final batch = firestore.batch();
        final notifRef = firestore.collection('schools').doc(schoolId).collection('notifications');

        for (final student in _selectedStudentDetails) {
          final docRef = notifRef.doc();
          batch.set(docRef, {
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'targetType': 'murid',
            'targetId': student['id'],
            'targetName': student['name'],
            'targetClassId': student['classId'],
            'senderId': user.uid,
            'senderName': user.nama,
            'senderRole': user.role,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } else if (_targetType == 'guru') {
        // Menggunakan Batch Write karena mengirim ke banyak guru sekaligus
        final batch = firestore.batch();
        final notifRef = firestore.collection('schools').doc(schoolId).collection('notifications');

        for (final teacher in _selectedTeacherDetails) {
          final docRef = notifRef.doc();
          batch.set(docRef, {
            'title': _titleController.text.trim(),
            'content': _contentController.text.trim(),
            'targetType': 'guru',
            'targetId': teacher['id'],
            'targetName': teacher['name'],
            'senderId': user.uid,
            'senderName': user.nama,
            'senderRole': user.role,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      } else {
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

        await firestore
            .collection('schools')
            .doc(schoolId)
            .collection('notifications')
            .add(dataToSave);
      }

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

    if (_targetType == 'murid') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showStudentSelectionSheet(schoolId),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: fieldBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_search_rounded, color: primaryIndigo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pilih Murid (${_selectedStudentIds.length} Terpilih)',
                      style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 16),
                ],
              ),
            ),
          ),
          if (_selectedStudentDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedStudentDetails.map((student) {
                return Chip(
                  label: Text(student['name'], style: const TextStyle(fontSize: 12)),
                  backgroundColor: primaryIndigo.withValues(alpha: 0.15),
                  labelStyle: const TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16, color: primaryIndigo),
                  onDeleted: () {
                    setState(() {
                      _selectedStudentIds.remove(student['id']);
                      _selectedStudentDetails.removeWhere((s) => s['id'] == student['id']);
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: primaryIndigo.withValues(alpha: 0.3)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      );
    }

    if (_targetType == 'guru') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showTeacherSelectionSheet(schoolId),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: fieldBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_search_rounded, color: primaryIndigo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pilih Guru (${_selectedTeacherIds.length} Terpilih)',
                      style: TextStyle(color: textPrimaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: iconColor, size: 16),
                ],
              ),
            ),
          ),
          if (_selectedTeacherDetails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTeacherDetails.map((teacher) {
                return Chip(
                  label: Text(teacher['name'], style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  labelStyle: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF0EA5E9)),
                  onDeleted: () {
                    setState(() {
                      _selectedTeacherIds.remove(teacher['id']);
                      _selectedTeacherDetails.removeWhere((t) => t['id'] == teacher['id']);
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      );
    }

    // Only kelas dropdown remains here

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
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

        if (role == 'teacher' && _targetType == 'kelas') {
          filteredDocs = docs.where((doc) => _teacherClassIds.contains(doc.id)).toList();
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
              'Belum ada kelas yang Anda ajar',
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
            'Pilih Kelas',
            style: TextStyle(color: hintColor),
          ),
          onChanged: (val) {
            if (val != null) {
              final selectedDoc = filteredDocs.firstWhere((doc) => doc.id == val);
              setState(() {
                _selectedTargetId = val;
                _selectedTargetName = selectedDoc.data()['namaKelas'] ?? '';
              });
            }
          },
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.class_rounded,
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
            final name = doc.data()['namaKelas'] ?? '';
            return DropdownMenuItem<String>(
              value: doc.id,
              child: Text(name, style: TextStyle(color: textPrimaryColor)),
            );
          }).toList(),
        );
      },
    );
  }

  void _showStudentSelectionSheet(String schoolId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _StudentSelectionSheet(
          schoolId: schoolId,
          initialSelectedIds: _selectedStudentIds,
          teacherClassIds: SessionService.currentUser!.role == 'teacher' ? _teacherClassIds : null,
          onSelectionChanged: (selectedIds, selectedDetails) {
            setState(() {
              _selectedStudentIds = selectedIds;
              _selectedStudentDetails = selectedDetails;
            });
          },
        );
      },
    );
  }

  void _showTeacherSelectionSheet(String schoolId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TeacherSelectionSheet(
          schoolId: schoolId,
          initialSelectedIds: _selectedTeacherIds,
          onSelectionChanged: (selectedIds, selectedDetails) {
            setState(() {
              _selectedTeacherIds = selectedIds;
              _selectedTeacherDetails = selectedDetails;
            });
          },
        );
      },
    );
  }
}

class _StudentSelectionSheet extends StatefulWidget {
  final String schoolId;
  final Set<String> initialSelectedIds;
  final Set<String>? teacherClassIds;
  final Function(Set<String>, List<Map<String, dynamic>>) onSelectionChanged;

  const _StudentSelectionSheet({
    required this.schoolId,
    required this.initialSelectedIds,
    this.teacherClassIds,
    required this.onSelectionChanged,
  });

  @override
  State<_StudentSelectionSheet> createState() => _StudentSelectionSheetState();
}

class _StudentSelectionSheetState extends State<_StudentSelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedIds = {};
  List<Map<String, dynamic>> _allStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('students')
          .get();

      List<Map<String, dynamic>> students = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final classId = data['classId'] ?? '';
        
        // Filter by teacher classes if role is teacher
        if (widget.teacherClassIds != null && !widget.teacherClassIds!.contains(classId)) {
          continue;
        }

        students.add({
          'id': doc.id,
          'name': data['nama'] ?? 'Tanpa Nama',
          'nis': data['nis'] ?? '-',
          'classId': classId,
          'className': data['className'] ?? 'Kelas',
        });
      }

      // Sort by name
      students.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _allStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final selectedDetails = _allStudents.where((s) => _selectedIds.contains(s['id'])).toList();
    widget.onSelectionChanged(_selectedIds, selectedDetails);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final bgColor = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final primaryIndigo = const Color(0xFF8B5CF6);

    final filteredStudents = _allStudents.where((student) {
      final nameMatches = student['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final nisMatches = student['nis'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatches || nisMatches;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subTextColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Murid',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                TextButton(
                  onPressed: _selectedIds.isEmpty && _allStudents.isNotEmpty
                      ? () {
                          setState(() {
                            _selectedIds = _allStudents.map((s) => s['id'] as String).toSet();
                          });
                        }
                      : () {
                          setState(() {
                            _selectedIds.clear();
                          });
                        },
                  child: Text(
                    _selectedIds.isEmpty && _allStudents.isNotEmpty ? 'Pilih Semua' : 'Batal Semua',
                    style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Cari nama atau NIS murid...',
                hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // List View
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryIndigo))
                : filteredStudents.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada murid ditemukan',
                          style: TextStyle(color: subTextColor),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredStudents.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final student = filteredStudents[index];
                          final id = student['id'];
                          final isSelected = _selectedIds.contains(id);

                          return Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: subTextColor,
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: primaryIndigo,
                              checkColor: Colors.white,
                              title: Text(
                                student['name'],
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${student['className']} • NIS: ${student['nis']}',
                                style: TextStyle(color: subTextColor, fontSize: 12),
                              ),
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
          ),

          // Footer / Confirm Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedIds.length} Terpilih',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherSelectionSheet extends StatefulWidget {
  final String schoolId;
  final Set<String> initialSelectedIds;
  final Function(Set<String>, List<Map<String, dynamic>>) onSelectionChanged;

  const _TeacherSelectionSheet({
    required this.schoolId,
    required this.initialSelectedIds,
    required this.onSelectionChanged,
  });

  @override
  State<_TeacherSelectionSheet> createState() => _TeacherSelectionSheetState();
}

class _TeacherSelectionSheetState extends State<_TeacherSelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedIds = {};
  List<Map<String, dynamic>> _allTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .get();

      List<Map<String, dynamic>> teachers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        teachers.add({
          'id': data['teacherId'] ?? doc.id,
          'docId': doc.id,
          'name': data['nama'] ?? 'Tanpa Nama',
          'nip': data['nip'] ?? '-',
          'mapel': data['mapel'] ?? data['mataPelajaran'] ?? '-',
        });
      }

      // Sort by name
      teachers.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (mounted) {
        setState(() {
          _allTeachers = teachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teachers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final selectedDetails = _allTeachers.where((t) => _selectedIds.contains(t['id'])).toList();
    widget.onSelectionChanged(_selectedIds, selectedDetails);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final bgColor = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    const primaryIndigo = Color(0xFF8B5CF6);

    final filteredTeachers = _allTeachers.where((teacher) {
      final nameMatches = teacher['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final nipMatches = teacher['nip'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final mapelMatches = teacher['mapel'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return nameMatches || nipMatches || mapelMatches;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: subTextColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pilih Guru',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                TextButton(
                  onPressed: _selectedIds.isEmpty && _allTeachers.isNotEmpty
                      ? () {
                          setState(() {
                            _selectedIds = _allTeachers.map((t) => t['id'] as String).toSet();
                          });
                        }
                      : () {
                          setState(() {
                            _selectedIds.clear();
                          });
                        },
                  child: Text(
                    _selectedIds.isEmpty && _allTeachers.isNotEmpty ? 'Pilih Semua' : 'Batal Semua',
                    style: const TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Cari nama, NIP, atau mata pelajaran guru...',
                hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryIndigo))
                : filteredTeachers.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada guru ditemukan',
                          style: TextStyle(color: subTextColor),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredTeachers.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final teacher = filteredTeachers[index];
                          final id = teacher['id'];
                          final isSelected = _selectedIds.contains(id);

                          return Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: subTextColor,
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: primaryIndigo,
                              checkColor: Colors.white,
                              title: Text(
                                teacher['name'],
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${teacher['mapel']} • NIP: ${teacher['nip']}',
                                style: TextStyle(color: subTextColor, fontSize: 12),
                              ),
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(id);
                                  } else {
                                    _selectedIds.remove(id);
                                  }
                                });
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
          ),

          // Footer / Confirm Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedIds.length} Terpilih',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Selesai',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
