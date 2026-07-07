import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../services/grade_service.dart';
import '../services/grade_pdf_helper.dart';

class TeacherGradeRecapPage extends StatefulWidget {
  final String schoolId;
  final String classId;
  final String className;
  final String teacherId;

  const TeacherGradeRecapPage({
    super.key,
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.teacherId,
  });

  @override
  State<TeacherGradeRecapPage> createState() => _TeacherGradeRecapPageState();
}

class _TeacherGradeRecapPageState extends State<TeacherGradeRecapPage> {
  final _gradeService = GradeService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'nama'; // 'nama', 'nilai_tertinggi', 'nilai_terendah'


  String _schoolName = 'Sekolah';
  String _teacherName = 'Wali Kelas';
  String _tahunAjaran = '';
  String _activeSemester = '';
  bool _isLoadingMetaData = true;
  // Mapping dari Auth UID → Student Document ID untuk backward-compatibility
  Map<String, String> _authUidToDocIdMap = {};

  @override
  void initState() {
    super.initState();
    _loadMetaData();
  }

  Future<void> _loadMetaData() async {
    try {
      final schoolFuture = SchoolService().getSchoolByDomain(widget.schoolId);
      Future<DocumentSnapshot<Map<String, dynamic>>?> teacherFuture = Future.value(null);
      
      if (widget.teacherId.isNotEmpty) {
        teacherFuture = FirebaseFirestore.instance
            .collection('schools')
            .doc(widget.schoolId)
            .collection('teachers')
            .doc(widget.teacherId)
            .get();
      }

      final results = await Future.wait([schoolFuture, teacherFuture]);
      final schoolData = results[0] as Map<String, dynamic>?;
      final teacherDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>?;

      // Build mapping Auth UID → Student Document ID
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('students')
          .where('classId', isEqualTo: widget.classId)
          .get();
      final Map<String, String> uidMap = {};
      for (final doc in studentsSnapshot.docs) {
        final uid = doc.data()['uid']?.toString();
        if (uid != null && uid.isNotEmpty && uid != doc.id) {
          uidMap[uid] = doc.id;
        }
      }

      if (mounted) {
        setState(() {
          _authUidToDocIdMap = uidMap;
          if (schoolData != null) {
            _schoolName = schoolData['namaSekolah'] ?? 'Sekolah';
            _tahunAjaran = schoolData['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
            _activeSemester = schoolData['semester'] ?? 'Semester 1';
          }
          if (teacherDoc != null && teacherDoc.exists) {
            _teacherName = teacherDoc.data()?['nama'] ?? 'Wali Kelas';
          }
          _isLoadingMetaData = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
      if (mounted) {
        setState(() {
          _isLoadingMetaData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Menghitung Nilai Akhir siswa per-mapel secara dinamis berdasarkan nilai dan bobot kategori yang aktif
  Map<String, double> _calculateFinalGradesForStudent({
    required String studentId,
    required Map<String, String> subjectIdToName,
    required Map<String, Map<String, List<Map<String, dynamic>>>> subjectCategoryGrades,
    required Map<String, Map<String, double>> subjectWeightsMap,
  }) {
    final Map<String, double> results = {};

    subjectIdToName.forEach((subjectId, _) {
      final catGrades = subjectCategoryGrades[subjectId] ?? {};
      final Map<String, double> categoryAverages = {};

      // 1. Hitung rata-rata nilai siswa untuk setiap kategori
      catGrades.forEach((category, listScores) {
        double sum = 0.0;
        int count = 0;
        for (final scores in listScores) {
          final cleanYear = _tahunAjaran.replaceAll('/', '_');
          final fallbackKey = '${studentId}_${cleanYear}_$_activeSemester';
          // Cari key Auth UID yang mungkin merujuk ke studentId ini
          final authUidKey = _authUidToDocIdMap.entries
              .where((e) => e.value == studentId)
              .map((e) => e.key)
              .firstOrNull;
          final detail = scores[studentId] ?? scores[fallbackKey] ?? (authUidKey != null ? scores[authUidKey] : null);
          if (detail != null && detail is Map) {
            final scoreVal = (detail['score'] ?? 0.0) as num;
            sum += scoreVal.toDouble();
            count++;
          }
        }
        if (count > 0) {
          categoryAverages[category] = sum / count;
        }
      });

      // Jika tidak ada nilai sama sekali untuk mapel ini, lewati
      if (categoryAverages.isEmpty) return;

      // 2. Ambil bobot kategori untuk mapel ini
      final weights = subjectWeightsMap[subjectId] ?? {
        'Tugas': 20.0,
        'Kuis': 20.0,
        'Ulangan Harian': 20.0,
        'UTS': 20.0,
        'UAS': 20.0,
      };

      // 3. Hitung bobot total dan total nilai
      double weightedSum = 0.0;
      final double totalWeightSum = weights.values.fold(0.0, (total, w) => total + w);

      categoryAverages.forEach((category, avg) {
        final w = weights[category] ?? 20.0;
        weightedSum += avg * w;
      });

      if (totalWeightSum > 0) {
        results[subjectId] = weightedSum / totalWeightSum;
      }
    });

    return results;
  }

  /// Menampilkan lembar rincian nilai siswa per-mata pelajaran (Bottom Sheet)
  void _showStudentDetailBottomSheet({
    required BuildContext context,
    required Map<String, dynamic> student,
    required bool isDark,
    required Map<String, String> subjectIdToName,
    required Map<String, Map<String, List<Map<String, dynamic>>>> subjectCategoryGrades,
    required Map<String, Map<String, double>> subjectWeightsMap,
    required Map<String, double> calculatedGrades,
    required Map<String, String> subjectIdToTeacher,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.02);
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Indikator Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header Detail Siswa
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
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
                          (student['nama'] ?? 'S')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['nama'] ?? '-',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIS: ${student['nis'] ?? '-'}',
                              style: TextStyle(fontSize: 13, color: subTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),

                // List Rincian Nilai Mapel
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    itemCount: subjectIdToName.length,
                    itemBuilder: (context, index) {
                      final subjectId = subjectIdToName.keys.elementAt(index);
                      final subjectName = subjectIdToName[subjectId] ?? '-';
                      final teacherName = subjectIdToTeacher[subjectId] ?? '';
                      final double? finalGrade = calculatedGrades[subjectId];

                      // Ambil detail nilai per kategori
                      final catGrades = subjectCategoryGrades[subjectId] ?? {};
                      final Map<String, double> categoryAverages = {};
                      catGrades.forEach((category, listScores) {
                        double sum = 0.0;
                        int count = 0;
                        for (final scores in listScores) {
                          final studentId = student['studentId']?.toString() ?? '';
                          final cleanYear = _tahunAjaran.replaceAll('/', '_');
                          final fallbackKey = '${studentId}_${cleanYear}_$_activeSemester';
                          // Cari key Auth UID yang mungkin merujuk ke studentId ini
                          final authUidKey = _authUidToDocIdMap.entries
                              .where((e) => e.value == studentId)
                              .map((e) => e.key)
                              .firstOrNull;
                          final detail = scores[studentId] ?? scores[fallbackKey] ?? (authUidKey != null ? scores[authUidKey] : null);
                          if (detail != null && detail is Map) {
                            final scoreVal = (detail['score'] ?? 0.0) as num;
                            sum += scoreVal.toDouble();
                            count++;
                          }
                        }
                        if (count > 0) {
                          categoryAverages[category] = sum / count;
                        }
                      });

                      final weights = subjectWeightsMap[subjectId] ?? {
                        'Tugas': 20.0,
                        'Kuis': 20.0,
                        'Ulangan Harian': 20.0,
                        'UTS': 20.0,
                        'UAS': 20.0,
                      };

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: subjectName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                      ),
                                      children: [
                                        if (teacherName.isNotEmpty) ...[
                                          const WidgetSpan(child: SizedBox(width: 8)),
                                          TextSpan(
                                            text: '(Guru: $teacherName)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: subTextColor,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: finalGrade != null
                                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                        : Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    finalGrade != null
                                        ? finalGrade.toStringAsFixed(1)
                                        : '-',
                                    style: TextStyle(
                                      color: finalGrade != null
                                          ? const Color(0xFF10B981)
                                          : Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Rincian kategori rata-rata
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['Tugas', 'Kuis', 'Ulangan Harian', 'UTS', 'UAS'].map((cat) {
                                final avg = categoryAverages[cat];
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: Text(
                                    '$cat: ${avg != null ? avg.toStringAsFixed(0) : "-"}',
                                    style: TextStyle(fontSize: 11, color: titleColor.withValues(alpha: 0.8)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                            // Info bobot
                            Text(
                              'Bobot Kategori: Tugas ${weights['Tugas']?.toStringAsFixed(0)}%, Kuis ${weights['Kuis']?.toStringAsFixed(0)}%, UH ${weights['Ulangan Harian']?.toStringAsFixed(0)}%, UTS ${weights['UTS']?.toStringAsFixed(0)}%, UAS ${weights['UAS']?.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 10,
                                color: subTextColor,
                              ),
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

        return Scaffold(
          body: AuthBackground(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _gradeService.getStudentsByClass(
                widget.schoolId,
                widget.classId,
                tahunAjaran: _tahunAjaran,
                semester: _activeSemester,
              ),
              builder: (context, studentsSnapshot) {
                if (studentsSnapshot.connectionState == ConnectionState.waiting || _isLoadingMetaData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                    ),
                  );
                }

                final studentDocs = studentsSnapshot.data?.docs ?? [];
                final List<Map<String, dynamic>> studentsList = studentDocs.map((doc) {
                  final data = doc.data();
                  data['studentId'] ??= doc.id;
                  return data;
                }).toList();

                // Urutkan Murid berdasarkan nama A-Z
                studentsList.sort((a, b) {
                  final String nameA = (a['nama'] ?? '').toString().toLowerCase();
                  final String nameB = (b['nama'] ?? '').toString().toLowerCase();
                  return nameA.compareTo(nameB);
                });

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _gradeService.getGradesByClass(
                    schoolId: widget.schoolId, 
                    classId: widget.classId,
                    tahunAjaran: _tahunAjaran,
                    semester: _activeSemester,
                  ),
                  builder: (context, gradesSnapshot) {
                    if (gradesSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                        ),
                      );
                    }

                    // Ekstrak data grade & mapel
                    final gradeDocs = gradesSnapshot.data?.docs ?? [];
                    final Map<String, Map<String, List<Map<String, dynamic>>>> subjectCategoryGrades = {};
                    final Map<String, String> subjectIdToName = {};
                    final Map<String, String> subjectIdToTeacher = {};

                    for (final doc in gradeDocs) {
                      final data = doc.data();
                      final subjectId = data['subjectId'] as String?;
                      final subjectName = data['subjectName'] as String?;
                      final category = data['category'] as String?;
                      final scores = data['scores'] as Map<String, dynamic>? ?? {};
                      final teacherName = data['teacherName'] as String? ?? '';

                      if (subjectId != null && category != null && subjectName != null) {
                        subjectIdToName[subjectId] = subjectName;
                        if (teacherName.isNotEmpty) {
                          subjectIdToTeacher[subjectId] = teacherName;
                        }

                        subjectCategoryGrades.putIfAbsent(subjectId, () => {});
                        subjectCategoryGrades[subjectId]!.putIfAbsent(category, () => []);
                        subjectCategoryGrades[subjectId]![category]!.add(scores);
                      }
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(widget.schoolId)
                          .collection('subject_weights')
                          .where('classId', isEqualTo: widget.classId)
                          .where('tahunAjaran', isEqualTo: _tahunAjaran)
                          .where('semester', isEqualTo: _activeSemester)
                          .snapshots(),
                      builder: (context, weightsSnapshot) {
                        if (weightsSnapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                            ),
                          );
                        }

                        // Ekstrak data bobot
                        final weightDocs = weightsSnapshot.data?.docs ?? [];
                        final Map<String, Map<String, double>> subjectWeightsMap = {};
                        for (final doc in weightDocs) {
                          final data = doc.data();
                          final subjectId = data['subjectId'] as String?;
                          final w = data['weights'] as Map<String, dynamic>?;
                          if (subjectId != null && w != null) {
                            subjectWeightsMap[subjectId] = w.map((k, v) => MapEntry(k, (v as num).toDouble()));
                          }
                        }

                        // Kalkulasi nilai seluruh siswa
                        final Map<String, Map<String, double>> studentGradesCalculated = {};
                        final Map<String, double> studentRerataAkhir = {};

                        for (final student in studentsList) {
                          final studentId = student['studentId']?.toString() ?? '';
                          final grades = _calculateFinalGradesForStudent(
                            studentId: studentId,
                            subjectIdToName: subjectIdToName,
                            subjectCategoryGrades: subjectCategoryGrades,
                            subjectWeightsMap: subjectWeightsMap,
                          );
                          studentGradesCalculated[studentId] = grades;

                          if (grades.isNotEmpty) {
                            double sum = 0.0;
                            grades.forEach((_, score) => sum += score);
                            studentRerataAkhir[studentId] = sum / grades.length;
                          }
                        }

                        // Saring siswa berdasarkan query pencarian
                        final filteredStudents = studentsList.where((student) {
                          final name = (student['nama'] ?? '').toString().toLowerCase();
                          final nis = (student['nis'] ?? '').toString().toLowerCase();
                          final query = _searchQuery.toLowerCase();
                          return name.contains(query) || nis.contains(query);
                        }).toList();

                        // Urutkan siswa berdasarkan pilihan filter
                        if (_sortBy == 'nilai_tertinggi') {
                          filteredStudents.sort((a, b) {
                            final idA = a['studentId']?.toString() ?? '';
                            final idB = b['studentId']?.toString() ?? '';
                            final valA = studentRerataAkhir[idA];
                            final valB = studentRerataAkhir[idB];
                            if (valA == null && valB == null) return 0;
                            if (valA == null) return 1;
                            if (valB == null) return -1;
                            return valB.compareTo(valA);
                          });
                        } else if (_sortBy == 'nilai_terendah') {
                          filteredStudents.sort((a, b) {
                            final idA = a['studentId']?.toString() ?? '';
                            final idB = b['studentId']?.toString() ?? '';
                            final valA = studentRerataAkhir[idA];
                            final valB = studentRerataAkhir[idB];
                            if (valA == null && valB == null) return 0;
                            if (valA == null) return 1;
                            if (valB == null) return -1;
                            return valA.compareTo(valB);
                          });
                        } else {
                          // Default: urutan nama A-Z
                          filteredStudents.sort((a, b) {
                            final String nameA = (a['nama'] ?? '').toString().toLowerCase();
                            final String nameB = (b['nama'] ?? '').toString().toLowerCase();
                            return nameA.compareTo(nameB);
                          });
                        }

                        // Ekspor PDF Function
                        void handlePdfExport() {
                          if (studentsList.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tidak ada data siswa untuk diekspor'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }

                          final List<Map<String, String>> subjectsList = subjectIdToName.entries
                              .map((e) => {'id': e.key, 'name': e.value})
                              .toList();

                          // Urutkan daftar mapel alfabetis agar kolom di PDF rapi
                          subjectsList.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

                          // Urutkan daftar siswa ekspor sesuai pilihan filter
                          final List<Map<String, dynamic>> sortedExportStudents = List.from(studentsList);
                          if (_sortBy == 'nilai_tertinggi') {
                            sortedExportStudents.sort((a, b) {
                              final idA = a['studentId']?.toString() ?? '';
                              final idB = b['studentId']?.toString() ?? '';
                              final valA = studentRerataAkhir[idA];
                              final valB = studentRerataAkhir[idB];
                              if (valA == null && valB == null) return 0;
                              if (valA == null) return 1;
                              if (valB == null) return -1;
                              return valB.compareTo(valA);
                            });
                          } else if (_sortBy == 'nilai_terendah') {
                            sortedExportStudents.sort((a, b) {
                              final idA = a['studentId']?.toString() ?? '';
                              final idB = b['studentId']?.toString() ?? '';
                              final valA = studentRerataAkhir[idA];
                              final valB = studentRerataAkhir[idB];
                              if (valA == null && valB == null) return 0;
                              if (valA == null) return 1;
                              if (valB == null) return -1;
                              return valA.compareTo(valB);
                            });
                          } else {
                            sortedExportStudents.sort((a, b) {
                              final String nameA = (a['nama'] ?? '').toString().toLowerCase();
                              final String nameB = (b['nama'] ?? '').toString().toLowerCase();
                              return nameA.compareTo(nameB);
                            });
                          }

                          GradePdfHelper.generateAndShowPdf(
                            schoolName: _schoolName,
                            className: widget.className,
                            teacherName: _teacherName,
                            students: sortedExportStudents,
                            subjects: subjectsList,
                            studentGrades: studentGradesCalculated,
                            tahunAjaran: _tahunAjaran,
                            semester: _activeSemester,
                          );
                        }

                        return CustomScrollView(
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
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rekap Nilai Kelas',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                                  ),
                                  Text(
                                    widget.className,
                                    style: TextStyle(fontSize: 11, color: subTextColor),
                                  ),
                                ],
                              ),
                              actions: [
                                Container(
                                  margin: const EdgeInsets.only(right: 16),
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.picture_as_pdf_rounded, color: iconColor, size: 20),
                                    tooltip: 'Ekspor Buku Nilai PDF',
                                    onPressed: handlePdfExport,
                                  ),
                                ),
                              ],
                            ),

                            // Search bar
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: cardBorderColor),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    style: TextStyle(color: titleColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Cari murid berdasarkan nama atau NIS...',
                                      hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                      border: InputBorder.none,
                                      icon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  _searchController.clear();
                                                  _searchQuery = '';
                                                });
                                              },
                                              child: Icon(Icons.close_rounded, color: subTextColor, size: 18),
                                            )
                                          : null,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // Info kelas ringkasan
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Daftar Murid (${filteredStudents.length})',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _sortBy == 'nilai_tertinggi'
                                              ? 'Nilai Tertinggi'
                                              : _sortBy == 'nilai_terendah'
                                                  ? 'Nilai Terendah'
                                                  : 'Nama (A-Z)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: subTextColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        PopupMenuButton<String>(
                                           initialValue: _sortBy,
                                          icon: Icon(Icons.sort_rounded, color: iconColor, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Urutkan Murid',
                                          color: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(
                                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                                            ),
                                          ),
                                          onSelected: (String value) {
                                            setState(() {
                                              _sortBy = value;
                                            });
                                          },
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                            PopupMenuItem<String>(
                                              value: 'nama',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.sort_by_alpha_rounded, color: iconColor, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text('Nama (A-Z)', style: TextStyle(color: titleColor, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'nilai_tertinggi',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.arrow_upward_rounded, color: iconColor, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text('Nilai Tertinggi', style: TextStyle(color: titleColor, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'nilai_terendah',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.arrow_downward_rounded, color: iconColor, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text('Nilai Terendah', style: TextStyle(color: titleColor, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Students recap list
                            if (filteredStudents.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off_rounded, size: 48, color: subTextColor),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Murid tidak ditemukan',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Coba gunakan kata kunci pencarian yang lain.',
                                          style: TextStyle(fontSize: 12, color: subTextColor),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final student = filteredStudents[index];
                                      final studentId = student['studentId']?.toString() ?? '';
                                      final studentName = student['nama'] ?? '-';
                                      final studentNis = student['nis'] ?? '-';
                                      final double? rerata = studentRerataAkhir[studentId];

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
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
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              _showStudentDetailBottomSheet(
                                                context: context,
                                                student: student,
                                                isDark: isDark,
                                                subjectIdToName: subjectIdToName,
                                                subjectCategoryGrades: subjectCategoryGrades,
                                                subjectWeightsMap: subjectWeightsMap,
                                                calculatedGrades: studentGradesCalculated[studentId] ?? {},
                                                subjectIdToTeacher: subjectIdToTeacher,
                                              );
                                            },
                                            borderRadius: BorderRadius.circular(20),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: LinearGradient(
                                                        colors: isDark
                                                            ? [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]
                                                            : [const Color(0xFF8B5CF6).withValues(alpha: 0.15), const Color(0xFFEC4899).withValues(alpha: 0.15)],
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      studentName[0].toUpperCase(),
                                                      style: TextStyle(
                                                        color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          studentName,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.bold,
                                                            color: titleColor,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          'NIS: $studentNis',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: subTextColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Rerata Nilai',
                                                        style: TextStyle(fontSize: 10, color: subTextColor),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: rerata != null
                                                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                                                              : Colors.amber.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          rerata != null ? rerata.toStringAsFixed(1) : '-',
                                                          style: TextStyle(
                                                            color: rerata != null ? const Color(0xFF8B5CF6) : Colors.amber,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: filteredStudents.length,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
