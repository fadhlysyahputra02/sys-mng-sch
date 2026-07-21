import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/semester_state_service.dart';
import '../../../core/localization/app_localization.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../services/grade_service.dart';

class TeacherInputGradePage extends StatefulWidget {
  final String teacherId;
  final Map<String, dynamic>? existingGradeData; // Null jika buat baru

  const TeacherInputGradePage({
    super.key,
    required this.teacherId,
    this.existingGradeData,
  });

  @override
  State<TeacherInputGradePage> createState() => _TeacherInputGradePageState();
}

class _TeacherInputGradePageState extends State<TeacherInputGradePage> {
  final _gradeService = GradeService();
  final _formKey = GlobalKey<FormState>();

  // Data jadwal guru untuk dropdown
  Map<String, Map<String, dynamic>> _classMap = {};
  bool _isLoadingSchedules = true;

  String? _tahunAjaran;
  String? _activeSemester;

  // Form states
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedCategory;
  final _titleController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '100');
  DateTime _selectedDate = DateTime.now();

  // Controllers untuk input nilai siswa: map studentId -> controller
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, TextEditingController> _noteControllers = {};

  final List<String> _categories = ['Tugas', 'Kuis', 'Ulangan Harian', 'UTS', 'UAS'];

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingGradeData != null;
    if (_isEditing) {
      _populateExistingData();
    } else {
      _loadTeacherSchedules();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _maxScoreController.dispose();
    for (var controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (var controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
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

  Future<void> _populateExistingData() async {
    final data = widget.existingGradeData!;
    _selectedClassId = data['classId']?.toString();
    _selectedClassName = data['className']?.toString();
    _selectedSubjectId = data['subjectId']?.toString();
    _selectedSubjectName = data['subjectName']?.toString();
    _selectedCategory = data['category']?.toString();
    _titleController.text = data['title'] ?? '';
    _maxScoreController.text = (data['maxScore'] ?? 100).toStringAsFixed(0);
    
    if (data['date'] != null) {
      _selectedDate = DateTime.parse(data['date'].toString());
    }

    _tahunAjaran = data['tahunAjaran']?.toString();
    _activeSemester = data['semester']?.toString();

    final scores = data['scores'] as Map<String, dynamic>? ?? {};
    scores.forEach((key, detail) {
      if (detail is Map) {
        final scoreVal = detail['score'] ?? '';
        final notesVal = detail['notes'] ?? '';
        
        String studentId = key;
        if (key.contains('_') && _tahunAjaran != null && _activeSemester != null) {
          final cleanYear = _tahunAjaran!.replaceAll('/', '_');
          final suffix = '_${cleanYear}_$_activeSemester';
          if (key.endsWith(suffix)) {
            studentId = key.substring(0, key.length - suffix.length);
          }
        }
        
        _scoreControllers[studentId] = TextEditingController(text: scoreVal.toString());
        _noteControllers[studentId] = TextEditingController(text: notesVal.toString());
      }
    });

    // Resolusi backward-compatible: jika key scores berupa Auth UID (bukan
    // student document ID), cari dokumen siswa yang sesuai dan remap
    // controller ke document ID yang benar agar cocok dengan class_enrollments.
    final schoolId = data['schoolId']?.toString() ?? '';
    if (schoolId.isNotEmpty && _scoreControllers.isNotEmpty) {
      final keysToCheck = List<String>.from(_scoreControllers.keys);
      for (final key in keysToCheck) {
        // Cek apakah key ini valid sebagai student document ID
        final studentDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc(key)
            .get();

        if (!studentDoc.exists) {
          // Key bukan document ID — kemungkinan adalah Auth UID
          final query = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .where('uid', isEqualTo: key)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            final actualDocId = query.docs.first.id;
            if (actualDocId != key) {
              // Remap controller dari Auth UID ke student document ID
              final scoreCtrl = _scoreControllers.remove(key);
              final noteCtrl = _noteControllers.remove(key);
              if (scoreCtrl != null) _scoreControllers[actualDocId] = scoreCtrl;
              if (noteCtrl != null) _noteControllers[actualDocId] = noteCtrl;
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingSchedules = false;
      });
    }
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

      final schedules = snapshot.docs.map((d) => d.data()).toList();

      final Map<String, Map<String, dynamic>> tempClassMap = {};
      for (final s in schedules) {
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

      // Sort tempClassMap by className alphabetically (A-Z)
      final sortedEntries = tempClassMap.entries.toList()
        ..sort((a, b) {
          final nameA = (a.value['className'] ?? '').toString().toLowerCase();
          final nameB = (b.value['className'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
      final Map<String, Map<String, dynamic>> sortedClassMap = Map.fromEntries(sortedEntries);

      if (mounted) {
        setState(() {
          _classMap = sortedClassMap;
          if (_tahunAjaran == null) {
            _tahunAjaran = schoolData?['tahunAjaran']?.toString();
          }
          if (_activeSemester == null) {
            _activeSemester = schoolData?['semester']?.toString();
          }
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

  Future<void> _selectDate(BuildContext context) async {
    final isDark = AuthBackground.isDarkMode.value;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Color(0xFF0F0C20),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF0F0C20),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E1B4B),
                  ),
                  dialogBackgroundColor: Colors.white,
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

  Future<void> _saveGradeData() async {
    final semesterError = SemesterStateService.validateInput();
    if (semesterError != null) {
      _showErrorSnackBar(semesterError);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      _showErrorSnackBar(AppLocalization.isIndonesian ? 'Pilih kelas terlebih dahulu' : 'Please select a class first');
      return;
    }
    if (_selectedSubjectId == null) {
      _showErrorSnackBar(AppLocalization.isIndonesian ? 'Pilih mata pelajaran terlebih dahulu' : 'Please select a subject first');
      return;
    }
    if (_selectedCategory == null) {
      _showErrorSnackBar(AppLocalization.selectCategoryFirst);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final user = SessionService.currentUser!;
    final double maxScore = double.tryParse(_maxScoreController.text) ?? 100.0;

    // Kumpulkan nilai siswa
    final Map<String, Map<String, dynamic>> studentScores = {};
    _scoreControllers.forEach((studentId, controller) {
      final double score = double.tryParse(controller.text) ?? 0.0;
      final String notes = _noteControllers[studentId]?.text ?? '';
      studentScores[studentId] = {
        'score': score,
        'notes': notes,
      };
    });

    try {
      await _gradeService.saveGrade(
        schoolId: user.schoolId,
        gradeId: widget.existingGradeData?['gradeId'],
        classId: _selectedClassId!,
        className: _selectedClassName!,
        subjectId: _selectedSubjectId!,
        subjectName: _selectedSubjectName!,
        teacherId: widget.teacherId,
        teacherName: user.nama,
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        maxScore: maxScore,
        date: _selectedDate,
        scores: studentScores,
        tahunAjaran: _tahunAjaran ?? '-',
        semester: _activeSemester ?? '-',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? AppLocalization.gradeUpdatedSuccess : AppLocalization.gradeSavedSuccess),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar('${AppLocalization.gradeSaveFailed}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
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

        // Filter subject dropdown items
        Map<String, String> subjectsList = {};
        if (_selectedClassId != null) {
          final classData = _classMap[_selectedClassId];
          if (classData != null && classData['subjects'] != null) {
            subjectsList = Map<String, String>.from(classData['subjects'] as Map);
          }
        }

        return Scaffold(
          body: AuthBackground(
            child: _isLoadingSchedules
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                    ),
                  )
                : Form(
                    key: _formKey,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // AppBar
                        SliverAppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          pinned: true,
                          iconTheme: IconThemeData(color: iconColor),
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
                            _isEditing ? AppLocalization.editGradeTitle : AppLocalization.inputNewGradeTitle,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                          ),
                        ),

                        // Form input metadata
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Container(
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
                                  _buildSemesterStateBanner(),
                                  // Dropdown Kelas
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedClassId,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: AppLocalization.isIndonesian ? 'Pilih Kelas' : 'Select Class',
                                      labelStyle: TextStyle(color: subTextColor),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    style: TextStyle(color: titleColor),
                                    items: _isEditing
                                        ? [
                                            DropdownMenuItem(
                                              value: _selectedClassId,
                                              child: Text(_selectedClassName ?? ''),
                                            )
                                          ]
                                        : _classMap.keys.map((classId) {
                                            return DropdownMenuItem(
                                              value: classId,
                                              child: Text(_classMap[classId]?['className']?.toString() ?? ''),
                                            );
                                          }).toList(),
                                    onChanged: _isEditing
                                        ? null
                                        : (val) {
                                            setState(() {
                                              _selectedClassId = val;
                                              if (val != null) {
                                                _selectedClassName = _classMap[val]?['className'] as String?;
                                              } else {
                                                _selectedClassName = null;
                                              }
                                              // Reset subject
                                              _selectedSubjectId = null;
                                              _selectedSubjectName = null;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 16),

                                  // Dropdown Mata Pelajaran
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedSubjectId,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: AppLocalization.isIndonesian ? 'Pilih Mata Pelajaran' : 'Select Subject',
                                      labelStyle: TextStyle(color: subTextColor),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    style: TextStyle(color: titleColor),
                                    items: _isEditing
                                        ? [
                                            DropdownMenuItem(
                                              value: _selectedSubjectId,
                                              child: Text(_selectedSubjectName ?? ''),
                                            )
                                          ]
                                        : (subjectsList.keys.toList()
                                            ..sort((a, b) => (subjectsList[a] ?? '').toLowerCase().compareTo((subjectsList[b] ?? '').toLowerCase())))
                                            .map((subjectId) {
                                              return DropdownMenuItem(
                                                value: subjectId,
                                                child: Text(subjectsList[subjectId] ?? ''),
                                              );
                                            }).toList(),
                                    onChanged: _isEditing
                                        ? null
                                        : (val) {
                                            setState(() {
                                              _selectedSubjectId = val;
                                              _selectedSubjectName = subjectsList[val];
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 16),

                                  // Dropdown Kategori
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: _selectedCategory,
                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                    decoration: InputDecoration(
                                      labelText: AppLocalization.categoryLabel,
                                      labelStyle: TextStyle(color: subTextColor),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    style: TextStyle(color: titleColor),
                                    items: _categories.map((cat) {
                                      return DropdownMenuItem<String>(
                                        value: cat,
                                        child: Text(_getLocalizedCategory(cat)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedCategory = val;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Judul Penilaian
                                  TextFormField(
                                    controller: _titleController,
                                    style: TextStyle(color: titleColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: AppLocalization.gradeTitlePlaceholder,
                                      labelStyle: TextStyle(color: subTextColor),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return AppLocalization.enterGradeTitle;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Nilai Maksimum
                                  TextFormField(
                                    controller: _maxScoreController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: titleColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      labelText: AppLocalization.maxScoreLabel,
                                      labelStyle: TextStyle(color: subTextColor),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                    ),
                                    validator: (val) {
                                      final d = double.tryParse(val ?? '');
                                      if (d == null || d <= 0) {
                                        return AppLocalization.invalidScore;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Tanggal Penilaian
                                  InkWell(
                                    onTap: () => _selectDate(context),
                                    borderRadius: BorderRadius.circular(16),
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
                                            AppLocalization.isIndonesian ? 'Tanggal Penilaian:' : 'Grade Date:',
                                            style: TextStyle(color: subTextColor, fontSize: 13),
                                          ),
                                          Text(
                                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                            style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Section Title: Siswa
                        if (_selectedClassId != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.people_alt_rounded, color: iconColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalization.studentGradeListLabel,
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Student List Section
                        if (_selectedClassId != null)
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _gradeService.getStudentsByClass(
                              user.schoolId,
                              _selectedClassId!,
                              tahunAjaran: _tahunAjaran,
                              semester: _activeSemester,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Text(
                                      'Gagal memuat siswa: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                );
                              }

                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SliverToBoxAdapter(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                                    ),
                                  ),
                                );
                              }

                              final students = (snapshot.data?.docs ?? []).toList();
                              students.sort((a, b) {
                                final nameA = (a.data()['nama'] ?? '').toString().toLowerCase();
                                final nameB = (b.data()['nama'] ?? '').toString().toLowerCase();
                                return nameA.compareTo(nameB);
                              });

                              if (students.isEmpty) {
                                return SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Center(
                                      child: Text(
                                        'Tidak ada siswa di kelas ini',
                                        style: TextStyle(color: subTextColor),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final student = students[index];
                                      String studentId = student.data()['studentId'] ?? student.id;
                                      if (studentId.contains('_') && _tahunAjaran != null && _activeSemester != null) {
                                        final cleanYear = _tahunAjaran!.replaceAll('/', '_');
                                        final suffix = '_${cleanYear}_$_activeSemester';
                                        if (studentId.endsWith(suffix)) {
                                          studentId = studentId.substring(0, studentId.length - suffix.length);
                                        }
                                      }
                                      final studentName = student.data()['nama'] ?? 'Siswa';
                                      final nis = student.data()['nis'] ?? '-';



                                      // Inisialisasi controller jika belum ada
                                      if (!_scoreControllers.containsKey(studentId)) {
                                        _scoreControllers[studentId] = TextEditingController(text: '');
                                      }
                                      if (!_noteControllers.containsKey(studentId)) {
                                        _noteControllers[studentId] = TextEditingController(text: '');
                                      }

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: cardBgColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: cardBorderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                                  child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6)),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        studentName,
                                                        style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 14),
                                                      ),
                                                      Text(
                                                        'NIS: $nis',
                                                        style: TextStyle(fontSize: 11, color: subTextColor),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Input Nilai
                                                SizedBox(
                                                  width: 70,
                                                  child: TextFormField(
                                                    controller: _scoreControllers[studentId],
                                                    keyboardType: TextInputType.number,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                                                    decoration: InputDecoration(
                                                      hintText: '0',
                                                      hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.4)),
                                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                      fillColor: inputFillColor,
                                                      filled: true,
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                        borderSide: BorderSide(color: cardBorderColor),
                                                      ),
                                                    ),
                                                    validator: (val) {
                                                      if (val != null && val.isNotEmpty) {
                                                        final d = double.tryParse(val);
                                                        final double max = double.tryParse(_maxScoreController.text) ?? 100.0;
                                                        if (d == null || d < 0 || d > max) {
                                                          return AppLocalization.wrongScoreRange;
                                                        }
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // Input Catatan Siswa
                                            TextFormField(
                                              controller: _noteControllers[studentId],
                                              style: TextStyle(color: titleColor, fontSize: 12),
                                              decoration: InputDecoration(
                                                hintText: AppLocalization.studentNotePlaceholder,
                                                hintStyle: TextStyle(color: subTextColor.withValues(alpha: 0.5), fontSize: 12),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                fillColor: inputFillColor,
                                                filled: true,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide(color: cardBorderColor),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    childCount: students.length,
                                  ),
                                ),
                              );
                            },
                          ),

                        // Spacer
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 100),
                        ),
                      ],
                    ),
                  ),
          ),
          bottomSheet: _selectedClassId == null
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F0C20) : Colors.white,
                    border: Border(top: BorderSide(color: cardBorderColor)),
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveGradeData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isEditing ? AppLocalization.saveChanges : AppLocalization.saveGrade,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
        );
          },
        );
      },
    );
  }

  Widget _buildSemesterStateBanner() {
    final semesterError = SemesterStateService.validateInput();
    if (semesterError == null) return const SizedBox.shrink();

    final status = SemesterStateService.status;
    final color = status == SemesterStatus.ditutup ? Colors.red : Colors.amber;
    final icon = status == SemesterStatus.ditutup ? Icons.lock : Icons.beach_access;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akses Dibatasi - ${SemesterStateService.statusLabel}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  semesterError,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
