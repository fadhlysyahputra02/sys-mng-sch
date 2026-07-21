import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/widgets/monthly_attendance_table_section.dart';
import '../../../core/localization/app_localization.dart';

class ParentAttendancePage extends StatelessWidget {
  const ParentAttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = Get.arguments?['schoolId'] as String? ?? '';
    final studentId = Get.arguments?['studentId'] as String? ?? '';
    final className = Get.arguments?['className'] as String? ?? '-';
    final studentName = Get.arguments?['studentName'] as String? ?? 'Anak';

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
                AppLocalization.isIndonesian ? 'Daftar Hadir Anak' : "Child's Attendance",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: SafeArea(
              bottom: true,
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: MonthlyAttendanceTableSection(
                  schoolId: schoolId,
                  studentId: studentId,
                  className: className,
                  studentName: studentName,
                  isDark: isDark,
                  textColor: textColor,
                  subTextColor: subTextColor,
                  cardBg: cardBg,
                  cardBorder: cardBorder,
                  showTitle: false,
                  embedded: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
