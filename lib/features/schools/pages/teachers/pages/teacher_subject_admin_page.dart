import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/teacher_subject_service.dart';

class TeacherSubjectPage extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherSubjectPage({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherSubjectPage> createState() => _TeacherSubjectPageState();
}

class _TeacherSubjectPageState extends State<TeacherSubjectPage> {
  final service = TeacherSubjectService();
  List<String> assigned = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadAssigned();
  }

  Future<void> loadAssigned() async {
    assigned = await service.getAssignedSubjects(widget.teacherId);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final hintBgColor = isDark ? const Color(0xFF6366F1).withValues(alpha: 0.08) : const Color(0xFF6366F1).withValues(alpha: 0.06);
        final hintBorderColor = isDark ? const Color(0xFF6366F1).withValues(alpha: 0.25) : const Color(0xFF6366F1).withValues(alpha: 0.2);
        final hintTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.75);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // ── AppBar ────────────────────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonColor, size: 20),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mata Pelajaran',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                          ),
                          Text(
                            widget.teacherName,
                            style: TextStyle(fontSize: 12, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Hint ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: hintBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: hintBorderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Centang mata pelajaran yang diampu oleh ${widget.teacherName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: hintTextColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(schoolId)
                          .collection('subjects')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                            ),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        if (docs.isEmpty) {
                          final emptyStateBgColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03);
                          final emptyStateBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
                          final emptyStateIconColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
                          final emptyStateTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);

                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: emptyStateBgColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: emptyStateBorderColor),
                                  ),
                                  child: Icon(Icons.menu_book_outlined, size: 48, color: emptyStateIconColor),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada mata pelajaran',
                                  style: TextStyle(
                                    color: emptyStateTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final subject = docs[index].data() as Map<String, dynamic>;
                            final subjectId = subject['subjectId'];
                            final isChecked = assigned.contains(subjectId);

                            final cardBgColor = isChecked
                                ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.08) : const Color(0xFF10B981).withValues(alpha: 0.06))
                                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white);
                            final cardBorderColor = isChecked
                                ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFF10B981).withValues(alpha: 0.3))
                                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08));
                            final cardShadow = isDark
                                ? const <BoxShadow>[]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ];
                            final subjectNameColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
                            final subjectCodeColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF1E1B4B).withValues(alpha: 0.55);
                            final checkboxBorderColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.3);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorderColor),
                                boxShadow: cardShadow,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Icon mapel
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isChecked
                                              ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                              : [const Color(0xFF6366F1).withValues(alpha: 0.5), const Color(0xFF8B5CF6).withValues(alpha: 0.5)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.book_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    // Subject info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            subject['namaMapel'] ?? '-',
                                            style: TextStyle(
                                              color: subjectNameColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subject['kodeMapel'] ?? '-',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: subjectCodeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Custom checkbox
                                    GestureDetector(
                                      onTap: () async {
                                        if (!isChecked) {
                                          await service.assignSubject(
                                            schoolId: schoolId,
                                            teacherId: widget.teacherId,
                                            teacherName: widget.teacherName,
                                            subjectId: subjectId,
                                            subjectName: subject['namaMapel'],
                                          );
                                          assigned.add(subjectId);
                                        } else {
                                          await service.removeSubject(
                                            teacherId: widget.teacherId,
                                            subjectId: subjectId,
                                          );
                                          assigned.remove(subjectId);
                                        }
                                        setState(() {});
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: isChecked
                                              ? const Color(0xFF10B981)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isChecked
                                                ? const Color(0xFF10B981)
                                                : checkboxBorderColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: isChecked
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
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
    );
      },
    );
  }
}
