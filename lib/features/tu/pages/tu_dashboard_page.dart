import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';

import '../../officer/pages/daily_recap_page.dart';
import '../../officer/pages/monthly_recap_page.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
            Row(
              children: [
                Expanded(
                  child: _buildSelectionCard(
                    title: 'Rekap Harian',
                    description: 'Laporan kehadiran per tanggal',
                    icon: Icons.calendar_today_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Get.back();
                      Get.to(() => const DailyRecapPage());
                    },
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textColor: textColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSelectionCard(
                    title: 'Rekap Bulanan',
                    description: 'Statistik kehadiran per kelas',
                    icon: Icons.calendar_month_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Get.back();
                      Get.to(() => const MonthlyRecapPage());
                    },
                    isDark: isDark,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    textColor: textColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    required Color textColor,
  }) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

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
                      // Profile & School Header
                      _buildMergedHeaderCard(nama, email, isDark),
                      const SizedBox(height: 32),

                      // Quick Actions Grid
                      Text(
                        'Menu Tata Usaha',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          _buildMenuCard(
                            title: 'Manajemen Siswa',
                            icon: Icons.people_rounded,
                            color: const Color(0xFF3B82F6),
                            onTap: () => Get.toNamed(AppRoutes.studentList),
                            textColor: textColor,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          ),
                          _buildMenuCard(
                            title: 'Manajemen Guru',
                            icon: Icons.school_rounded,
                            color: const Color(0xFFF59E0B),
                            onTap: () => Get.toNamed(AppRoutes.teacherlist),
                            textColor: textColor,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          ),
                          _buildMenuCard(
                            title: 'Rekap Absensi',
                            icon: Icons.calendar_month_rounded,
                            color: const Color(0xFF8B5CF6),
                            onTap: _showAbsensiSelectionDialog,
                            textColor: textColor,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          ),
                          _buildMenuCard(
                            title: 'Pembayaran',
                            icon: Icons.payments_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () {
                              // TODO: Add payments page route
                              Get.snackbar('Segera Hadir', 'Fitur Pembayaran sedang dalam pengembangan.');
                            },
                            textColor: textColor,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          ),
                          _buildMenuCard(
                            title: 'Notifikasi',
                            icon: Icons.notifications_rounded,
                            color: const Color(0xFFEF4444),
                            onTap: () => Get.toNamed(AppRoutes.notifications),
                            textColor: textColor,
                            cardBg: cardBg,
                            cardBorder: cardBorder,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
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
      ),
    );
  }

  Widget _buildMergedHeaderCard(String adminNama, String adminEmail, bool isDark) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final emailColor = isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final dateColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                    Text(
                      adminEmail,
                      style: TextStyle(
                        fontSize: 11, 
                        color: emailColor
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
