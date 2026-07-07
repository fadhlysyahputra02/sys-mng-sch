import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ParentStudentGradesSection extends StatefulWidget {
  final String schoolId;
  final String studentId;
  final String classId;
  final String className;
  final String tahunAjaran;
  final String semester;
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final Color cardBg;
  final Color cardBorder;

  const ParentStudentGradesSection({
    super.key,
    required this.schoolId,
    required this.studentId,
    required this.classId,
    required this.className,
    required this.tahunAjaran,
    required this.semester,
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    required this.cardBg,
    required this.cardBorder,
  });

  @override
  State<ParentStudentGradesSection> createState() =>
      ParentStudentGradesSectionState();
}

class ParentStudentGradesSectionState extends State<ParentStudentGradesSection> {
  Map<String, Map<String, dynamic>> _groupedGrades = {};
  Map<String, double> _subjectWeightedAvg = {};
  final Set<String> _expandedSubjects = {};
  Map<String, dynamic>? _gradeTemplates;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    loadGrades();
  }

  Future<void> loadGrades() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();
      final gradeTemplates =
          schoolDoc.data()?['grade_templates'] as Map<String, dynamic>?;

      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('grades')
          .where('classId', isEqualTo: widget.classId)
          .where('tahunAjaran', isEqualTo: widget.tahunAjaran)
          .where('semester', isEqualTo: widget.semester)
          .get();

      final Map<String, Map<String, dynamic>> grouped = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scores = data['scores'] as Map<String, dynamic>? ?? {};
        
        final cleanYear = widget.tahunAjaran.replaceAll('/', '_');
        final fallbackKey = '${widget.studentId}_${cleanYear}_${widget.semester}';
        
        final hasPlainKey = scores.containsKey(widget.studentId);
        final hasFallbackKey = scores.containsKey(fallbackKey);
        
        if (!hasPlainKey && !hasFallbackKey) continue;

        final studentScoreData =
            (scores[widget.studentId] ?? scores[fallbackKey]) as Map<String, dynamic>? ?? {};
        final double score = (studentScoreData['score'] as num?)?.toDouble() ?? 0.0;
        final String notes = (studentScoreData['notes'] ?? '').toString();
        final String subjectName = data['subjectName'] ?? 'Mata Pelajaran';
        final String subjectId = data['subjectId'] ?? '';
        final String category = data['category'] ?? 'Tugas';
        final String title = data['title'] ?? 'Penilaian';
        final double maxScore = (data['maxScore'] as num?)?.toDouble() ?? 100.0;
        final String date = data['date'] ?? '-';

        grouped.putIfAbsent(
          subjectName,
          () => {
            'subjectId': subjectId,
            'subjectName': subjectName,
            'categories': <String, List<Map<String, dynamic>>>{},
          },
        );

        final categories = grouped[subjectName]!['categories']
            as Map<String, List<Map<String, dynamic>>>;
        categories.putIfAbsent(category, () => []);
        categories[category]!.add({
          'title': title,
          'score': score,
          'maxScore': maxScore,
          'date': date,
          'notes': notes,
        });
      }

      final Map<String, double> weightedAvg = {};
      for (final entry in grouped.entries) {
        final subjectName = entry.key;
        final subjectId = entry.value['subjectId'] as String;
        final categories = entry.value['categories']
            as Map<String, List<Map<String, dynamic>>>;

        Map<String, double>? weights;
        try {
          final docId =
              '${widget.classId}_${subjectId}_${widget.tahunAjaran.replaceAll('/', '_')}_${widget.semester}';
          final weightDoc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
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
          final double totalWeightSum = weights.values.fold(0.0, (total, w) => total + w);
          categories.forEach((cat, items) {
            final catWeight = weights![cat] ?? 0.0;
            if (catWeight > 0 && items.isNotEmpty) {
              final catAvg = items.fold(0.0, (sum, item) {
                    final s = item['score'] as double;
                    final max = item['maxScore'] as double;
                    return sum + (max > 0 ? (s / max) * 100 : 0);
                  }) /
                  items.length;
              weightedSum += catAvg * catWeight;
            }
          });
          weightedAvg[subjectName] =
              totalWeightSum > 0 ? weightedSum / totalWeightSum : 0.0;
        } else {
          double totalScore = 0;
          int count = 0;
          categories.forEach((cat, items) {
            for (final item in items) {
              final s = item['score'] as double;
              final max = item['maxScore'] as double;
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

  void _toggleExpand(String subjectName) {
    setState(() {
      if (_expandedSubjects.contains(subjectName)) {
        _expandedSubjects.remove(subjectName);
      } else {
        _expandedSubjects.add(subjectName);
      }
    });
  }

  Color _getScoreColor(double score) {
    if (_gradeTemplates != null) {
      if (score >= (_gradeTemplates!['aminus'] ?? 85)) {
        return const Color(0xFF10B981);
      }
      if (score >= (_gradeTemplates!['bminus'] ?? 70)) {
        return const Color(0xFF3B82F6);
      }
      if (score >= (_gradeTemplates!['cminus'] ?? 55)) {
        return const Color(0xFFF59E0B);
      }
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
        const months = [
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

  @override
  Widget build(BuildContext context) {
    final textColor = widget.textColor;
    final subTextColor = widget.subTextColor;
    final cardBg = widget.cardBg;
    final cardBorder = widget.cardBorder;
    final isDark = widget.isDark;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : const Color(0xFF8B5CF6),
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat nilai',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: loadGrades,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_groupedGrades.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          children: [
            Icon(
              Icons.grade_rounded,
              size: 48,
              color: subTextColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Nilai',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nilai anak akan tampil setelah guru memasukkan nilai.',
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nilai Anak',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.tahunAjaran} • ${widget.semester}',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._groupedGrades.entries.map((entry) {
          final subjectName = entry.key;
          final categories = entry.value['categories']
              as Map<String, List<Map<String, dynamic>>>;
          final avg = _subjectWeightedAvg[subjectName] ?? 0.0;
          final scoreColor = _getScoreColor(avg);
          final scoreLabel = _getScoreLabel(avg);
          final isExpanded = _expandedSubjects.contains(subjectName);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleExpand(subjectName),
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(16),
                      bottom: Radius.circular(isExpanded ? 0 : 16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.book_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subjectName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  widget.className,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: scoreColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  avg.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scoreColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    scoreLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: subTextColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: categories.entries.map((catEntry) {
                        final catName = catEntry.key;
                        final items = catEntry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                catName,
                                style: TextStyle(
                                  color: _getCategoryColor(catName),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            ...items.map((item) {
                              final s = item['score'] as double;
                              final max = item['maxScore'] as double;
                              final pct = max > 0 ? (s / max) * 100 : 0.0;
                              final itemColor = _getScoreColor(pct);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title'] as String,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            _formatDate(item['date'] as String),
                                            style: TextStyle(
                                              color: subTextColor,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${s.toStringAsFixed(s % 1 == 0 ? 0 : 1)} / ${max.toStringAsFixed(max % 1 == 0 ? 0 : 1)}',
                                      style: TextStyle(
                                        color: itemColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
