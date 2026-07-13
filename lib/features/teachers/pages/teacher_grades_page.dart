import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../../core/localization/app_localization.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../services/grade_service.dart';
import 'teacher_input_grade_page.dart';

class TeacherGradesPage extends StatefulWidget {
  final String teacherId;
  final bool hideBackButton;
  const TeacherGradesPage({
    super.key,
    required this.teacherId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherGradesPage> createState() => _TeacherGradesPageState();
}

class _TeacherGradesPageState extends State<TeacherGradesPage> {
  final _gradeService = GradeService();

  bool _isLoadingSchedules = true;
  Map<String, Map<String, dynamic>> _classMap = {};
  String? _selectedFilterClassId;
  String? _selectedFilterSubjectId;
  String? _tahunAjaran;
  String? _activeSemester;

  @override
  void initState() {
    super.initState();
    _loadTeacherSchedules();
  }

  Future<void> _loadTeacherSchedules() async {
    final user = SessionService.currentUser!;
    try {
      final schoolData = await SchoolService().getSchoolByDomain(user.schoolId);
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('class_schedules')
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      final Map<String, Map<String, dynamic>> tempClassMap = {};
      for (final doc in snapshot.docs) {
        final s = doc.data();
        final classId = s['classId']?.toString() ?? '';
        final className = s['className']?.toString() ?? '';
        final subjectId = s['subjectId']?.toString() ?? '';
        final subjectName = s['subjectName']?.toString() ?? '';

        if (classId.isEmpty || className.isEmpty) continue;

        if (!tempClassMap.containsKey(classId)) {
          tempClassMap[classId] = {
            'classId': classId,
            'className': className,
            'subjects': <String, String>{},
          };
        }
        if (subjectId.isNotEmpty && subjectName.isNotEmpty) {
          final classData = tempClassMap[classId]!;
          (classData['subjects'] as Map<String, String>)[subjectId] = subjectName;
        }
      }

      if (mounted) {
        setState(() {
          _classMap = tempClassMap;
          _tahunAjaran = schoolData?['tahunAjaran'];
          _activeSemester = schoolData?['semester'];
          _isLoadingSchedules = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading schedules: $e');
      if (mounted) {
        setState(() {
          _isLoadingSchedules = false;
        });
      }
    }
  }

  String _getFormattedIndonesianDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        final date = DateTime(year, month, day);
        final dayName = AppLocalization.dayNames[date.weekday - 1];
        final monthName = AppLocalization.monthNames[date.month - 1];
        return '$dayName, $day $monthName $year';
      }
    } catch (_) {}
    return dateStr;
  }

  String _getLocalizedCategory(String cat) {
    switch (cat) {
      case 'Tugas':
        return AppLocalization.isIndonesian ? 'Tugas' : 'Assignment';
      case 'Kuis':
        return AppLocalization.isIndonesian ? 'Kuis' : 'Quiz';
      case 'Ulangan Harian':
        return AppLocalization.isIndonesian ? 'Ulangan Harian' : 'Daily Test';
      case 'UTS':
        return AppLocalization.isIndonesian ? 'UTS' : 'Midterm Exam';
      case 'UAS':
        return AppLocalization.isIndonesian ? 'UAS' : 'Final Exam';
      default:
        return cat;
    }
  }

  Future<void> _confirmDelete(BuildContext context, String schoolId, String gradeId, String title) async {
    final isDark = AuthBackground.isDarkMode.value;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              AppLocalization.deleteGrade,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalization.isIndonesian
              ? 'Apakah Anda yakin ingin menghapus penilaian "$title" beserta seluruh nilai siswa di dalamnya? Tindakan ini tidak dapat dibatalkan.'
              : 'Are you sure you want to delete the grade "$title" along with all student scores in it? This action cannot be undone.',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalization.cancel, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalization.isIndonesian ? 'Hapus' : 'Delete', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _gradeService.deleteGrade(schoolId, gradeId);
        Get.snackbar(
          AppLocalization.isIndonesian ? 'Sukses' : 'Success',
          AppLocalization.gradeDeleted,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          AppLocalization.isIndonesian ? 'Gagal menghapus penilaian: $e' : 'Failed to delete grade: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    }
  }

  void _showWeightsConfigDialog(BuildContext context) {
    final user = SessionService.currentUser!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WeightsConfigDialog(
        schoolId: user.schoolId,
        teacherId: widget.teacherId,
        classMap: _classMap,
        tahunAjaran: _tahunAjaran ?? '-',
        semester: _activeSemester ?? '-',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLocale,
      builder: (context, locale, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
            final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
            final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
            final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
            final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
            final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
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
                    AppLocalization.gradesBookTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                  ),
                   actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 16, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _showWeightsConfigDialog(context),
                        icon: Icon(Icons.scale_rounded, color: iconColor, size: 20),
                        label: Text(
                          AppLocalization.setWeights,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_isLoadingSchedules)
                  SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                      ),
                    ),
                  ),

                if (!_isLoadingSchedules)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorderColor),
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: shadowColor,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.filter_alt_rounded, color: const Color(0xFF8B5CF6), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalization.filterGrades,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: titleColor,
                                  ),
                                ),
                                const Spacer(),
                                if (_selectedFilterClassId != null || _selectedFilterSubjectId != null)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedFilterClassId = null;
                                        _selectedFilterSubjectId = null;
                                      });
                                    },
                                    child: Text(
                                      AppLocalization.reset,
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedFilterClassId,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: AppLocalization.classLabel,
                                      labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    style: TextStyle(color: titleColor, fontSize: 13),
                                    items: [
                                      DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(AppLocalization.isIndonesian ? 'Semua Kelas' : 'All Classes'),
                                      ),
                                      ..._classMap.keys.map((classId) {
                                        return DropdownMenuItem<String>(
                                          value: classId,
                                          child: Text(_classMap[classId]?['className']?.toString() ?? ''),
                                        );
                                      })
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedFilterClassId = val;
                                        _selectedFilterSubjectId = null; 
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedFilterSubjectId,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: AppLocalization.subjectLabel,
                                      labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    style: TextStyle(color: titleColor, fontSize: 13),
                                    items: () {
                                      Map<String, String> subjectsList = {};
                                      if (_selectedFilterClassId != null) {
                                        final classData = _classMap[_selectedFilterClassId];
                                        if (classData != null && classData['subjects'] != null) {
                                          subjectsList = Map<String, String>.from(classData['subjects'] as Map);
                                        }
                                      } else {
                                        for (final classId in _classMap.keys) {
                                          final classData = _classMap[classId];
                                          if (classData != null && classData['subjects'] != null) {
                                            subjectsList.addAll(Map<String, String>.from(classData['subjects'] as Map));
                                          }
                                        }
                                      }
                                      return [
                                        DropdownMenuItem<String>(
                                          value: null,
                                          child: Text(AppLocalization.isIndonesian ? 'Semua Mapel' : 'All Subjects'),
                                        ),
                                        ...subjectsList.keys.map((subjectId) {
                                          return DropdownMenuItem<String>(
                                            value: subjectId,
                                            child: Text(subjectsList[subjectId] ?? ''),
                                          );
                                        })
                                      ];
                                    }(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedFilterSubjectId = val;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (!_isLoadingSchedules)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _gradeService.getGradesByTeacher(
                      user.schoolId,
                      widget.teacherId,
                      classId: _selectedFilterClassId,
                      subjectId: _selectedFilterSubjectId,
                      tahunAjaran: _tahunAjaran ?? '-',
                      semester: _activeSemester ?? '-',
                    ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Text(
                            '${AppLocalization.isIndonesian ? 'Gagal memuat data nilai' : 'Failed to load grade data'}: ${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.grade_rounded,
                                size: 64,
                                color: subTextColor.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalization.noGradesYet,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalization.tapPlusToInsert,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: subTextColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final gradeId = doc.id;
                            final title = data['title'] ?? (AppLocalization.isIndonesian ? 'Penilaian' : 'Grade');
                            final category = data['category'] ?? 'Tugas';
                            final className = data['className'] ?? 'Kelas';
                            final subjectName = data['subjectName'] ?? 'Pelajaran';
                            final dateStr = data['date'] ?? '-';
                            final maxScore = ((data['maxScore'] ?? 100.0) as num).toDouble();

                            final scores = data['scores'] as Map<String, dynamic>? ?? {};
                            double sum = 0;
                            int count = 0;
                            scores.forEach((key, detail) {
                              if (detail is Map) {
                                sum += ((detail['score'] ?? 0.0) as num).toDouble();
                                count++;
                              }
                            });
                            final double average = count > 0 ? sum / count : 0.0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          _getLocalizedCategory(category),
                                          style: const TextStyle(
                                            color: Color(0xFF8B5CF6),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 20),
                                            tooltip: AppLocalization.editGrade,
                                            onPressed: () => Get.to(() => TeacherInputGradePage(
                                                  teacherId: widget.teacherId,
                                                  existingGradeData: data,
                                                )),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_rounded, color: Color(0xFFEF4444), size: 20),
                                            tooltip: AppLocalization.deleteGrade,
                                            onPressed: () => _confirmDelete(context, user.schoolId, gradeId, title),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$subjectName ($className)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(color: cardBorderColor),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalization.isIndonesian ? 'Tanggal' : 'Date',
                                            style: TextStyle(fontSize: 11, color: subTextColor),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _getFormattedIndonesianDate(dateStr),
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            AppLocalization.isIndonesian ? 'Rata-Rata Kelas' : 'Class Average',
                                            style: TextStyle(fontSize: 11, color: subTextColor),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${average.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: average >= 75.0 ? const Color(0xFF10B981) : Colors.orangeAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? '$count Siswa dinilai' : '$count Students graded',
                                        style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: docs.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => Get.to(() => TeacherInputGradePage(teacherId: widget.teacherId)),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        );
          },
        );
      },
    );
  }
}

class _WeightsConfigDialog extends StatefulWidget {
  final String schoolId;
  final String teacherId;
  final Map<String, Map<String, dynamic>> classMap;
  final String tahunAjaran;
  final String semester;
  const _WeightsConfigDialog({required this.schoolId, required this.teacherId, required this.classMap, required this.tahunAjaran, required this.semester});

  @override
  State<_WeightsConfigDialog> createState() => _WeightsConfigDialogState();
}

class _WeightsConfigDialogState extends State<_WeightsConfigDialog> {
  final _gradeService = GradeService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoadingWeights = false;
  bool _isSaving = false;

  final Set<String> _selectedClassIds = {};
  String? _selectedSubjectId;

  // Controllers untuk bobot
  final _tugasController = TextEditingController(text: '20');
  final _kuisController = TextEditingController(text: '20');
  final _ulanganController = TextEditingController(text: '20');
  final _utsController = TextEditingController(text: '20');
  final _uasController = TextEditingController(text: '20');

  String _getLocalizedCategory(String cat) {
    switch (cat) {
      case 'Tugas':
        return AppLocalization.isIndonesian ? 'Tugas' : 'Assignment';
      case 'Kuis':
        return AppLocalization.isIndonesian ? 'Kuis' : 'Quiz';
      case 'Ulangan Harian':
        return AppLocalization.isIndonesian ? 'Ulangan Harian' : 'Daily Test';
      case 'UTS':
        return AppLocalization.isIndonesian ? 'UTS' : 'Midterm Exam';
      case 'UAS':
        return AppLocalization.isIndonesian ? 'UAS' : 'Final Exam';
      default:
        return cat;
    }
  }

  double get _totalPercentage {
    final t = double.tryParse(_tugasController.text) ?? 0;
    final k = double.tryParse(_kuisController.text) ?? 0;
    final u = double.tryParse(_ulanganController.text) ?? 0;
    final uts = double.tryParse(_utsController.text) ?? 0;
    final uas = double.tryParse(_uasController.text) ?? 0;
    return t + k + u + uts + uas;
  }

  /// Kumpulkan semua mata pelajaran unik dari kelas-kelas yang dipilih
  Map<String, String> get _availableSubjects {
    final Map<String, String> subjects = {};
    for (final classId in _selectedClassIds) {
      final classData = widget.classMap[classId];
      if (classData != null && classData['subjects'] != null) {
        subjects.addAll(Map<String, String>.from(classData['subjects'] as Map));
      }
    }
    return subjects;
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadExistingWeights() async {
    if (_selectedClassIds.isEmpty || _selectedSubjectId == null) return;
    setState(() {
      _isLoadingWeights = true;
    });

    try {
      // Ambil bobot dari kelas pertama yang dipilih sebagai referensi
      final firstClassId = _selectedClassIds.first;
      final docId = '${firstClassId}_${_selectedSubjectId}_${widget.tahunAjaran.replaceAll('/', '_')}_${widget.semester}';
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('subject_weights')
          .doc(docId)
          .get();

      if (doc.exists && doc.data()?['weights'] != null) {
        final w = doc.data()!['weights'] as Map<String, dynamic>;
        setState(() {
          _tugasController.text = (w['Tugas'] ?? 20).toString();
          _kuisController.text = (w['Kuis'] ?? 20).toString();
          _ulanganController.text = (w['Ulangan Harian'] ?? 20).toString();
          _utsController.text = (w['UTS'] ?? 20).toString();
          _uasController.text = (w['UAS'] ?? 20).toString();
        });
      } else {
        setState(() {
          _tugasController.text = '20';
          _kuisController.text = '20';
          _ulanganController.text = '20';
          _utsController.text = '20';
          _uasController.text = '20';
        });
      }
    } catch (e) {
      debugPrint('Error loading weights: $e');
    } finally {
      setState(() {
        _isLoadingWeights = false;
      });
    }
  }

  Future<void> _saveWeights() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassIds.isEmpty || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalization.isIndonesian ? 'Pilih minimal satu Kelas & Mapel terlebih dahulu' : 'Please select at least one Class & Subject first'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final total = _totalPercentage;
    if (total != 100.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalization.isIndonesian ? 'Total bobot harus 100% (saat ini: ${total.toStringAsFixed(0)}%)' : 'Total weight must be 100% (currently: ${total.toStringAsFixed(0)}%)'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final wMap = {
        'Tugas': double.tryParse(_tugasController.text) ?? 20.0,
        'Kuis': double.tryParse(_kuisController.text) ?? 20.0,
        'Ulangan Harian': double.tryParse(_ulanganController.text) ?? 20.0,
        'UTS': double.tryParse(_utsController.text) ?? 20.0,
        'UAS': double.tryParse(_uasController.text) ?? 20.0,
      };

      // Simpan bobot untuk setiap kelas yang dipilih
      for (final classId in _selectedClassIds) {
        await _gradeService.saveCategoryWeights(
          schoolId: widget.schoolId,
          classId: classId,
          subjectId: _selectedSubjectId!,
          teacherId: widget.teacherId,
          weights: wMap,
          tahunAjaran: widget.tahunAjaran,
          semester: widget.semester,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalization.isIndonesian
              ? 'Bobot kategori berhasil disimpan untuk ${_selectedClassIds.length} kelas'
              : 'Category weights successfully saved for ${_selectedClassIds.length} classes'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalization.isIndonesian ? 'Gagal menyimpan bobot' : 'Failed to save weights'}: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    final subjectsList = _availableSubjects;

    // Pastikan _selectedSubjectId masih valid di dalam list mapel saat ini
    if (_selectedSubjectId != null && !subjectsList.containsKey(_selectedSubjectId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedSubjectId = null;
          });
        }
      });
    }

    final bool hasSelection = _selectedClassIds.isNotEmpty && _selectedSubjectId != null;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cardBorderColor),
      ),
      title: Row(
        children: [
          const Icon(Icons.scale_rounded, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          Text(
            AppLocalization.isIndonesian ? 'Atur Bobot Kategori' : 'Set Category Weights',
            style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Multi-select Kelas (Checkbox)
                      Text(
                        AppLocalization.isIndonesian ? 'Pilih Kelas (bisa lebih dari satu)' : 'Select Class (can select multiple)',
                        style: TextStyle(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: inputFillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: widget.classMap.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(AppLocalization.isIndonesian ? 'Tidak ada kelas tersedia' : 'No classes available', style: TextStyle(color: subTextColor, fontSize: 12)),
                              )
                            : ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                children: widget.classMap.keys.map((classId) {
                                  final className = widget.classMap[classId]?['className']?.toString() ?? '';
                                  final isSelected = _selectedClassIds.contains(classId);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    activeColor: const Color(0xFF8B5CF6),
                                    title: Text(
                                      className,
                                      style: TextStyle(color: titleColor, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedClassIds.add(classId);
                                        } else {
                                          _selectedClassIds.remove(classId);
                                        }
                                        // Reset mapel jika sudah tidak relevan
                                        if (_selectedSubjectId != null && !_availableSubjects.containsKey(_selectedSubjectId)) {
                                          _selectedSubjectId = null;
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                      ),
                      if (_selectedClassIds.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _selectedClassIds.map((classId) {
                              final className = widget.classMap[classId]?['className']?.toString() ?? '';
                              return Chip(
                                label: Text(className, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: const Color(0xFF8B5CF6),
                                deleteIconColor: Colors.white70,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                onDeleted: () {
                                  setState(() {
                                    _selectedClassIds.remove(classId);
                                    if (_selectedSubjectId != null && !_availableSubjects.containsKey(_selectedSubjectId)) {
                                      _selectedSubjectId = null;
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Dropdown Mapel (berdasarkan gabungan semua kelas terpilih)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedSubjectId,
                        dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                        decoration: InputDecoration(
                          labelText: AppLocalization.isIndonesian ? 'Pilih Mata Pelajaran' : 'Select Subject',
                          labelStyle: TextStyle(color: subTextColor, fontSize: 13),
                          fillColor: inputFillColor,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cardBorderColor),
                          ),
                        ),
                        style: TextStyle(color: titleColor, fontSize: 14),
                        items: subjectsList.keys.map((subjectId) {
                          return DropdownMenuItem(
                            value: subjectId,
                            child: Text(subjectsList[subjectId] ?? ''),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSubjectId = val;
                          });
                          _loadExistingWeights();
                        },
                      ),
                      const SizedBox(height: 16),

                      if (hasSelection) ...[
                        if (_isLoadingWeights)
                          const SizedBox(
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                            ),
                          )
                        else ...[
                          Divider(color: cardBorderColor),
                          const SizedBox(height: 8),
                          _buildWeightInput(_getLocalizedCategory('Tugas'), _tugasController, titleColor, subTextColor, inputFillColor, cardBorderColor),
                          const SizedBox(height: 10),
                          _buildWeightInput(_getLocalizedCategory('Kuis'), _kuisController, titleColor, subTextColor, inputFillColor, cardBorderColor),
                          const SizedBox(height: 10),
                          _buildWeightInput(_getLocalizedCategory('Ulangan Harian'), _ulanganController, titleColor, subTextColor, inputFillColor, cardBorderColor),
                          const SizedBox(height: 10),
                          _buildWeightInput(_getLocalizedCategory('UTS'), _utsController, titleColor, subTextColor, inputFillColor, cardBorderColor),
                          const SizedBox(height: 10),
                          _buildWeightInput(_getLocalizedCategory('UAS'), _uasController, titleColor, subTextColor, inputFillColor, cardBorderColor),
                          const SizedBox(height: 16),
                          
                          // Total akumulasi
                          StatefulBuilder(
                            builder: (context, setSubState) {
                              void update() => setSubState(() {});
                              _tugasController.addListener(update);
                              _kuisController.addListener(update);
                              _ulanganController.addListener(update);
                              _utsController.addListener(update);
                              _uasController.addListener(update);
                              
                              final total = _totalPercentage;
                              final isValid = total == 100.0;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isValid ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppLocalization.isIndonesian ? 'Total Akumulasi:' : 'Total Accumulation:',
                                      style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      '${total.toStringAsFixed(0)}% / 100%',
                                      style: TextStyle(
                                        color: isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Info jumlah kelas
                          if (_selectedClassIds.length > 1) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF3B82F6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppLocalization.isIndonesian
                                          ? 'Bobot akan diterapkan ke ${_selectedClassIds.length} kelas sekaligus.'
                                          : 'Weights will be applied to ${_selectedClassIds.length} classes at once.',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ]
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            AppLocalization.isIndonesian ? 'Pilih Kelas dan Mapel untuk mengatur bobot.' : 'Select Class and Subject to configure weights.',
                            style: TextStyle(color: subTextColor, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalization.cancel,
            style: TextStyle(color: subTextColor, fontWeight: FontWeight.w600),
          ),
        ),
        if (hasSelection && !_isLoadingWeights)
          ElevatedButton(
            onPressed: _isSaving ? null : _saveWeights,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    AppLocalization.isIndonesian
                        ? (_selectedClassIds.length > 1 ? 'Simpan (${_selectedClassIds.length} Kelas)' : 'Simpan')
                        : (_selectedClassIds.length > 1 ? 'Save (${_selectedClassIds.length} Classes)' : 'Save'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
      ],
    );
  }

  Widget _buildWeightInput(
    String label,
    TextEditingController controller,
    Color titleColor,
    Color subTextColor,
    Color inputFillColor,
    Color cardBorderColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              suffixText: '%',
              suffixStyle: TextStyle(color: subTextColor, fontSize: 11),
              fillColor: inputFillColor,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cardBorderColor),
              ),
            ),
            validator: (val) {
              final d = double.tryParse(val ?? '');
              if (d == null || d < 0 || d > 100) {
                return '0-100';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}

