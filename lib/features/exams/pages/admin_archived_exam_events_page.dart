import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
import 'admin_exam_schedule_view_page.dart';

class AdminArchivedExamEventsPage extends StatelessWidget {
  const AdminArchivedExamEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;
    final service = ExamSessionService();

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subtitleColor = isDark
                ? Colors.white.withValues(alpha: 0.55)
                : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
            final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
            final cardBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

            return Scaffold(
              body: AuthBackground(
                child: Column(
                  children: [
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                              onPressed: () => Get.back(),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AppLocalization.isIndonesian ? 'Arsip Event' : 'Archived Events',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<ExamEvent>>(
                        stream: service.getArchivedExamEvents(schoolId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                              ),
                            );
                          }

                          final events = snapshot.data ?? [];

                          if (events.isEmpty) {
                            return _buildEmptyState(isDark, titleColor, subtitleColor);
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                            itemCount: events.length,
                            itemBuilder: (_, i) => _buildEventCard(
                              context,
                              events[i],
                              isDark,
                              cardColor,
                              cardBorder,
                              titleColor,
                              subtitleColor,
                              service,
                              schoolId,
                            ),
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
      },
    );
  }

  Widget _buildEmptyState(bool isDark, Color titleColor, Color subtitleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.archive_outlined,
                size: 36,
                color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalization.isIndonesian ? 'Belum Ada Arsip' : 'No Archived Events',
              style: TextStyle(color: titleColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    ExamEvent event,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
    ExamSessionService service,
    String schoolId,
  ) {
    final localeStr = AppLocalization.isIndonesian ? 'id' : 'en';
    final dateStr = '${DateFormat('dd MMM', localeStr).format(event.startDate)} – ${DateFormat('dd MMM yyyy', localeStr).format(event.endDate)}';
    final userRole = SessionService.currentUser?.role ?? '';
    final isAdmin = userRole == 'school_admin' || userRole == 'super_admin';

    return GestureDetector(
      onTap: () => Get.to(() => AdminExamScheduleViewPage(eventId: event.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.orangeAccent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppLocalization.isIndonesian ? 'DIARSIPKAN' : 'ARCHIVED',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        onSelected: (val) async {
                          if (val == 'restore') {
                            await service.updateExamEventStatus(schoolId, event.id, 'Finished');
                            Get.snackbar(
                                AppLocalization.isIndonesian ? 'Dipulihkan' : 'Restored',
                                AppLocalization.isIndonesian ? 'Event berhasil dipulihkan.' : 'Event successfully restored.',
                                backgroundColor: const Color(0xFF10B981), colorText: Colors.white);
                          } else if (val == 'delete' && isAdmin) {
                             // Delete logic can be added here if needed, but for simplicity let's skip
                          }
                        },
                        icon: Icon(Icons.more_vert_rounded, color: subtitleColor, size: 20),
                        color: isDark ? const Color(0xFF1A1730) : Colors.white,
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'restore',
                            child: Text(AppLocalization.isIndonesian ? 'Pulihkan Event' : 'Restore Event', style: TextStyle(color: titleColor)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.title,
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: subtitleColor),
                      const SizedBox(width: 6),
                      Text(dateStr, style: TextStyle(color: subtitleColor, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
