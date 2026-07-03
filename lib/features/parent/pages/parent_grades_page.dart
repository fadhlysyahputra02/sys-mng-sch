import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../authentication/widgets/auth_background.dart';
import '../widgets/parent_student_grades_section.dart';

class ParentGradesPage extends StatefulWidget {
  const ParentGradesPage({super.key});

  @override
  State<ParentGradesPage> createState() => _ParentGradesPageState();
}

class _ParentGradesPageState extends State<ParentGradesPage> {
  final _gradesSectionKey = GlobalKey<ParentStudentGradesSectionState>();

  @override
  Widget build(BuildContext context) {
    final schoolId = Get.arguments?['schoolId'] as String? ?? '';
    final studentId = Get.arguments?['studentId'] as String? ?? '';
    final classId = Get.arguments?['classId'] as String?;
    final className = Get.arguments?['className'] as String? ?? '-';
    final tahunAjaran = Get.arguments?['tahunAjaran'] as String?;
    final semester = Get.arguments?['semester'] as String?;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg =
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return AuthBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              title: Text(
                'Laporan Nilai Anak',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SafeArea(
              bottom: true,
              top: false,
              child: RefreshIndicator(
                color: const Color(0xFF8B5CF6),
                onRefresh: () async {
                  if (_gradesSectionKey.currentState != null) {
                    await _gradesSectionKey.currentState!.loadGrades();
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: classId != null &&
                          classId.isNotEmpty &&
                          tahunAjaran != null &&
                          semester != null
                      ? ParentStudentGradesSection(
                          key: _gradesSectionKey,
                          schoolId: schoolId,
                          studentId: studentId,
                          classId: classId,
                          className: className,
                          tahunAjaran: tahunAjaran,
                          semester: semester,
                          isDark: isDark,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: subTextColor, size: 32),
                              const SizedBox(height: 12),
                              Text(
                                'Data kelas anak belum lengkap.\nLaporan nilai belum tersedia.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 13,
                                  height: 1.5,
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
}
