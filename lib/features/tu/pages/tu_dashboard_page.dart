import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';

import '../../officer/pages/daily_recap_page.dart';
import '../../schools/pages/settings/school_settings_page.dart';
import '../../schools/pages/teachers/pages/admin_teacher_attendance_page.dart';

import '../../schools/pages/classes/pages/class_list_page.dart';
import '../../schools/pages/subjects/pages/subject_list_page.dart';
import '../../schools/pages/schedule/Page/class_schedule_overview_page.dart';
import '../../schools/pages/officers/pages/officer_management_page.dart';
import '../../schools/pages/teachers/pages/teacher_list_admin_page.dart';
import '../../schools/pages/students/pages/student_admin_list_page.dart';
import '../../schools/pages/notifications/notifications_page.dart';
import '../../shared/coming_soon_page.dart';

import '../../../core/widgets/motif_card.dart';
import 'tu_payment_dashboard.dart';

class TuDashboardPage extends StatefulWidget {
  const TuDashboardPage({super.key});

  @override
  State<TuDashboardPage> createState() => _TuDashboardPageState();
}

class _TuDashboardPageState extends State<TuDashboardPage> {
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
      } else {
        if (mounted) setState(() => _isLoadingSchool = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSchool = false);
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[now.weekday % 7];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 10) return 'Selamat Pagi';
    if (hour <= 14) return 'Selamat Siang';
    if (hour <= 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    SessionService.currentUser = null;
    Get.offAllNamed(AppRoutes.login);
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

  List<Map<String, dynamic>> get _menuItems => [
    {
      'title': 'Dashboard',
      'icon': Icons.dashboard_rounded,
      'color': const Color(0xFF6366F1),
    },
    {
      'title': 'Manajemen Siswa',
      'icon': Icons.people_rounded,
      'color': const Color(0xFF3B82F6),
      'onTap': () => Get.to(() => StudentListPage(schoolId: schoolId)),
    },
    {
      'title': 'Manajemen Guru',
      'icon': Icons.school_rounded,
      'color': const Color(0xFFF59E0B),
      'onTap': () => Get.to(() => TeacherListPage(schoolId: schoolId)),
    },
    {
      'title': 'Rekap Absensi',
      'icon': Icons.calendar_month_rounded,
      'color': const Color(0xFF8B5CF6),
      'onTap': _showAbsensiSelectionDialog,
    },
    {
      'title': 'Kelas',
      'icon': Icons.class_rounded,
      'color': const Color(0xFFF59E0B),
      'onTap': () => Get.to(() => ClassListPage()),
    },
    {
      'title': 'Mata Pelajaran',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFF10B981),
      'onTap': () => Get.to(() => SubjectListPage()),
    },
    {
      'title': 'Jadwal',
      'icon': Icons.calendar_today_rounded,
      'color': const Color(0xFFEC4899),
      'onTap': () => Get.to(() => ClassScheduleOverviewPage()),
    },
    {
      'title': 'Petugas (Kepegawaian)',
      'icon': Icons.security_rounded,
      'color': const Color(0xFF8B5CF6),
      'onTap': () => Get.to(() => const OfficerManagementPage()),
    },
    {
      'title': 'Pembayaran',
      'icon': Icons.payments_rounded,
      'color': const Color(0xFF10B981),
      'onTap': () => Get.to(() => TUPaymentDashboard(schoolId: schoolId)),
    },
    {
      'title': 'Notifikasi',
      'icon': Icons.notifications_rounded,
      'color': const Color(0xFFEF4444),
      'onTap': () => Get.to(() => NotificationsPage()),
    },
    {
      'title': 'Export Laporan',
      'icon': Icons.file_download_rounded,
      'color': const Color(0xFF10B981),
      'badge': 'BASIC',
      'onTap': () => Get.toNamed(AppRoutes.comingSoonExportTu),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    if (user == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.splash));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final isWeb = MediaQuery.of(context).size.width > 800;

        if (isWeb) {
          return _buildWebLayout(isDark);
        } else {
          return _buildMobileLayout(isDark);
        }
      },
    );
  }

  Widget _buildWebLayout(bool isDark) {
    final panelBg = isDark ? const Color(0xFF0B081B) : const Color(0xFFF8FAFC);

    return Scaffold(
      body: Row(
        children: [
          // ── SIDEBAR ──
          _buildSidebar(isDark),
          // ── KONTEN UTAMA ──
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
          right: BorderSide(color: borderRightColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header sidebar: logo kiri + nama sekolah kanan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _schoolLogoBase64 != null
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: miniLogoBorder, width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: _schoolLogoBase64 != null
                        ? Image.memory(base64Decode(_schoolLogoBase64!), fit: BoxFit.cover)
                        : const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
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
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
                            ),
                      const SizedBox(height: 4),
                      _buildPlanBadgeSidebar(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(color: dividerColor, height: 1),
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildSidebarItem('Dashboard', Icons.dashboard_rounded, 0, const Color(0xFF6366F1), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Manajemen Siswa', Icons.people_rounded, 1, const Color(0xFF3B82F6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Manajemen Guru', Icons.school_rounded, 2, const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Rekap Absensi', Icons.calendar_month_rounded, 3, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Kelas', Icons.class_rounded, 4, const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Mata Pelajaran', Icons.menu_book_rounded, 5, const Color(0xFF10B981), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Jadwal', Icons.calendar_today_rounded, 6, const Color(0xFFEC4899), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Petugas', Icons.security_rounded, 7, const Color(0xFF8B5CF6), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Pembayaran', Icons.payments_rounded, 8, const Color(0xFF10B981), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Notifikasi', Icons.notifications_rounded, 9, const Color(0xFFEF4444), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Export Laporan', Icons.file_download_rounded, 10, const Color(0xFF10B981), isDark),
                const SizedBox(height: 4),
                _buildSidebarItem('Pengaturan', Icons.settings_rounded, 11, const Color(0xFF64748B), isDark),
              ],
            ),
          ),
          Divider(color: dividerColor, height: 1),
          // Logout
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
          setState(() => _selectedMenuIndex = index);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: itemBorder, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
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

  Widget _buildPlanBadgeSidebar() {
    Gradient badgeGradient;
    if (_plan == 'PRO') {
      badgeGradient = const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]);
    } else if (_plan == 'BASIC') {
      badgeGradient = const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]);
    } else {
      badgeGradient = const LinearGradient(colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(gradient: badgeGradient, borderRadius: BorderRadius.circular(8)),
      child: Text(
        _plan,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8, letterSpacing: 0.5),
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 12),
              Text('Keluar', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(bool isDark) {
    switch (_selectedMenuIndex) {
      case 1:
        return StudentListPage(schoolId: schoolId, hideBackButton: true);
      case 2:
        return TeacherListPage(schoolId: schoolId, hideBackButton: true);
      case 3:
        return _buildDesktopAbsensiOverview(isDark);
      case 4:
        return ClassListPage(hideBackButton: true);
      case 5:
        return SubjectListPage(hideBackButton: true);
      case 6:
        return ClassScheduleOverviewPage(hideBackButton: true);
      case 7:
        return const OfficerManagementPage(hideBackButton: true);
      case 8:
        return TUPaymentDashboard(schoolId: schoolId, hideBackButton: true);
      case 9:
        return NotificationsPage(hideBackButton: true);
      case 10:
        return const ComingSoonPage(
          featureName: 'Export Laporan',
          description: 'Unduh laporan absensi, nilai, dan statistik dalam format PDF atau Excel.',
          icon: Icons.file_download_rounded,
          iconColor: Color(0xFF10B981),
          packageBadge: 'BASIC',
        );
      case 11:
        return SchoolSettingsPage(schoolId: schoolId, hideBackButton: true);
      default:
        return _buildDesktopDashboardHome(isDark);
    }
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
                  'Rekap Absensi',
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
                  style: TextStyle(color: subTextColor, fontSize: 15),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWebHeaderBar(isDark),
            const SizedBox(height: 32),
            _buildMergedHeaderCard(nama, email, isDark),
            const SizedBox(height: 32),
            Text(
              'Menu Tata Usaha',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuGrid(isDark, crossAxisCount: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildWebHeaderBar(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()}',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getFormattedDate(),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Sistem Aktif',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuGrid(bool isDark, {required int crossAxisCount}) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    final items = _menuItems.skip(1).toList();
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: crossAxisCount == 4 ? 1.3 : 1.1,
      children: items.map((item) => _buildMenuCard(
        title: item['title'] as String,
        icon: item['icon'] as IconData,
        color: item['color'] as Color,
        onTap: (item['onTap'] as VoidCallback?) ?? () {},
        textColor: textColor,
        cardBg: cardBg,
        cardBorder: cardBorder,
        badge: item['badge'] as String?,
      )).toList(),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Dashboard Tata Usaha',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: textColor),
            onPressed: () => Get.to(() => SchoolSettingsPage(schoolId: schoolId)),
            tooltip: 'Pengaturan',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            onPressed: _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMergedHeaderCard(nama, email, isDark),
                  const SizedBox(height: 32),
                  Text(
                    'Menu Tata Usaha',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuGrid(isDark, crossAxisCount: 2),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required Color textColor,
    required Color cardBg,
    required Color cardBorder,
    String? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 32),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildPackageBadge(badge),
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
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: _schoolLogoBase64 != null
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
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
                          Icons.support_agent_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              ),
              const SizedBox(width: 16),
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
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
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
                      'Tata Usaha: $adminNama',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Tata Usaha',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                ),
              ),
              const SizedBox(width: 8),
              _buildPlanBadge(),
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

  Widget _buildPlanBadge() {
    Color badgeColor;
    Gradient badgeGradient;
    IconData icon;
    String label = _plan;

    if (label == 'PRO') {
      badgeColor = const Color(0xFFD97706);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.workspace_premium_rounded;
    } else if (label == 'BASIC') {
      badgeColor = const Color(0xFF2563EB);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.star_rounded;
    } else {
      badgeColor = const Color(0xFF4B5563);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: badgeGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
