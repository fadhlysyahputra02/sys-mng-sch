import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../services/grade_service.dart';
import 'teacher_grade_recap_page.dart';
import 'teacher_rapor_page.dart';

class TeacherReportsPage extends StatefulWidget {
  final String schoolId;
  final String teacherId;
  final bool hideBackButton;

  const TeacherReportsPage({
    super.key,
    required this.schoolId,
    required this.teacherId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherReportsPage> createState() => _TeacherReportsPageState();
}

class _TeacherReportsPageState extends State<TeacherReportsPage> {
  bool _isLoading = true;
  List<DocumentSnapshot<Map<String, dynamic>>> _homeroomClasses = [];
  List<Map<String, String>> _teachingPairs = [];
  String? _selectedFilterClassId;
  String? _selectedFilterSubjectId;

  Map<String, String> get _teachingClasses {
    final Map<String, String> classes = {};
    for (var pair in _teachingPairs) {
      final classId = pair['classId'];
      final className = pair['className'];
      if (classId != null && className != null) {
        classes[classId] = className;
      }
    }
    return classes;
  }

  Map<String, String> _getSubjectsForClass(String classId) {
    final Map<String, String> subjects = {};
    for (var pair in _teachingPairs) {
      if (pair['classId'] == classId) {
        final subjectId = pair['subjectId'];
        final subjectName = pair['subjectName'];
        if (subjectId != null && subjectName != null) {
          subjects[subjectId] = subjectName;
        }
      }
    }
    return subjects;
  }

  String _tahunAjaran = '';
  String _activeSemester = '';
  
  StreamSubscription<DocumentSnapshot>? _schoolSub;
  bool _lockDialogShown = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _listenToAccess();
  }

  void _listenToAccess() {
    _schoolSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bool enabled = data['enableERapor'] ?? false;
        if (!enabled && !_lockDialogShown && mounted) {
          _lockDialogShown = true;
          _showPremiumDialogAndExit();
        }
      }
    });
  }

  void _showPremiumDialogAndExit() {
    final isDark = AuthBackground.isDarkMode.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Fitur Terkunci', style: TextStyle(color: Colors.amber)),
            ],
          ),
          content: Text(
            'Sekolah belum berlangganan untuk mengaktifkan fitur ini.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                if (mounted) {
                  Get.offAllNamed('/teacher'); // Exit to Dashboard
                }
              },
              child: const Text('Tutup', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 0. Ambil metadata sekolah
      final schoolDoc = await SchoolService().getSchoolByDomain(widget.schoolId);
      final activeTahunAjaran = schoolDoc?['tahunAjaran']?.toString() ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
      final activeSemester = schoolDoc?['semester']?.toString() ?? 'Semester 1';

      // 1. Ambil data kelas wali kelas
      final homeroomSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('classes')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      // 2. Ambil jadwal mengajar guru
      final scheduleSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('class_schedules')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      final List<Map<String, String>> tempPairs = [];
      final Set<String> seenKeys = {};

      for (final doc in scheduleSnapshot.docs) {
        final s = doc.data();
        final classId = s['classId']?.toString() ?? '';
        final className = s['className']?.toString() ?? '';
        final subjectId = s['subjectId']?.toString() ?? '';
        final subjectName = s['subjectName']?.toString() ?? '';

        if (classId.isEmpty || className.isEmpty || subjectId.isEmpty || subjectName.isEmpty) continue;

        final key = '${classId}_$subjectId';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          tempPairs.add({
            'classId': classId,
            'className': className,
            'subjectId': subjectId,
            'subjectName': subjectName,
          });
        }
      }

      tempPairs.sort((a, b) {
        final classCompare = (a['className'] ?? '').compareTo(b['className'] ?? '');
        if (classCompare != 0) return classCompare;
        return (a['subjectName'] ?? '').compareTo(b['subjectName'] ?? '');
      });

      setState(() {
        _tahunAjaran = activeTahunAjaran;
        _activeSemester = activeSemester;
        _homeroomClasses = homeroomSnapshot.docs;
        _teachingPairs = tempPairs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading reports metadata: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _manageSubjectDescriptions({
    required BuildContext context,
    required String schoolId,
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return _ManageDescriptionsBottomSheet(
          schoolId: schoolId,
          classId: classId,
          className: className,
          subjectId: subjectId,
          subjectName: subjectName,
          teacherName: SessionService.currentUser!.nama,
          tahunAjaran: _tahunAjaran,
          semester: _activeSemester,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        if (_isLoading) {
          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                ),
              ),
            ),
          );
        }

        if (_homeroomClasses.isEmpty && _teachingPairs.isEmpty) {
          return Scaffold(
            body: AuthBackground(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    automaticallyImplyLeading: !widget.hideBackButton,
                    iconTheme: IconThemeData(color: iconColor),
                    leading: widget.hideBackButton
                        ? null
                        : Container(
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
                      'Laporan & Rapor',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorderColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Tidak Ada Akses Menu',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Anda tidak terdaftar sebagai Wali Kelas maupun Guru Pengampu Mata Pelajaran di kelas manapun.\n\nSilakan hubungi Admin Sekolah untuk penugasan kelas atau mata pelajaran.',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: AuthBackground(
            child: RefreshIndicator(
              onRefresh: _loadAllData,
              color: const Color(0xFF8B5CF6),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // AppBar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    automaticallyImplyLeading: !widget.hideBackButton,
                    iconTheme: IconThemeData(color: iconColor),
                    leading: widget.hideBackButton
                        ? null
                        : Container(
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
                      'Laporan & Rapor',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. SECTION WALI KELAS (jika ada)
                        if (_homeroomClasses.isNotEmpty) ...[
                          Text(
                            'Menu Wali Kelas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kelola dan pantau rekapitulasi penilaian hasil belajar murid di bawah asuhan Anda.',
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._homeroomClasses.map((clsDoc) {
                            final classId = clsDoc.id;
                            final className = clsDoc.data()?['namaKelas'] ?? 'Kelas Tanpa Nama';

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Kartu Rekap Nilai
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: cardBorderColor),
                                    boxShadow: isDark ? [] : [
                                      BoxShadow(
                                        color: shadowColor,
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Get.to(() => TeacherGradeRecapPage(
                                              schoolId: widget.schoolId,
                                              classId: classId,
                                              className: className,
                                              teacherId: widget.teacherId,
                                            ));
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.bar_chart_rounded,
                                                color: Color(0xFFEC4899),
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Rekap Nilai - $className',
                                                    style: TextStyle(
                                                      color: titleColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Melihat rangkuman nilai seluruh mata pelajaran kelas Anda.',
                                                    style: TextStyle(
                                                      color: subTextColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: iconColor.withValues(alpha: 0.5),
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Kartu E-Rapor
                                Container(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: cardBorderColor),
                                    boxShadow: isDark ? [] : [
                                      BoxShadow(
                                        color: shadowColor,
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Get.to(() => TeacherRaporPage(
                                              schoolId: widget.schoolId,
                                              classId: classId,
                                              className: className,
                                              teacherId: widget.teacherId,
                                            ));
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.assignment_rounded,
                                                color: Color(0xFF8B5CF6),
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'E-Rapor & Cetak Rapor - $className',
                                                    style: TextStyle(
                                                      color: titleColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Kelola nilai sikap, catatan wali kelas, dan cetak rapor resmi.',
                                                    style: TextStyle(
                                                      color: subTextColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: iconColor.withValues(alpha: 0.5),
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],

                        // 2. SECTION GURU MATA PELAJARAN (jika ada)
                        if (_teachingPairs.isNotEmpty) ...[
                          if (_homeroomClasses.isNotEmpty) const SizedBox(height: 16),
                          Text(
                            'Menu Guru Mata Pelajaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tulis dan kelola deskripsi pencapaian rapor siswa berdasarkan kelas dan mapel yang Anda ampu.',
                            style: TextStyle(
                              fontSize: 13,
                              color: subTextColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: isDark ? [] : [
                                BoxShadow(
                                  color: shadowColor,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.filter_alt_rounded, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pilih Kelas & Mata Pelajaran',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: titleColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Dropdown Kelas
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _selectedFilterClassId,
                                  dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                  decoration: InputDecoration(
                                    labelText: 'Kelas',
                                    labelStyle: TextStyle(color: subTextColor, fontSize: 12),
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorderColor),
                                    ),
                                  ),
                                  style: TextStyle(color: titleColor, fontSize: 14),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Pilih Kelas'),
                                    ),
                                    ..._teachingClasses.keys.map((classId) {
                                      return DropdownMenuItem<String>(
                                        value: classId,
                                        child: Text(_teachingClasses[classId] ?? ''),
                                      );
                                    })
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedFilterClassId = val;
                                      _selectedFilterSubjectId = null; // Reset mapel
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Dropdown Mapel
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _selectedFilterSubjectId,
                                  dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                  decoration: InputDecoration(
                                    labelText: 'Mata Pelajaran',
                                    labelStyle: TextStyle(color: subTextColor, fontSize: 12),
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorderColor),
                                    ),
                                  ),
                                  style: TextStyle(color: titleColor, fontSize: 14),
                                  items: () {
                                    Map<String, String> subjectsList = {};
                                    if (_selectedFilterClassId != null) {
                                      subjectsList = _getSubjectsForClass(_selectedFilterClassId!);
                                    }
                                    return [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('Pilih Mata Pelajaran'),
                                      ),
                                      ...subjectsList.keys.map((subjectId) {
                                        return DropdownMenuItem<String>(
                                          value: subjectId,
                                          child: Text(subjectsList[subjectId] ?? ''),
                                        );
                                      })
                                    ];
                                  }(),
                                  onChanged: _selectedFilterClassId == null
                                      ? null
                                      : (val) {
                                          setState(() {
                                            _selectedFilterSubjectId = val;
                                          });
                                        },
                                ),
                                if (_selectedFilterClassId != null && _selectedFilterSubjectId != null) ...[
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      final className = _teachingClasses[_selectedFilterClassId!] ?? 'Kelas';
                                      final subjects = _getSubjectsForClass(_selectedFilterClassId!);
                                      final subjectName = subjects[_selectedFilterSubjectId!] ?? 'Mata Pelajaran';
                                      _manageSubjectDescriptions(
                                        context: context,
                                        schoolId: widget.schoolId,
                                        classId: _selectedFilterClassId!,
                                        className: className,
                                        subjectId: _selectedFilterSubjectId!,
                                        subjectName: subjectName,
                                        isDark: isDark,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.edit_note_rounded, size: 22),
                                    label: const Text(
                                      'Kelola Deskripsi Rapor',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ]),
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

  @override
  void dispose() {
    _schoolSub?.cancel();
    super.dispose();
  }
}

class _ManageDescriptionsBottomSheet extends StatefulWidget {
  final String schoolId;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String teacherName;
  final String tahunAjaran;
  final String semester;

  const _ManageDescriptionsBottomSheet({
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.teacherName,
    required this.tahunAjaran,
    required this.semester,
  });

  @override
  State<_ManageDescriptionsBottomSheet> createState() => _ManageDescriptionsBottomSheetState();
}

class _ManageDescriptionsBottomSheetState extends State<_ManageDescriptionsBottomSheet> {
  final _gradeService = GradeService();
  bool _isLoading = true;
  List<DocumentSnapshot<Map<String, dynamic>>> _students = [];
  final Map<String, TextEditingController> _descControllers = {};
  final Map<String, bool> _savingStates = {};
  final Map<String, String> _lastSavedValues = {};
  final Map<String, bool> _isModified = {};

  @override
  void initState() {
    super.initState();
    _loadStudentsAndDescriptions();
  }

  @override
  void dispose() {
    for (var controller in _descControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudentsAndDescriptions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('students')
          .where('classId', isEqualTo: widget.classId)
          .get();

      final studentDocs = studentsSnapshot.docs;
      studentDocs.sort((a, b) {
        final nameA = (a.data()['nama'] ?? '').toString().toLowerCase();
        final nameB = (b.data()['nama'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      final descMap = await _gradeService.getSubjectDescriptionsBySubject(
        schoolId: widget.schoolId,
        subjectId: widget.subjectId,
        tahunAjaran: widget.tahunAjaran,
        semester: widget.semester,
      );

      for (var controller in _descControllers.values) {
        controller.dispose();
      }
      _descControllers.clear();
      _savingStates.clear();
      _lastSavedValues.clear();
      _isModified.clear();

      for (var student in studentDocs) {
        final studentId = student.data()['studentId'] ?? student.id;
        final existingDesc = descMap[studentId] ?? '';
        final controller = TextEditingController(text: existingDesc);
        _descControllers[studentId] = controller;
        _savingStates[studentId] = false;
        _lastSavedValues[studentId] = existingDesc;
        _isModified[studentId] = false;

        controller.addListener(() {
          final isMod = controller.text != (_lastSavedValues[studentId] ?? '');
          if ((_isModified[studentId] ?? false) != isMod) {
            setState(() {
              _isModified[studentId] = isMod;
            });
          }
        });
      }

      setState(() {
        _students = studentDocs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading students and descriptions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDescription(String studentId) async {
    final deskripsi = _descControllers[studentId]?.text.trim() ?? '';
    setState(() {
      _savingStates[studentId] = true;
    });

    try {
      await _gradeService.saveSubjectDescription(
        schoolId: widget.schoolId,
        subjectId: widget.subjectId,
        studentId: studentId,
        tahunAjaran: widget.tahunAjaran,
        semester: widget.semester,
        deskripsi: deskripsi,
        updatedBy: widget.teacherName,
      );

      _lastSavedValues[studentId] = deskripsi;
      _isModified[studentId] = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deskripsi berhasil disimpan untuk ${studentName(studentId)}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan deskripsi: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingStates[studentId] = false;
        });
      }
    }
  }

  String studentName(String studentId) {
    try {
      final doc = _students.firstWhere((element) {
        final elId = element.data()?['studentId'] ?? element.id;
        return elId == studentId;
      });
      return doc.data()?['nama'] ?? 'siswa';
    } catch (_) {
      return 'siswa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.02);
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deskripsi Rapor Siswa',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.subjectName} • ${widget.className}',
                          style: TextStyle(fontSize: 13, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            const Divider(),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                      ),
                    )
                  : _students.isEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada siswa di kelas ini.',
                            style: TextStyle(color: subTextColor),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(24),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final studentDoc = _students[index];
                            final studentId = studentDoc.data()?['studentId'] ?? studentDoc.id;
                            final studentData = studentDoc.data();
                            final studentNameStr = studentData?['nama']?.toString() ?? 'Siswa';
                            final nis = studentData?['nis'] ?? '-';
                            final controller = _descControllers[studentId];
                            final isSaving = _savingStates[studentId] ?? false;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          studentNameStr[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              studentNameStr,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: titleColor,
                                              ),
                                            ),
                                            Text(
                                              'NIS: $nis',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: subTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: controller,
                                    maxLines: 3,
                                    maxLength: 200,
                                    style: TextStyle(color: titleColor, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Tulis deskripsi pencapaian siswa untuk mapel ini...',
                                      hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.6), fontSize: 12),
                                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                      filled: true,
                                      contentPadding: const EdgeInsets.all(12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                                      ),
                                      counterText: '',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: () {
                                      final isModified = _isModified[studentId] ?? false;
                                      final isTextEmpty = controller?.text.trim().isEmpty ?? true;
                                      final shouldShowActive = isModified || isTextEmpty;

                                      final btnBgColor = isSaving
                                          ? const Color(0xFF10B981)
                                          : shouldShowActive
                                              ? const Color(0xFF10B981)
                                              : isDark
                                                  ? Colors.white.withValues(alpha: 0.12)
                                                  : Colors.black.withValues(alpha: 0.06);
                                      final btnFgColor = isSaving
                                          ? Colors.white
                                          : shouldShowActive
                                              ? Colors.white
                                              : isDark
                                                  ? Colors.white60
                                                  : Colors.black54;

                                      return ElevatedButton.icon(
                                        onPressed: isSaving || !shouldShowActive ? null : () => _saveDescription(studentId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: btnBgColor,
                                          foregroundColor: btnFgColor,
                                          disabledBackgroundColor: btnBgColor,
                                          disabledForegroundColor: btnFgColor,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        icon: isSaving
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Icon(shouldShowActive ? Icons.save_rounded : Icons.check_circle_outline_rounded, size: 16),
                                        label: Text(
                                          isSaving
                                              ? 'Menyimpan...'
                                              : shouldShowActive
                                                  ? 'Simpan'
                                                  : 'Tersimpan',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}
