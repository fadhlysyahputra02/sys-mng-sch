import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../authentication/widgets/auth_background.dart';
import '../../../core/services/session_service.dart';

class StudentGradesPage extends StatefulWidget {
  final String studentDocId;
  final String className;
  final String classId;
  final String tahunAjaran;
  final String semester;

  const StudentGradesPage({
    super.key,
    required this.studentDocId,
    required this.className,
    required this.classId,
    required this.tahunAjaran,
    required this.semester,
  });

  @override
  State<StudentGradesPage> createState() => _StudentGradesPageState();
}

class _StudentGradesPageState extends State<StudentGradesPage> {
  // Grades dikelompokkan per mata pelajaran
  // { subjectName: { subjectId, categories: { category: [{ title, score, maxScore, date }] } } }
  Map<String, Map<String, dynamic>> _groupedGrades = {};
  Map<String, double> _subjectWeightedAvg = {};
  final Set<String> _expandedSubjects = {};
  Map<String, dynamic>? _gradeTemplates;
  bool _isLoading = true;
  String? _error;

  void _toggleExpand(String subjectName) {
    setState(() {
      if (_expandedSubjects.contains(subjectName)) {
        _expandedSubjects.remove(subjectName);
      } else {
        _expandedSubjects.add(subjectName);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = SessionService.currentUser!;
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .get();
      final gradeTemplates =
          schoolDoc.data()?['grade_templates'] as Map<String, dynamic>?;

      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('grades')
          .where('classId', isEqualTo: widget.classId)
          .where('tahunAjaran', isEqualTo: widget.tahunAjaran)
          .where('semester', isEqualTo: widget.semester)
          .get();

      final Map<String, Map<String, dynamic>> grouped = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scores = data['scores'] as Map<String, dynamic>? ?? {};
        // Hanya ambil nilai yang ada untuk murid ini
        if (!scores.containsKey(widget.studentDocId)) continue;

        final studentScoreData =
            scores[widget.studentDocId] as Map<String, dynamic>? ?? {};
        final double score = ((studentScoreData['score'] ?? 0.0) as num).toDouble();
        final String notes = (studentScoreData['notes'] ?? '').toString();

        final String subjectName = data['subjectName'] ?? 'Mata Pelajaran';
        final String subjectId = data['subjectId'] ?? '';
        final String category = data['category'] ?? 'Tugas';
        final String title = data['title'] ?? 'Penilaian';
        final double maxScore = ((data['maxScore'] ?? 100.0) as num).toDouble();
        final String date = data['date'] ?? '-';

        if (!grouped.containsKey(subjectName)) {
          grouped[subjectName] = {
            'subjectId': subjectId,
            'subjectName': subjectName,
            'categories': <String, List<Map<String, dynamic>>>{},
          };
        }
        final categories =
            grouped[subjectName]!['categories']
                as Map<String, List<Map<String, dynamic>>>;
        if (!categories.containsKey(category)) {
          categories[category] = [];
        }
        categories[category]!.add({
          'title': title,
          'score': score,
          'maxScore': maxScore,
          'date': date,
          'notes': notes,
        });
      }

      // Hitung nilai rata-rata per mapel (dengan mempertimbangkan bobot jika ada)
      final Map<String, double> weightedAvg = {};
      for (final entry in grouped.entries) {
        final subjectName = entry.key;
        final subjectId = entry.value['subjectId'] as String;
        final categories =
            entry.value['categories']
                as Map<String, List<Map<String, dynamic>>>;

        // Coba ambil bobot dari Firestore
        Map<String, double>? weights;
        try {
          final user = SessionService.currentUser!;
          final docId =
              '${widget.classId}_${subjectId}_${widget.tahunAjaran.replaceAll('/', '_')}_${widget.semester}';
          final weightDoc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(user.schoolId)
              .collection('subject_weights')
              .doc(docId)
              .get();
          if (weightDoc.exists && weightDoc.data()?['weights'] != null) {
            final raw = weightDoc.data()!['weights'] as Map<String, dynamic>;
            weights = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
          }
        } catch (_) {}

        if (weights != null) {
          double weightedSum = 0;
          double weightSum = 0;
          categories.forEach((cat, items) {
            final catWeight = weights![cat] ?? 0.0;
            if (catWeight > 0 && items.isNotEmpty) {
              double catAvg =
                  items.fold(0.0, (sum, item) {
                    final s = (item['score'] as num).toDouble();
                    final max = (item['maxScore'] as num).toDouble();
                    return sum + (max > 0 ? (s / max) * 100 : 0);
                  }) /
                  items.length;
              weightedSum += catAvg * catWeight;
              weightSum += catWeight;
            }
          });
          weightedAvg[subjectName] = weightSum > 0
              ? weightedSum / weightSum
              : 0.0;
        } else {
          // Rata-rata biasa
          double totalScore = 0;
          int count = 0;
          categories.forEach((cat, items) {
            for (final item in items) {
              final s = (item['score'] as num).toDouble();
              final max = (item['maxScore'] as num).toDouble();
              totalScore += max > 0 ? (s / max) * 100 : 0;
              count++;
            }
          });
          weightedAvg[subjectName] = count > 0 ? totalScore / count : 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _groupedGrades = grouped;
          _subjectWeightedAvg = weightedAvg;
          _gradeTemplates = gradeTemplates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getScoreColor(double score) {
    if (_gradeTemplates != null) {
      if (score >= (_gradeTemplates!['aminus'] ?? 85))
        return const Color(0xFF10B981);
      if (score >= (_gradeTemplates!['bminus'] ?? 70))
        return const Color(0xFF3B82F6);
      if (score >= (_gradeTemplates!['cminus'] ?? 55))
        return const Color(0xFFF59E0B);
      return const Color(0xFFEF4444);
    }
    if (score >= 85) return const Color(0xFF10B981);
    if (score >= 70) return const Color(0xFF3B82F6);
    if (score >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getScoreLabel(double score) {
    if (_gradeTemplates != null) {
      if (score >= (_gradeTemplates!['aplus'] ?? 95)) return 'A+';
      if (score >= (_gradeTemplates!['a'] ?? 90)) return 'A';
      if (score >= (_gradeTemplates!['aminus'] ?? 85)) return 'A-';
      if (score >= (_gradeTemplates!['bplus'] ?? 80)) return 'B+';
      if (score >= (_gradeTemplates!['b'] ?? 75)) return 'B';
      if (score >= (_gradeTemplates!['bminus'] ?? 70)) return 'B-';
      if (score >= (_gradeTemplates!['cplus'] ?? 65)) return 'C+';
      if (score >= (_gradeTemplates!['c'] ?? 60)) return 'C';
      if (score >= (_gradeTemplates!['cminus'] ?? 55)) return 'C-';
      return 'D';
    }

    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'E';
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        final month = int.parse(parts[1]);
        return '${parts[2]} ${months[month]} ${parts[0]}';
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.55)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.55);
        final cardBg = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.07);
        final shadowColor = isDark
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.04);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final iconBgColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar
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
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: iconColor,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nilai Saya',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: titleColor,
                        ),
                      ),
                      Text(
                        '${widget.tahunAjaran}  •  ${widget.semester}',
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
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: iconColor,
                          size: 20,
                        ),
                        tooltip: 'Refresh',
                        onPressed: _loadGrades,
                      ),
                    ),
                  ],
                ),

                // Content
                if (_isLoading)
                  SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                      ),
                    ),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 56,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Gagal memuat data nilai',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadGrades,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_groupedGrades.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.grade_rounded,
                            size: 72,
                            color: subTextColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Nilai',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nilai Anda akan tampil di sini\nsetelah guru memasukkan nilai.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subTextColor, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final entries = _groupedGrades.entries.toList();
                        final entry = entries[index];
                        final subjectName = entry.key;
                        final categories =
                            entry.value['categories']
                                as Map<String, List<Map<String, dynamic>>>;
                        final avg = _subjectWeightedAvg[subjectName] ?? 0.0;
                        final scoreColor = _getScoreColor(avg);
                        final scoreLabel = _getScoreLabel(avg);
                        final isExpanded = _expandedSubjects.contains(
                          subjectName,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorder),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: shadowColor,
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Mapel
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _toggleExpand(subjectName),
                                  borderRadius: BorderRadius.vertical(
                                    top: const Radius.circular(24),
                                    bottom: Radius.circular(
                                      isExpanded ? 0 : 24,
                                    ),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      18,
                                      20,
                                      14,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF8B5CF6).withValues(
                                            alpha: isDark ? 0.25 : 0.12,
                                          ),
                                          const Color(0xFF6366F1).withValues(
                                            alpha: isDark ? 0.1 : 0.05,
                                          ),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.vertical(
                                        top: const Radius.circular(24),
                                        bottom: Radius.circular(
                                          isExpanded ? 0 : 24,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF8B5CF6,
                                            ).withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.book_rounded,
                                            color: Color(0xFF8B5CF6),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                subjectName,
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                widget.className,
                                                style: TextStyle(
                                                  color: subTextColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Badge nilai akhir
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: scoreColor.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: scoreColor.withValues(
                                                    alpha: 0.4,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    avg.toStringAsFixed(1),
                                                    style: TextStyle(
                                                      color: scoreColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: scoreColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      scoreLabel,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  'Nilai Akhir',
                                                  style: TextStyle(
                                                    color: subTextColor,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  isExpanded
                                                      ? Icons
                                                            .keyboard_arrow_up_rounded
                                                      : Icons
                                                            .keyboard_arrow_down_rounded,
                                                  color: subTextColor,
                                                  size: 14,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Rincian Per Kategori
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    12,
                                    20,
                                    18,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: categories.entries.map((
                                      catEntry,
                                    ) {
                                      final catName = catEntry.key;
                                      final items = catEntry.value;
                                      double catAvg = 0;
                                      if (items.isNotEmpty) {
                                        catAvg =
                                            items.fold(0.0, (sum, item) {
                                              final s = (item['score'] as num).toDouble();
                                              final max =
                                                  (item['maxScore'] as num).toDouble();
                                              return sum +
                                                  (max > 0
                                                      ? (s / max) * 100
                                                      : 0);
                                            }) /
                                            items.length;
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Label Kategori
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _getCategoryColor(
                                                    catName,
                                                  ).withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: _getCategoryColor(
                                                      catName,
                                                    ).withValues(alpha: 0.35),
                                                  ),
                                                ),
                                                child: Text(
                                                  catName,
                                                  style: TextStyle(
                                                    color: _getCategoryColor(
                                                      catName,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                'Rata-rata: ${catAvg.toStringAsFixed(1)}',
                                                style: TextStyle(
                                                  color: _getScoreColor(catAvg),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Item Penilaian
                                          ...items.map((item) {
                                            final s = (item['score'] as num).toDouble();
                                            final max =
                                                (item['maxScore'] as num).toDouble();
                                            final pct = max > 0
                                                ? (s / max) * 100
                                                : 0.0;
                                            final itemColor = _getScoreColor(
                                              pct,
                                            );

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withValues(
                                                        alpha: 0.04,
                                                      )
                                                    : Colors.black.withValues(
                                                        alpha: 0.02,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: cardBorder,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          item['title']
                                                              as String,
                                                          style: TextStyle(
                                                            color: titleColor,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          _formatDate(
                                                            item['date']
                                                                as String,
                                                          ),
                                                          style: TextStyle(
                                                            color: subTextColor,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        if ((item['notes']
                                                                as String)
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                            height: 3,
                                                          ),
                                                          Text(
                                                            item['notes']
                                                                as String,
                                                            style: TextStyle(
                                                              color:
                                                                  subTextColor,
                                                              fontSize: 11,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        s.toStringAsFixed(
                                                          s % 1 == 0 ? 0 : 1,
                                                        ),
                                                        style: TextStyle(
                                                          color: itemColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 18,
                                                        ),
                                                      ),
                                                      Text(
                                                        '/ ${max.toStringAsFixed(max % 1 == 0 ? 0 : 1)}',
                                                        style: TextStyle(
                                                          color: subTextColor,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          const SizedBox(height: 8),
                                          Divider(
                                            color: cardBorder,
                                            height: 1,
                                            thickness: 1,
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }, childCount: _groupedGrades.length),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Tugas':
        return const Color(0xFF3B82F6);
      case 'Kuis':
        return const Color(0xFF8B5CF6);
      case 'Ulangan Harian':
        return const Color(0xFFF59E0B);
      case 'UTS':
        return const Color(0xFFF97316);
      case 'UAS':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }
}
