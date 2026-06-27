import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';

class TeacherSchedulePage extends StatefulWidget {
  final String teacherId;
  final bool hideBackButton;
  const TeacherSchedulePage({
    super.key,
    required this.teacherId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherSchedulePage> createState() => _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends State<TeacherSchedulePage> {
  final _scheduleService = ClassScheduleService();
  static const List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    const primaryIndigo = Color(0xFF8B5CF6);

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonBgColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);
        final backButtonIconColor = isDark
            ? Colors.white
            : const Color(0xFF1E1B4B);
        final tabLabelColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final tabUnselectedLabelColor = isDark
            ? Colors.white38
            : const Color(0xFF1E1B4B).withValues(alpha: 0.45);

        return DefaultTabController(
          length: _days.length,
          child: Scaffold(
            body: AuthBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: !widget.hideBackButton,
                  iconTheme: IconThemeData(color: backButtonIconColor),
                  leading: widget.hideBackButton
                      ? null
                      : Container(
                          margin: const EdgeInsets.only(left: 16),
                          decoration: BoxDecoration(
                            color: backButtonBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: backButtonIconColor,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                  title: Text(
                    'Jadwal Mengajar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: titleColor,
                    ),
                  ),
                  bottom: TabBar(
                    isScrollable: true,
                    indicatorColor: primaryIndigo,
                    indicatorWeight: 3,
                    labelColor: tabLabelColor,
                    unselectedLabelColor: tabUnselectedLabelColor,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    tabs: _days.map((day) => Tab(text: day)).toList(),
                  ),
                ),
                body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _scheduleService.getSchedulesByTeacher(
                    user.schoolId,
                    widget.teacherId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Terjadi kesalahan memuat jadwal',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.white : primaryIndigo,
                          ),
                        ),
                      );
                    }

                    final allSchedules =
                        snapshot.data?.docs.map((e) => e.data()).toList() ?? [];

                    return TabBarView(
                      children: _days.map((day) {
                        final daySchedules = allSchedules
                            .where((s) => s['hari'] == day)
                            .toList();

                        // Sort schedules chronologically by start time
                        daySchedules.sort((a, b) {
                          return _timeToMinutes(
                            a['jamMulai'] ?? '',
                          ).compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
                        });

                        return _buildScheduleListForDay(
                          daySchedules,
                          day,
                          isDark,
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleListForDay(
    List<Map<String, dynamic>> schedules,
    String day,
    bool isDark,
  ) {
    final emptyIconColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.2);
    final emptyTextColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final cardShadow = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.03);

    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
    final textSubtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.8);

    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 64, color: emptyIconColor),
            const SizedBox(height: 16),
            Text(
              'Tidak ada jadwal mengajar pada hari $day',
              style: TextStyle(
                fontSize: 14,
                color: emptyTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final s = schedules[index];
        final subjectName = s['subjectName'] ?? 'Pelajaran';
        final className = s['className'] ?? 'Kelas';
        final jamMulai = s['jamMulai'] ?? '00:00';
        final jamSelesai = s['jamSelesai'] ?? '00:00';
        final jenisJadwal = s['jenisJadwal'] ?? 'pelajaran';

        final isRest = jenisJadwal == 'istirahat';
        final accentColor = isRest
            ? const Color(0xFFF59E0B)
            : const Color(0xFF8B5CF6);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: cardShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Accent Side Color Bar
                  Container(width: 6, color: accentColor),
                  const SizedBox(width: 16),

                  // Time Representation
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          jamMulai,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          jamSelesai,
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    width: 1,
                    color: cardBorder,
                  ),

                  // Subject and Class Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 16,
                        bottom: 16,
                        right: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subjectName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isRest)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'Istirahat',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (!isRest)
                            Row(
                              children: [
                                Icon(
                                  Icons.class_outlined,
                                  color: subTextColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    className,
                                    style: TextStyle(
                                      color: textSubtitleColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Waktunya Istirahat & Santai',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
