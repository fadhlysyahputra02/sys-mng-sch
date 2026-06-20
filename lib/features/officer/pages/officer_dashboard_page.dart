import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../data/officer_repository.dart';
import '../data/scan_log_model.dart';
import 'package:intl/intl.dart';

class OfficerDashboardPage extends StatefulWidget {
  const OfficerDashboardPage({super.key});

  @override
  State<OfficerDashboardPage> createState() => _OfficerDashboardPageState();
}

class _OfficerDashboardPageState extends State<OfficerDashboardPage> {
  final OfficerRepository _repo = OfficerRepository();

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    SessionService.currentUser = null;
    Get.offAllNamed(AppRoutes.login);
  }

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
              'Officer Dashboard',
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                          child: const Icon(Icons.security_rounded, color: Color(0xFF6366F1), size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo,',
                                style: TextStyle(color: subTextColor, fontSize: 14),
                              ),
                              Text(
                                user.nama,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildMenuCard(
                          title: 'Scan QR',
                          icon: Icons.qr_code_scanner_rounded,
                          color: const Color(0xFF10B981),
                          onTap: () => Get.toNamed(AppRoutes.officerScan),
                          textColor: textColor,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                        ),
                        _buildMenuCard(
                          title: 'Absen Manual',
                          icon: Icons.how_to_reg_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => Get.toNamed(AppRoutes.officerManual),
                          textColor: textColor,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                        ),
                        _buildMenuCard(
                          title: 'Rekap Harian',
                          icon: Icons.bar_chart_rounded,
                          color: const Color(0xFF6366F1),
                          onTap: () => Get.toNamed(AppRoutes.officerRecap),
                          textColor: textColor,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Recent Scans
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Scan Terakhir Hari Ini',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(DateTime.now()),
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: StreamBuilder<List<ScanLogModel>>(
                        stream: _repo.getTodayScanLogs(user.schoolId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final logs = snapshot.data ?? [];
                          if (logs.isEmpty) {
                            return Center(
                              child: Text(
                                'Belum ada data scan hari ini.',
                                style: TextStyle(color: subTextColor),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: logs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              final isHadir = log.status == 'hadir';
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isHadir
                                            ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isHadir ? Icons.check_circle_rounded : Icons.warning_rounded,
                                        color: isHadir ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.studentName,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Kelas: ${log.className} • ${log.method == 'qr_scan' ? 'QR' : 'Manual'}',
                                            style: TextStyle(color: subTextColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      DateFormat('HH:mm').format(log.timeScanned),
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
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
}
