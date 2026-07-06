import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/services/app_auth_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../../services/school_service.dart';
import '../classes/pages/class_list_page.dart';
import '../grades/school_admin_grades_page.dart';
import '../settings/school_settings_page.dart';
import '../teachers/pages/teacher_list_admin_page.dart';
import '../students/pages/student_admin_list_page.dart';
import '../students/data/student_admin_service.dart';
import '../subjects/pages/subject_list_page.dart';
import '../schedule/Page/class_schedule_overview_page.dart';
import '../notifications/notifications_page.dart';
import '../staff/staff_management_tabbed_page.dart';

import '../../../officer/pages/daily_recap_page.dart';
import '../teaching_reports/admin_teaching_reports_page.dart';
import '../teachers/pages/admin_teacher_attendance_page.dart';

import '../rapor/school_admin_rapor_page.dart';
import '../violations/admin_violations_history_page.dart';
import '../../../../core/widgets/motif_card.dart';
import '../approvals/approval_dashboard_page.dart';
import '../../../../core/localization/app_localization.dart';


class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  String get schoolId => SessionService.currentUser?.schoolId ?? '';
  String get nama => SessionService.currentUser?.nama ?? '';
  String get email => SessionService.currentUser?.email ?? '';

  String? _schoolName;
  String _plan = 'FREE';
  String? _schoolLogoBase64;
  bool _isLoadingSchool = true;
  int _selectedMenuIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSchoolData();
  }

  Future<void> _loadSchoolData() async {
    try {
      final schoolData = await SchoolService().getSchoolByDomain(schoolId);
      if (schoolData != null && mounted) {
        setState(() {
          _schoolName = schoolData['namaSekolah'];
          _plan = (schoolData['plan'] ?? 'FREE').toString().toUpperCase();
          _schoolLogoBase64 = schoolData['logoBase64'];
          _isLoadingSchool = false;
        });
        // Backfill data histori kelas secara asinkronus agar data nilai sebelumnya termigrasi ke class_enrollments
        StudentService().backfillClassEnrollments(schoolId);
      } else {
        if (mounted) {
          setState(() {
            _isLoadingSchool = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSchool = false;
        });
      }
    }
  }

  final List<_MenuData> _menus = const [
    _MenuData('Manajemen Guru', Icons.school_rounded, Color(0xFFF59E0B)),
    _MenuData('Manajemen Siswa', Icons.people_rounded, Color(0xFF3B82F6)),
    _MenuData('Mata Pelajaran', Icons.menu_book_rounded, Color(0xFF10B981)),
    _MenuData('Kelas', Icons.class_rounded, Color(0xFFF59E0B)),
    _MenuData('Jadwal', Icons.calendar_today_rounded, Color(0xFFEC4899)),
    _MenuData('Rekap Absensi', Icons.calendar_month_rounded, Color(0xFF8B5CF6)),
    _MenuData('Rekap Nilai', Icons.grade_rounded, Color(0xFFEF4444)),
    _MenuData('Laporan Mengajar', Icons.edit_document, Color(0xFFF59E0B)),
    _MenuData('Notifikasi', Icons.notifications_rounded, Color(0xFFEF4444)),
    _MenuData('Pengaturan', Icons.settings_rounded, Color(0xFF64748B)),
    _MenuData('Petugas', Icons.security_rounded, Color(0xFF8B5CF6)),
    _MenuData('E-Rapor', Icons.description_rounded, Color(0xFF8B5CF6)),
    _MenuData('Pelanggaran Murid', Icons.report_problem_rounded, Color(0xFFEF4444)),
    _MenuData('Persetujuan', Icons.edit_note_rounded, Color(0xFF10B981)),
  ];

  String _getMenuTranslation(String originalTitle) {
    switch (originalTitle) {
      case 'Dashboard':
        return AppLocalization.isIndonesian ? 'Dashboard' : 'Dashboard';
      case 'Manajemen Guru':
        return AppLocalization.isIndonesian ? 'Manajemen Guru' : 'Teacher Management';
      case 'Manajemen Siswa':
        return AppLocalization.isIndonesian ? 'Manajemen Siswa' : 'Student Management';
      case 'Mata Pelajaran':
        return AppLocalization.isIndonesian ? 'Mata Pelajaran' : 'Subjects';
      case 'Kelas':
        return AppLocalization.isIndonesian ? 'Kelas' : 'Classes';
      case 'Jadwal':
        return AppLocalization.isIndonesian ? 'Jadwal' : 'Schedule';
      case 'Rekap Absensi':
        return AppLocalization.isIndonesian ? 'Rekap Absensi' : 'Attendance Recap';
      case 'Notifikasi':
        return AppLocalization.isIndonesian ? 'Notifikasi' : 'Notifications';
      case 'Petugas':
        return AppLocalization.isIndonesian ? 'Petugas' : 'Staff/Officers';
      case 'Rekap Nilai':
        return AppLocalization.isIndonesian ? 'Rekap Nilai' : 'Grades Recap';
      case 'E-Rapor':
        return AppLocalization.isIndonesian ? 'E-Rapor' : 'E-Report Card';
      case 'Pelanggaran Murid':
        return AppLocalization.isIndonesian ? 'Pelanggaran Murid' : 'Student Infractions';
      case 'Persetujuan':
        return AppLocalization.isIndonesian ? 'Persetujuan' : 'Approvals';


      case 'Laporan Mengajar':
        return AppLocalization.isIndonesian ? 'Laporan Mengajar' : 'Teaching Reports';
      case 'Pengaturan':
        return AppLocalization.isIndonesian ? 'Pengaturan' : 'Settings';
      default:
        return originalTitle;
    }
  }

  void _onMenuTap(String title) async {
    switch (title) {
      case 'E-Rapor':
        Get.to(() => const SchoolAdminRaporPage());
        break;
      case 'Pelanggaran Murid':
        Get.to(() => const AdminViolationsHistoryPage());
        break;
      case 'Manajemen Guru':
        Get.toNamed(AppRoutes.teacherlist);
        break;
      case 'Manajemen Siswa':
        Get.toNamed(AppRoutes.studentList);
        break;
      case 'Mata Pelajaran':
        Get.toNamed(AppRoutes.subjectList);
        break;
      case 'Kelas':
        Get.to(() => ClassListPage());
        break;
      case 'Jadwal':
        Get.toNamed(AppRoutes.schedule);
        break;
      case 'Notifikasi':
        Get.toNamed(AppRoutes.notifications);
        break;
      case 'Rekap Nilai':
        Get.to(() => const SchoolAdminGradesPage());
        break;
      case 'Pengaturan':
        final updated = await Get.to(() => SchoolSettingsPage(schoolId: schoolId));
        if (updated == true) {
          _loadSchoolData();
        }
        break;
      case 'Petugas':
        Get.to(() => const StaffManagementTabbedPage());
        break;
      case 'Rekap Absensi':
        _showAbsensiSelectionDialog();
        break;
      case 'Laporan Mengajar':
        Get.to(() => const AdminTeachingReportsPage());
        break;
      case 'Persetujuan':
        Get.to(() => const ApprovalDashboardPage());
        break;

    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 10) return AppLocalization.isIndonesian ? 'Selamat Pagi' : 'Good Morning';
    if (hour <= 14) return AppLocalization.isIndonesian ? 'Selamat Siang' : 'Good Afternoon';
    if (hour <= 18) return AppLocalization.isIndonesian ? 'Selamat Sore' : 'Good Evening';
    return AppLocalization.isIndonesian ? 'Selamat Malam' : 'Good Night';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = AppLocalization.isIndonesian
        ? ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']
        : ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = AppLocalization.isIndonesian
        ? [
            'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
            'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
          ]
        : [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
          ];
    final dayName = days[now.weekday % 7];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (SessionService.currentUser == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.splash));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 850) {
                  return _buildMobileLayout(isDark);
                } else {
                  return _buildDesktopLayout(isDark);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Scaffold(
      body: AuthBackground(
        child: RefreshIndicator(
          onRefresh: _loadSchoolData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // SliverAppBar
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              toolbarHeight: 56,
              title: Text(
                _getGreeting(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                Container(
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.settings_rounded, color: iconColor, size: 20),
                    tooltip: AppLocalization.isIndonesian ? 'Pengaturan' : 'Settings',
                    onPressed: () async {
                      final updated = await Get.to(() => SchoolSettingsPage(schoolId: schoolId));
                      if (updated == true) {
                        _loadSchoolData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.logout_rounded, color: iconColor, size: 20),
                    tooltip: AppLocalization.isIndonesian ? 'Keluar' : 'Logout',
                    onPressed: _logout,
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Merged Header Card (Profile & School Info)
                    _buildMergedHeaderCard(nama, email, isDark),

                    const SizedBox(height: 28),

                    // MENU UTAMA
                    _buildSectionTitle('Menu Utama', Icons.dashboard_rounded, isDark),
                    const SizedBox(height: 16),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: _menus.length,
                      itemBuilder: (_, i) => _buildMenuCard(_menus[i], isDark),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMergedHeaderCard(String adminNama, String adminEmail, bool isDark) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final dateColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return MotifCard(
      isDark: isDark,
      cardColor: cardColor,
      cardBorderColor: cardBorder,
      cardShadowColor: cardShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // School Logo / Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: _schoolLogoBase64 != null
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _schoolLogoBase64 != null
                      ? Image.memory(
                          base64Decode(_schoolLogoBase64!),
                          fit: BoxFit.cover,
                          width: 70,
                          height: 70,
                        )
                      : const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // School and Admin Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isLoadingSchool
                        ? SizedBox(
                            height: 18,
                            width: 140,
                            child: LinearProgressIndicator(
                              backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                            ),
                          )
                        : Text(
                            _schoolName ?? 'Sekolah Baru',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    const SizedBox(height: 4),
                    Text(
                      'School ID: $schoolId',
                      style: TextStyle(
                        fontSize: 13, 
                        color: subtitleColor, 
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row for Badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Admin Sekolah',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                ),
              ), // Removed plan badge display
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 16),
          // Footer: Date and System Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: dateColor),
                  const SizedBox(width: 6),
                  Text(
                    _getFormattedDate(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: dateColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Sistem Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(_MenuData menu, bool isDark) {
    final bool isActive = [
      'Manajemen Guru', 'Manajemen Siswa', 'Mata Pelajaran', 'Kelas', 'Jadwal', 'Notifikasi',
      'Pengaturan', 'Petugas', 'Rekap Absensi', 'Rekap Nilai', 'Laporan Mengajar',
      'E-Rapor', 'Pelanggaran Murid', 'Persetujuan',
    ].contains(menu.title);

    final cardBg = isActive
        ? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white)
        : (isDark ? Colors.white.withValues(alpha: 0.015) : Colors.black.withValues(alpha: 0.015));

    final cardBorder = isActive
        ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06))
        : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03));

    final titleColor = isActive
        ? (isDark ? Colors.white : const Color(0xFF1E1B4B))
        : (isDark ? Colors.white30 : Colors.black26);

    final upcomingBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
    final upcomingText = isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? () => _onMenuTap(menu.title) : null,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isActive
                            ? menu.color.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        menu.icon,
                        color: isActive
                            ? menu.color
                            : (isDark ? Colors.white24 : Colors.black26),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getMenuTranslation(menu.title),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isActive) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: upcomingBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppLocalization.isIndonesian ? 'Segera Hadir' : 'Coming Soon',
                          style: TextStyle(
                            color: upcomingText,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Badge paket (BASIC / PRO) di pojok kanan atas
              if (menu.badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildPackageBadge(menu.badge!),
                ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildPackageBadge(String badge) {
    final isBasic = badge == 'BASIC';
    final gradient = isBasic
        ? const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (isBasic ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B))
                .withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        badge,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 8,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    final panelBg = isDark ? const Color(0xFF0B081B) : const Color(0xFFF8FAFC);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _buildSidebar(isDark),
          // Main Panel Content
          Expanded(
            child: Container(
              color: panelBg,
              child: _buildDesktopContent(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDark) {
    final sidebarBg = isDark ? const Color(0xFF110E24) : Colors.white;
    final borderRightColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final miniLogoBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
    final schoolNameColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(
            color: borderRightColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                // Mini Logo
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: _schoolLogoBase64 != null
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: miniLogoBorder,
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _schoolLogoBase64 != null
                        ? Image.memory(
                            base64Decode(_schoolLogoBase64!),
                            fit: BoxFit.cover,
                          )
                        : const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _isLoadingSchool
                          ? SizedBox(
                              height: 12,
                              width: 80,
                              child: LinearProgressIndicator(
                                backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                              ),
                            )
                          : Text(
                              _schoolName ?? 'Sekolah Baru',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: schoolNameColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ), // Removed plan badge display
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: dividerColor,
            height: 1,
          ),
          // Sidebar Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildSidebarItem('Dashboard', Icons.dashboard_rounded, 0, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Manajemen Guru', Icons.school_rounded, 1, const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Manajemen Siswa', Icons.people_rounded, 2, const Color(0xFF3B82F6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Mata Pelajaran', Icons.menu_book_rounded, 3, const Color(0xFF10B981), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Kelas', Icons.class_rounded, 4, const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Jadwal', Icons.calendar_today_rounded, 5, const Color(0xFFEC4899), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Rekap Absensi', Icons.calendar_month_rounded, 6, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                 _buildSidebarItem('Notifikasi', Icons.notifications_rounded, 7, const Color(0xFFEF4444), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Petugas', Icons.security_rounded, 9, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Rekap Nilai', Icons.grade_rounded, 10, const Color(0xFFEF4444), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('E-Rapor', Icons.description_rounded, 11, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Pelanggaran Murid', Icons.report_problem_rounded, 12, const Color(0xFFEF4444), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Persetujuan', Icons.edit_note_rounded, 13, const Color(0xFF10B981), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Laporan Mengajar', Icons.edit_document, 14, const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 4),
                const SizedBox(height: 4),
                _buildSidebarItem('Pengaturan', Icons.settings_rounded, 8, const Color(0xFF64748B), isDark),
              ],
            ),
          ),
          Divider(
            color: dividerColor,
            height: 1,
          ),
          // Logout Item at the bottom
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildSidebarLogoutItem(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String title, IconData icon, int index, Color color, bool isDark) {
    final bool isSelected = _selectedMenuIndex == index;
    final itemBg = isSelected ? color.withValues(alpha: isDark ? 0.15 : 0.08) : Colors.transparent;
    final itemBorder = isSelected ? color.withValues(alpha: isDark ? 0.3 : 0.2) : Colors.transparent;
    final iconColor = isSelected ? color : (isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5));
    final textColor = isSelected ? (isDark ? Colors.white : const Color(0xFF1E1B4B)) : (isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.7));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMenuIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: itemBorder,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                _getMenuTranslation(title),
                style: TextStyle(
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildSidebarLogoutItem(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.red.shade400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalization.isIndonesian ? 'Keluar' : 'Logout',
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(bool isDark) {
    switch (_selectedMenuIndex) {
      case 0:
        return _buildDesktopDashboardHome(isDark);
      case 1:
        return TeacherListPage(schoolId: schoolId, hideBackButton: true);
      case 2:
        return StudentListPage(schoolId: schoolId, hideBackButton: true);
      case 3:
        return SubjectListPage(hideBackButton: true);
      case 4:
        return ClassListPage(hideBackButton: true);
      case 5:
        return ClassScheduleOverviewPage(hideBackButton: true);
      case 6:
        return _buildDesktopAbsensiOverview(isDark);
      case 7:
        return NotificationsPage(hideBackButton: true);
      case 8:
        return SchoolSettingsPage(schoolId: schoolId, hideBackButton: true);
      case 9:
        return const StaffManagementTabbedPage();
      case 10:
        return const SchoolAdminGradesPage();
      case 11:
        return const SchoolAdminRaporPage(hideBackButton: true);
      case 12:
        return const AdminViolationsHistoryPage(hideBackButton: true);
      case 13:
        return const ApprovalDashboardPage(hideBackButton: true);
      case 14:
        return const AdminTeachingReportsPage();

      default:
        return _buildDesktopDashboardHome(isDark);
    }
  }

  void _showAbsensiSelectionDialog() {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0C20) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          border: Border(
            top: BorderSide(color: cardBorder),
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rekap Absensi',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih skala rekapan absensi yang ingin Anda lihat:',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSelectionCard(
                    title: 'Rekap Absensi Siswa',
                    description: 'Laporan & statistik kehadiran harian dan bulanan siswa',
                    icon: Icons.calendar_month_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Get.back();
                      Get.to(() => const DailyRecapPage());
                    },
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                  ),
                  const SizedBox(height: 12),
                  _buildSelectionCard(
                    title: 'Rekap Absensi Guru',
                    description: 'Laporan & statistik kehadiran harian dan bulanan guru',
                    icon: Icons.co_present_rounded,
                    color: const Color(0xFF6366F1),
                    onTap: () {
                      Get.back();
                      Get.to(() => const AdminTeacherAttendancePage(isMonthly: false));
                    },
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopAbsensiOverview(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return AuthBackground(
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Rekap Absensi School',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih jenis rekap absensi yang ingin Anda tinjau atau cetak laporan.',
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                      width: 280,
                      child: _buildSelectionCard(
                        title: 'Rekap Absensi Siswa',
                        description: 'Laporan & statistik kehadiran harian dan bulanan siswa',
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF8B5CF6),
                        onTap: () => Get.to(() => const DailyRecapPage()),
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: _buildSelectionCard(
                        title: 'Rekap Absensi Guru',
                        description: 'Laporan & statistik kehadiran harian dan bulanan guru',
                        icon: Icons.co_present_rounded,
                        color: const Color(0xFF6366F1),
                        onTap: () => Get.to(() => const AdminTeacherAttendancePage(isMonthly: false)),
                        isDark: isDark,
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDashboardHome(bool isDark) {
    final greetingColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final dateBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final dateBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final dateIconColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final dateTextColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B);
    final dateShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

    return AuthBackground(
      child: RefreshIndicator(
        onRefresh: _loadSchoolData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: greetingColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selamat datang kembali di panel administrasi ${_schoolName ?? "sekolah"}.',
                      style: TextStyle(
                        fontSize: 14,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
                // Date Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: dateBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dateBorderColor),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: dateShadow,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: dateIconColor),
                      const SizedBox(width: 8),
                      Text(
                        _getFormattedDate(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: dateTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Merged Header Card (Horizontal layout on desktop!)
            _buildMergedHeaderCardDesktop(isDark),

            const SizedBox(height: 36),

            // Live counters statistics
            _buildSectionTitle('Statistik Sekolah', Icons.analytics_rounded, isDark),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('teachers').snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildStatCardDesktop('Total Guru', '$count', Icons.person_rounded, const Color(0xFF6366F1), isDark);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('students').snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildStatCardDesktop('Total Murid', '$count', Icons.groups_rounded, const Color(0xFF0EA5E9), isDark);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('classes').snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildStatCardDesktop('Total Kelas', '$count', Icons.class_rounded, const Color(0xFFF59E0B), isDark);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('schools').doc(schoolId).collection('subjects').snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildStatCardDesktop('Mata Pelajaran', '$count', Icons.menu_book_rounded, const Color(0xFF10B981), isDark);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Live Data Panels
            _buildSectionTitle('Info Cepat', Icons.info_outline_rounded, isDark),
            const SizedBox(height: 16),
            SizedBox(
              height: 360,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Panel 1: Daftar Hadir Harian Guru
                  Expanded(
                    child: _buildLiveDataPanel(
                      title: 'Hadir Harian Guru',
                      icon: Icons.co_present_rounded,
                      color: const Color(0xFF6366F1),
                      isDark: isDark,
                      onViewAll: () => Get.to(() => const AdminTeacherAttendancePage(isMonthly: false)),
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(schoolId)
                          .collection('teacher_daily_attendance')
                          .where('date', isEqualTo: _getTodayStr())
                          .orderBy('checkInTime', descending: false)
                          .snapshots(),
                      itemBuilder: (doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final name = d['teacherName'] ?? d['nama'] ?? '-';
                        final status = d['status'] ?? 'hadir';
                        final isLate = status == 'terlambat';
                        final statusColor = isLate ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
                        final checkIn = d['checkInTime'];
                        String timeStr = '';
                        if (checkIn is Timestamp) {
                          final t = checkIn.toDate().toLocal();
                          timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                        }
                        return _buildPanelRow(
                          leading: Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          title: name,
                          trailing: timeStr.isNotEmpty ? timeStr : status,
                          trailingColor: statusColor,
                          isDark: isDark,
                        );
                      },
                      emptyText: 'Belum ada absensi guru hari ini',
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Panel 2: Daftar Pelanggaran Siswa
                  Expanded(
                    child: _buildLiveDataPanel(
                      title: 'Pelanggaran Siswa',
                      icon: Icons.report_problem_rounded,
                      color: const Color(0xFFEF4444),
                      isDark: isDark,
                      onViewAll: () => Get.to(() => const AdminViolationsHistoryPage()),
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(schoolId)
                          .collection('violations')
                          .orderBy('date', descending: true)
                          .limit(20)
                          .snapshots(),
                      itemBuilder: (doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final name = d['studentName'] ?? '-';
                        final jenis = d['jenis'] ?? 'Pelanggaran';
                        final poin = d['poin'] ?? 0;
                        return _buildPanelRow(
                          leading: const Icon(Icons.report_rounded, color: Color(0xFFEF4444), size: 14),
                          title: name,
                          subtitle: jenis,
                          trailing: '-$poin',
                          trailingColor: const Color(0xFFEF4444),
                          isDark: isDark,
                        );
                      },
                      emptyText: 'Tidak ada catatan pelanggaran',
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Panel 3: Murid Terlambat
                  Expanded(
                    child: _buildLiveDataPanel(
                      title: 'Murid Terlambat',
                      icon: Icons.timer_off_rounded,
                      color: const Color(0xFFF59E0B),
                      isDark: isDark,
                      onViewAll: () => Get.to(() => const DailyRecapPage()),
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(schoolId)
                          .collection('daily_attendance')
                          .where('date', isEqualTo: _getTodayStr())
                          .where('status', isEqualTo: 'terlambat')
                          .orderBy('timestamp', descending: false)
                          .snapshots(),
                      itemBuilder: (doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final name = d['studentName'] ?? '-';
                        final className = d['className'] ?? '';
                        final ts = d['timestamp'];
                        String timeStr = '';
                        if (ts is Timestamp) {
                          final t = ts.toDate().toLocal();
                          timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                        }
                        return _buildPanelRow(
                          leading: const Icon(Icons.access_time_rounded, color: Color(0xFFF59E0B), size: 14),
                          title: name,
                          subtitle: className,
                          trailing: timeStr,
                          trailingColor: const Color(0xFFF59E0B),
                          isDark: isDark,
                        );
                      },
                      emptyText: 'Tidak ada murid terlambat hari ini',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMergedHeaderCardDesktop(bool isDark) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);


    return MotifCard(
      isDark: isDark,
      cardColor: cardColor,
      cardBorderColor: cardBorder,
      cardShadowColor: cardShadow,
      child: Row(
        children: [
          // School Logo / Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: _schoolLogoBase64 != null
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _schoolLogoBase64 != null
                  ? Image.memory(
                      base64Decode(_schoolLogoBase64!),
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    )
                  : const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
            ),
          ),
          const SizedBox(width: 24),
          // School and Admin Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoadingSchool
                    ? SizedBox(
                        height: 24,
                        width: 200,
                        child: LinearProgressIndicator(
                          backgroundColor: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        ),
                      )
                    : Text(
                        _schoolName ?? 'Sekolah Baru',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                const SizedBox(height: 6),
                Text(
                  'School ID: $schoolId',
                  style: TextStyle(
                    fontSize: 13, 
                    color: subtitleColor, 
                    fontWeight: FontWeight.w500
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Badges and System Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'Admin Sekolah',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                  ), // Removed plan badge display
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Sistem Aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardDesktop(String title, String value, IconData icon, Color color, bool isDark) {
    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final valueColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final titleColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final cardShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardBorderColor,
        ),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTodayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Widget _buildLiveDataPanel({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onViewAll,
    required Stream<QuerySnapshot> stream,
    required Widget Function(QueryDocumentSnapshot) itemBuilder,
    required String emptyText,
  }) {
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onViewAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Lihat Semua',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
          ),
          // Panel Content
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: color.withValues(alpha: 0.2), size: 32),
                          const SizedBox(height: 8),
                          Text(
                            emptyText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.35),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => itemBuilder(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelRow({
    required Widget leading,
    required String title,
    String? subtitle,
    required String trailing,
    required Color trailingColor,
    required bool isDark,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subColor = isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(color: subColor, fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: TextStyle(
              color: trailingColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _logout() async {

    final isDark = AuthBackground.isDarkMode.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), 
              width: 1.5
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalization.isIndonesian ? 'Konfirmasi Logout' : 'Confirm Logout',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalization.isIndonesian
                    ? 'Apakah Anda yakin ingin keluar dari aplikasi?'
                    : 'Are you sure you want to exit the application?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6),
                  height: 1.5,
                ),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Get.back(result: false),
                    child: Text(AppLocalization.cancelButton, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1B4B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Get.back(result: true),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(AppLocalization.isIndonesian ? 'Keluar' : 'Logout', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await AppAuthService.logout();
      } catch (e) {
        Get.snackbar('Error', 'Gagal logout: $e');
      }
    }
  }
}

class _MenuData {
  final String title;
  final IconData icon;
  final Color color;
  final String? badge;
  const _MenuData(this.title, this.icon, this.color, {this.badge});
}
