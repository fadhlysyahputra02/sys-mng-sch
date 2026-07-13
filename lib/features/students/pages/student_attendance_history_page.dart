import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../widgets/monthly_attendance_table_section.dart';
import '../../../core/localization/app_localization.dart';

class StudentAttendanceHistoryPage extends StatelessWidget {
  final String studentDocId;
  final String className;
  final String studentName;

  const StudentAttendanceHistoryPage({
    super.key,
    required this.studentDocId,
    required this.className,
    this.studentName = 'Murid',
  });

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);
        final iconBg = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  iconTheme: IconThemeData(color: textColor),
                  leading: Container(
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textColor,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: Text(
                    AppLocalization.isIndonesian ? 'Riwayat Absensi' : 'Attendance History',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  sliver: SliverToBoxAdapter(
                    child: MonthlyAttendanceTableSection(
                      schoolId: user.schoolId,
                      studentId: studentDocId,
                      className: className,
                      studentName: studentName,
                      isDark: isDark,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      cardBg: cardBg,
                      cardBorder: cardBorder,
                      showTitle: false,
                    ),
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
