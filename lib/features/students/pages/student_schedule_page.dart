import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';

class StudentSchedulePage extends StatefulWidget {
  final String className;
  const StudentSchedulePage({super.key, required this.className});

  @override
  State<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends State<StudentSchedulePage> {
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

  String _getLocalDayName(String day) {
    final isIndo = AppLocalization.isIndonesian;
    switch (day) {
      case 'Senin': return isIndo ? 'Senin' : 'Monday';
      case 'Selasa': return isIndo ? 'Selasa' : 'Tuesday';
      case 'Rabu': return isIndo ? 'Rabu' : 'Wednesday';
      case 'Kamis': return isIndo ? 'Kamis' : 'Thursday';
      case 'Jumat': return isIndo ? 'Jumat' : 'Friday';
      case 'Sabtu': return isIndo ? 'Sabtu' : 'Saturday';
      case 'Minggu': return isIndo ? 'Minggu' : 'Sunday';
      default: return day;
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    const primaryIndigo = Color(0xFF8B5CF6);

    return DefaultTabController(
      length: _days.length,
      child: ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final btnBg = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
          final tabUnselectedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.38);

          return Scaffold(
            body: AuthBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: IconThemeData(color: iconColor),
                  leading: Container(
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: btnBg,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: Text(
                    AppLocalization.isIndonesian
                        ? 'Jadwal Kelas ${widget.className}'
                        : '${widget.className} Class Schedule',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                  ),
                  bottom: TabBar(
                    isScrollable: true,
                    indicatorColor: primaryIndigo,
                    indicatorWeight: 3,
                    labelColor: textColor,
                    unselectedLabelColor: tabUnselectedColor,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                    tabs: _days.map((day) => Tab(text: _getLocalDayName(day))).toList(),
                  ),
                ),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _scheduleService.getSchedulesByClassName(user.schoolId, widget.className),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalization.isIndonesian
                              ? 'Terjadi kesalahan memuat jadwal'
                              : 'Error loading schedule',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  );
                }

                final allSchedules = snapshot.data?.docs.map((e) => e.data()).toList() ?? [];

                return TabBarView(
                  children: _days.map((day) {
                    final daySchedules = allSchedules.where((s) => s['hari'] == day).toList();
                    
                    // Sort schedules chronologically by start time
                    daySchedules.sort((a, b) {
                      return _timeToMinutes(a['jamMulai'] ?? '').compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
                    });

                    return _buildScheduleListForDay(daySchedules, day, isDark);
                  }).toList(),
                );
              },
            ),
          ),
        ),
      );
      },
      ),
    );
  }

  Widget _buildScheduleListForDay(List<Map<String, dynamic>> schedules, String day, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF9FAFB);
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);
    if (schedules.isEmpty) {
      final emptyIconColor = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF1E1B4B).withValues(alpha: 0.15);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: emptyIconColor,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalization.isIndonesian
                  ? 'Tidak ada jadwal pelajaran pada hari $day'
                  : 'No subjects scheduled for ${_getLocalDayName(day)}',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
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
        final teacherName = s['teacherName'] ?? '-';
        final jamMulai = s['jamMulai'] ?? '00:00';
        final jamSelesai = s['jamSelesai'] ?? '00:00';
        final jenisJadwal = s['jenisJadwal'] ?? 'pelajaran';
        
        final isRest = jenisJadwal == 'istirahat';
        final accentColor = isRest ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                  Container(
                    width: 6,
                    color: accentColor,
                  ),
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
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    width: 1,
                    color: cardBorderColor,
                  ),
                  
                  // Subject and Teacher Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    AppLocalization.isIndonesian ? 'Istirahat' : 'Rest Break',
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
                                  Icons.person_outline_rounded,
                                  color: subTextColor,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppLocalization.isIndonesian ? 'Guru: $teacherName' : 'Teacher: $teacherName',
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
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
                              AppLocalization.isIndonesian ? 'Waktunya Istirahat & Santai' : 'Time to Rest & Relax',
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
