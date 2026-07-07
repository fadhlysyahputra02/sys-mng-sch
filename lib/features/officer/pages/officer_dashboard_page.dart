import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/app_auth_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../../teachers/pages/teacher_settings_page.dart';
import '../../schools/pages/teachers/pages/admin_teacher_attendance_page.dart';

import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../core/widgets/motif_card.dart';

class OfficerDashboardPage extends StatefulWidget {
  const OfficerDashboardPage({super.key});

  @override
  State<OfficerDashboardPage> createState() => _OfficerDashboardPageState();
}

class _OfficerDashboardPageState extends State<OfficerDashboardPage> {
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
    await AppAuthService.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    if (user == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.splash));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data();
        final isOfficer = userData?['role'] == 'officer';
        final scanGuruEnabled = userData?['scanGuruEnabled'] as bool? ??
            (isOfficer ? true : (userData?['isGateOfficer'] as bool? ?? false));
        final scanMuridEnabled = userData?['scanMuridEnabled'] as bool? ??
            (isOfficer ? true : (userData?['isGateOfficer'] as bool? ?? false));

        return ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
            return ValueListenableBuilder<String>(
              valueListenable: AppLocalization.currentLocale,
              builder: (context, locale, _) {
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
                      AppLocalization.isIndonesian ? 'Dashboard Officer' : 'Officer Dashboard',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.settings_rounded, color: textColor),
                        onPressed: () => Get.to(() => const TeacherSettingsPage()),
                        tooltip: AppLocalization.isIndonesian ? 'Pengaturan' : 'Settings',
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.red),
                        onPressed: _logout,
                        tooltip: AppLocalization.isIndonesian ? 'Keluar' : 'Logout',
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
                            'Menu Cepat',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ─── MURID section ───────────────────────────────
                          _buildSectionLabel('Absensi Murid', Icons.school_rounded, const Color(0xFF10B981), textColor),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: [
                              _buildMenuCard(
                                title: 'Scan Murid\n(Masuk)',
                                icon: Icons.qr_code_scanner_rounded,
                                color: const Color(0xFF10B981), // Emerald Green
                                onTap: () => Get.toNamed(AppRoutes.officerScan, arguments: {'role': 'student', 'action': 'check_in'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanMuridEnabled,
                              ),
                              _buildMenuCard(
                                title: 'Scan Murid\n(Pulang)',
                                icon: Icons.exit_to_app_rounded,
                                color: const Color(0xFF059669), // Darker Green
                                onTap: () => Get.toNamed(AppRoutes.officerScan, arguments: {'role': 'student', 'action': 'check_out'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanMuridEnabled,
                              ),
                              _buildMenuCard(
                                title: 'Absen Manual\nMurid (Masuk)',
                                icon: Icons.how_to_reg_rounded,
                                color: const Color(0xFF34D399), // Light Green
                                onTap: () => Get.toNamed(AppRoutes.officerManual, arguments: {'mode': 'student_check_in'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanMuridEnabled,
                              ),
                              _buildMenuCard(
                                title: 'Absen Manual\nMurid (Pulang)',
                                icon: Icons.assignment_return_rounded,
                                color: const Color(0xFF0D9488), // Teal Green
                                onTap: () => Get.toNamed(AppRoutes.officerManual, arguments: {'mode': 'student_check_out'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanMuridEnabled,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ─── GURU section ────────────────────────────────
                          _buildSectionLabel('Absensi Guru', Icons.assignment_ind_rounded, const Color(0xFF2563EB), textColor),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: [
                              _buildMenuCard(
                                title: 'Scan Guru\n(Masuk)',
                                icon: Icons.qr_code_scanner_rounded,
                                color: const Color(0xFF3B82F6), // Blue
                                onTap: () => Get.toNamed(AppRoutes.officerScan, arguments: {'role': 'teacher', 'action': 'check_in'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanGuruEnabled,
                              ),
                              _buildMenuCard(
                                title: 'Scan Guru\n(Pulang)',
                                icon: Icons.exit_to_app_rounded,
                                color: const Color(0xFF1D4ED8), // Dark Blue
                                onTap: () => Get.toNamed(AppRoutes.officerScan, arguments: {'role': 'teacher', 'action': 'check_out'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanGuruEnabled,
                              ),
                              _buildMenuCard(
                                title: 'Absen Manual\nGuru (Masuk)',
                                icon: Icons.how_to_reg_rounded,
                                color: const Color(0xFF60A5FA), // Light Blue
                                onTap: () => Get.toNamed(AppRoutes.officerManual, arguments: {'mode': 'teacher_check_in'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanGuruEnabled,
                              ),
                              _buildMenuCard(
                                title: 'Absen Manual\nGuru (Pulang)',
                                icon: Icons.assignment_return_rounded,
                                color: const Color(0xFF2563EB), // Royal Blue
                                onTap: () => Get.toNamed(AppRoutes.officerManual, arguments: {'mode': 'teacher_check_out'}),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanGuruEnabled,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ─── REKAP section ───────────────────────────────
                          _buildSectionLabel('Rekap Absensi', Icons.bar_chart_rounded, const Color(0xFF6366F1), textColor),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.1,
                            children: [
                              _buildMenuCard(
                                title: 'Rekap Murid',
                                icon: Icons.school_rounded,
                                color: const Color(0xFF10B981),
                                onTap: () => Get.toNamed(AppRoutes.officerRecap),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanMuridEnabled,
                              ),
                              _buildMenuCard(
                                title: 'Rekap Guru',
                                icon: Icons.assignment_ind_rounded,
                                color: const Color(0xFF3B82F6),
                                onTap: () => Get.to(() => const AdminTeacherAttendancePage(isMonthly: false)),
                                textColor: textColor,
                                cardBg: cardBg,
                                cardBorder: cardBorder,
                                isDisabled: !scanGuruEnabled,
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
      },
    );
  },
);
  }

  Widget _buildSectionLabel(String label, IconData icon, Color color, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
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
    bool isDisabled = false,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.55 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled
              ? () {
                  Get.snackbar(
                    'Akses Ditolak',
                    'Otoritas scan untuk fitur ini tidak aktif.',
                    backgroundColor: Colors.amber,
                    colorText: Colors.black,
                  );
                }
              : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey.withOpacity(0.05) : cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDisabled ? Colors.grey.withOpacity(0.3) : cardBorder),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDisabled ? Colors.grey.withOpacity(0.1) : color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: isDisabled ? Colors.grey : color, size: 32),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDisabled ? Colors.grey : textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDisabled)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.redAccent,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
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
                      'Officer: $adminNama',
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
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Officer',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                ),
              ),
              // Removed plan badge display
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
                  Text(
                    AppLocalization.isIndonesian ? 'Sistem Aktif' : 'System Active',
                    style: const TextStyle(
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
}
