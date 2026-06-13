import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/services/app_auth_service.dart';
import '../../../../core/services/session_service.dart';
import '../../services/school_service.dart';
import '../classes/pages/class_list_page.dart';
import '../settings/school_settings_page.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  final schoolId = SessionService.currentUser!.schoolId;
  final nama = SessionService.currentUser!.nama;

  String? _schoolName;
  String _plan = 'FREE';
  String? _schoolLogoBase64;
  bool _isLoadingSchool = true;

  // Warna palette
  static const _primary = Color(0xFF4F46E5);   // indigo
  static const _surface = Color(0xFFF8F7FF);
  static const _cardBg = Colors.white;

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

  final List<_MenuData> _menus = [
    _MenuData('Guru', Icons.person_outline_rounded, Color(0xFF6366F1), Color(0xFFEDE9FE)),
    _MenuData('Murid', Icons.groups_outlined, Color(0xFF0EA5E9), Color(0xFFE0F2FE)),
    _MenuData('Mata Pelajaran', Icons.menu_book_outlined, Color(0xFF10B981), Color(0xFFD1FAE5)),
    _MenuData('Kelas', Icons.class_outlined, Color(0xFFF59E0B), Color(0xFFFEF3C7)),
    _MenuData('Jadwal', Icons.calendar_month_outlined, Color(0xFFEC4899), Color(0xFFFCE7F3)),
    _MenuData('Absensi', Icons.fact_check_outlined, Color(0xFF8B5CF6), Color(0xFFEDE9FE)),
    _MenuData('Nilai', Icons.grade_outlined, Color(0xFFEF4444), Color(0xFFFEE2E2)),
    _MenuData('Pengaturan', Icons.settings_outlined, Color(0xFF64748B), Color(0xFFF1F5F9)),
  ];

  final List<_PremiumData> _premiums = [
    _PremiumData('Wali Murid', Icons.family_restroom, 'PRO', Color(0xFFF97316)),
    _PremiumData('E-Rapor', Icons.description_outlined, 'PRO', Color(0xFFF97316)),
    _PremiumData('WhatsApp Gateway', Icons.chat_bubble_outline, 'PRO', Color(0xFFF97316)),
    _PremiumData('Keuangan', Icons.account_balance_wallet_outlined, 'PRO', Color(0xFFF97316)),
    _PremiumData('Jurusan', Icons.account_tree_outlined, 'BASIC', Color(0xFF0EA5E9)),
  ];

  void _onMenuTap(String title) async {
    switch (title) {
      case 'Guru':
        Get.toNamed(AppRoutes.teacherlist);
        break;
      case 'Murid':
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
      case 'Pengaturan':
        final updated = await Get.to(() => SchoolSettingsPage(schoolId: schoolId));
        if (updated == true) {
          _loadSchoolData();
        }
        break;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 10) return 'Selamat Pagi';
    if (hour <= 14) return 'Selamat Siang';
    if (hour <= 18) return 'Selamat Sore';
    return 'Selamat Malam';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: const Color(0xFF312E81), // matching top of linear gradient
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header Stack ──
          _buildHeaderStack(),

          const SizedBox(height: 16),

          // ── Menu Grid ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Menu Utama',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _menus.length,
                  itemBuilder: (_, i) => _buildMenuCard(_menus[i]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Premium Section ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.workspace_premium, color: Color(0xFFF97316), size: 20),
                    const SizedBox(width: 6),
                    const Text(
                      'Fitur Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1B4B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._premiums.map((p) => _buildPremiumTile(p)),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderStack() {
    return SizedBox(
      height: 235,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Gradient Banner
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 175,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF312E81), // deep indigo
                    Color(0xFF4F46E5), // primary indigo
                    Color(0xFF4338CA), // indigo-700
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Stack(
                children: [
                  // Decorative abstract circle 1
                  Positioned(
                    top: -40,
                    right: -40,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  // Decorative abstract circle 2
                  Positioned(
                    bottom: -30,
                    left: -20,
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withOpacity(0.04),
                    ),
                  ),
                  // Header Content Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          // Greeting Text
                          Expanded(
                            child: Text(
                              '${_getGreeting()}, $nama',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          // Logout Button
                          Material(
                            color: Colors.white.withOpacity(0.15),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                              tooltip: 'Logout',
                              onPressed: _logout,
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
          // Overlapping School Info Card
          Positioned(
            top: 110,
            left: 16,
            right: 16,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEEF2F6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E1B4B).withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // School Building Icon Container / Dynamic School Logo
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: _schoolLogoBase64 != null
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFFEEF2F6), Color(0xFFE2E8F0)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEEF2F6), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: _schoolLogoBase64 != null
                              ? Image.memory(
                                  base64Decode(_schoolLogoBase64!),
                                  fit: BoxFit.cover,
                                  width: 52,
                                  height: 52,
                                )
                              : const Icon(
                                  Icons.school_rounded,
                                  color: Color(0xFF4F46E5),
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // School Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isLoadingSchool
                                ? const SizedBox(
                                    height: 16,
                                    width: 120,
                                    child: LinearProgressIndicator(
                                      backgroundColor: Color(0xFFEEF2F6),
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                                    ),
                                  )
                                : Text(
                                    _schoolName ?? 'Sekolah Baru',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              'School ID: $schoolId',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Plan Badge
                      _buildPlanBadge(),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 16),
                  // Footer info of card (Date & System Status)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            _getFormattedDate(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
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
                          const SizedBox(width: 4),
                          const Text(
                            'Sistem Aktif',
                            style: TextStyle(
                              fontSize: 11,
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
            ),
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
            color: badgeColor.withOpacity(0.3),
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

  Widget _buildMenuCard(_MenuData menu) {
    final bool isActive = ['Guru', 'Murid', 'Mata Pelajaran', 'Kelas', 'Jadwal', 'Pengaturan'].contains(menu.title);

    return GestureDetector(
      onTap: isActive ? () => _onMenuTap(menu.title) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: menu.color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: menu.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(menu.icon, color: menu.color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              menu.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF1E1B4B) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTile(_PremiumData p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(p.icon, color: p.color, size: 20),
        ),
        title: Text(
          p.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: p.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            p.badge,
            style: TextStyle(
              color: p.color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        onTap: () {},
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  ),
  contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.logout_rounded,
          color: Colors.red,
          size: 36,
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Konfirmasi Logout',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Apakah Anda yakin ingin keluar dari aplikasi?',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey.shade700,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Logout'),
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
  final Color bgColor;
  const _MenuData(this.title, this.icon, this.color, this.bgColor);
}

class _PremiumData {
  final String title;
  final IconData icon;
  final String badge;
  final Color color;
  const _PremiumData(this.title, this.icon, this.badge, this.color);
}
