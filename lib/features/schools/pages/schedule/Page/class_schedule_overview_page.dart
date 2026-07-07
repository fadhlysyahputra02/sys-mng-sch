import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../classes/data/class_service.dart';
import '../Service/class_schedule_service.dart';
import 'auto_schedule_generator_page.dart';
import 'class_schedule_page.dart';

class ClassScheduleOverviewPage extends StatelessWidget {
  final bool hideBackButton;
  ClassScheduleOverviewPage({super.key, this.hideBackButton = false});

  final ClassService _classService = ClassService();
  final ClassScheduleService _scheduleService = ClassScheduleService();

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

            return Scaffold(
              body: AuthBackground(
                child: Column(
                  children: [
                    // AppBar Area
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                        child: Row(
                          children: [
                            if (!hideBackButton)
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonColor, size: 20),
                              ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AppLocalization.isIndonesian ? 'Jadwal Kelas' : 'Class Schedules',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Body
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _classService.getClasses(schoolId),
                        builder: (context, classSnapshot) {
                          if (classSnapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    AppLocalization.isIndonesian
                                        ? 'Terjadi kesalahan memuat data kelas.'
                                        : 'An error occurred while loading class data.',
                                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (!classSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                              ),
                            );
                          }

                          final classDocs = classSnapshot.data!.docs;

                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _scheduleService.getSchedulesBySchool(schoolId),
                            builder: (context, scheduleSnapshot) {
                              if (scheduleSnapshot.hasError) {
                                return Center(
                                  child: Text(
                                    AppLocalization.isIndonesian
                                        ? 'Gagal memuat jadwal.'
                                        : 'Failed to load schedules.',
                                    style: TextStyle(color: titleColor),
                                  ),
                                );
                              }

                              if (!scheduleSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
                                  ),
                                );
                              }

                              final scheduleDocs = scheduleSnapshot.data!.docs;
                              final scheduleMap = <String, List<Map<String, dynamic>>>{};

                              for (final doc in scheduleDocs) {
                                final data = doc.data();
                                final classId = (data['classId'] ?? '').toString();
                                if (classId.isEmpty) continue;
                                scheduleMap.putIfAbsent(classId, () => []).add(data);
                              }

                              final classesWithSchedule = classDocs
                                  .where((doc) => scheduleMap.containsKey(doc.id))
                                  .toList();
                              classesWithSchedule.sort((a, b) {
                                final nameA = (a.data()['namaKelas'] ?? '').toString().toLowerCase();
                                final nameB = (b.data()['namaKelas'] ?? '').toString().toLowerCase();
                                return nameA.compareTo(nameB);
                              });

                              final classesWithoutSchedule = classDocs
                                  .where((doc) => !scheduleMap.containsKey(doc.id))
                                  .toList();
                              classesWithoutSchedule.sort((a, b) {
                                final nameA = (a.data()['namaKelas'] ?? '').toString().toLowerCase();
                                final nameB = (b.data()['namaKelas'] ?? '').toString().toLowerCase();
                                return nameA.compareTo(nameB);
                              });

                              return ListView(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                                children: [
                                  // Stat Cards Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _statCard(
                                          title: AppLocalization.isIndonesian ? 'Total Kelas' : 'Total Classes',
                                          value: '${classDocs.length}',
                                          icon: Icons.class_rounded,
                                          colors: const [Color(0xFFEC4899), Color(0xFFF472B6)],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _statCard(
                                          title: AppLocalization.isIndonesian ? 'Ada Jadwal' : 'With Schedule',
                                          value: '${classesWithSchedule.length}',
                                          icon: Icons.event_available_rounded,
                                          colors: const [Color(0xFF059669), Color(0xFF34D399)],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _statCard(
                                          title: AppLocalization.isIndonesian ? 'Belum Ada' : 'No Schedule',
                                          value: '${classesWithoutSchedule.length}',
                                          icon: Icons.event_busy_rounded,
                                          colors: const [Color(0xFFDC2626), Color(0xFFF87171)],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF8B5CF6), Color(0xFFC084FC)],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () => _handleGenerateTap(context),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      AppLocalization.isIndonesian ? 'Generate' : 'Auto Generate',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(16),
                                              onTap: () => _showFormatConfirmationDialog(context, schoolId),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 20),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      AppLocalization.isIndonesian ? 'Format' : 'Clear All',
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 28),

                                  // Section: Classes with schedule
                                  _sectionHeader(
                                    AppLocalization.isIndonesian ? 'Sudah Ada Jadwal' : 'With Schedules Set',
                                    Icons.check_circle_rounded,
                                    const Color(0xFF10B981),
                                  ),
                                  const SizedBox(height: 12),

                                  if (classesWithSchedule.isEmpty)
                                    _emptyStateCard(
                                      icon: Icons.event_note_rounded,
                                      message: AppLocalization.isIndonesian
                                          ? 'Belum ada kelas yang memiliki jadwal.'
                                          : 'No classes have schedule set yet.',
                                      isDark: isDark,
                                    )
                                  else
                                    ...classesWithSchedule.map((doc) {
                                      final data = doc.data();
                                      final schedules = scheduleMap[doc.id] ?? [];
                                      final firstSchedule = schedules.first;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _classCard(
                                          classname: data['namaKelas'] ?? '-',
                                          subtitle: AppLocalization.isIndonesian
                                              ? '${schedules.length} jadwal  •  ${firstSchedule['hari'] ?? ''}, ${firstSchedule['jamMulai'] ?? ''} – ${firstSchedule['jamSelesai'] ?? ''}'
                                              : '${schedules.length} periods  •  ${firstSchedule['hari'] ?? ''}, ${firstSchedule['jamMulai'] ?? ''} – ${firstSchedule['jamSelesai'] ?? ''}',
                                          hasSchedule: true,
                                          isDark: isDark,
                                          onTap: () {
                                            Get.to(() => ClassSchedulePage(
                                              classId: doc.id,
                                              className: data['namaKelas'] ?? '',
                                            ));
                                          },
                                        ),
                                      );
                                    }),

                                  const SizedBox(height: 24),

                                  // Section: Classes without schedule
                                  _sectionHeader(
                                    AppLocalization.isIndonesian ? 'Belum Ada Jadwal' : 'Pending Schedules',
                                    Icons.pending_actions_rounded,
                                    const Color(0xFFEF4444),
                                  ),
                                  const SizedBox(height: 12),

                                  if (classesWithoutSchedule.isEmpty)
                                    _emptyStateCard(
                                      icon: Icons.celebration_rounded,
                                      message: AppLocalization.isIndonesian
                                          ? 'Semua kelas sudah memiliki jadwal. 🎉'
                                          : 'All classes have schedule set. 🎉',
                                      isDark: isDark,
                                    )
                                  else
                                    ...classesWithoutSchedule.map((doc) {
                                      final data = doc.data();

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _classCard(
                                          classname: data['namaKelas'] ?? '-',
                                          subtitle: AppLocalization.isIndonesian
                                              ? 'Tap untuk mulai isi jadwal kelas ini'
                                              : 'Tap to start setting schedule for this class',
                                          hasSchedule: false,
                                          isDark: isDark,
                                          onTap: () {
                                            Get.to(() => ClassSchedulePage(
                                              classId: doc.id,
                                              className: data['namaKelas'] ?? '',
                                            ));
                                          },
                                        ),
                                      );
                                    }),
                                ],
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
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _emptyStateCard({required IconData icon, required String message, required bool isDark}) {
    final emptyBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final emptyBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final emptyIconColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: emptyBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: emptyBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: emptyIconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: emptyTextColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classCard({
    required String classname,
    required String subtitle,
    required bool hasSchedule,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final badgeColor = hasSchedule ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final badgeText = hasSchedule ? 'Ada Jadwal' : 'Belum Ada';
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);
    final textNameColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSubColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6B7280);
    final chevronColor = isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF9CA3AF);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.class_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classname,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textNameColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: textSubColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: chevronColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGenerateTap(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
      ),
    );

    try {
      final user = SessionService.currentUser;
      final schoolId = user?.schoolId ?? '';
      
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();
          
      final schoolData = schoolDoc.data();
      final bool enableScheduleFeatures = schoolData?['enableScheduleFeatures'] ?? false;
      
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      if ((user?.role == 'school_admin' || user?.role == 'tu') && !enableScheduleFeatures) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF151026),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalization.isIndonesian ? 'Fitur Terkunci' : 'Feature Locked',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
              content: Text(
                AppLocalization.isIndonesian
                    ? 'Fitur Generate Jadwal Otomatis dinonaktifkan oleh Super Admin. Silakan hubungi Super Admin untuk mengaktifkan akses.'
                    : 'The Automatic Schedule Generation feature is disabled by the Super Admin. Please contact Super Admin to enable access.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
          );
        }
        return;
      }

      Get.to(() => const AutoScheduleGeneratorPage());
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalization.isIndonesian ? 'Gagal: $e' : 'Failed: $e',
            ),
          ),
        );
      }
    }
  }

  void _showPremiumDialog(BuildContext context, String message) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final mutedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorder, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Fitur Premium 🌟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Silakan hubungi administrator/sales untuk melakukan upgrade paket sekolah Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showFormatConfirmationDialog(BuildContext context, String schoolId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalization.isIndonesian ? 'Format Jadwal?' : 'Format Schedules?',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalization.isIndonesian
                    ? 'Apakah Anda yakin ingin menghapus SELURUH jadwal kelas di sekolah ini? Aksi ini tidak dapat dibatalkan.'
                    : 'Are you sure you want to delete ALL class schedules in this school? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                      );

                      try {
                        await _scheduleService.deleteAllSchedules(schoolId);
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalization.isIndonesian
                                    ? 'Seluruh jadwal berhasil diformat (dihapus).'
                                    : 'All schedules successfully cleared.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalization.isIndonesian
                                    ? 'Gagal format jadwal: $e'
                                    : 'Failed to clear schedules: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      AppLocalization.isIndonesian ? 'Format' : 'Format',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
