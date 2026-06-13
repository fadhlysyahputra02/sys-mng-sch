import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../authentication/widgets/auth_background.dart';

class PremiumFeaturesPage extends StatelessWidget {
  const PremiumFeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Ambil arguments jika ada
    final Map<String, dynamic> args = Get.arguments ?? {};
    final String currentPlan = (args['plan'] ?? 'FREE').toString().toUpperCase();

    // Palette warna
    const orangePremium = Color(0xFFF97316);

    final List<_PremiumItem> features = [
      _PremiumItem(
        title: 'Wali Murid (Portal Orang Tua)',
        description: 'Menghubungkan orang tua langsung ke sistem sekolah untuk memantau nilai, kehadiran, dan tugas anak.',
        icon: Icons.family_restroom_rounded,
        badge: 'PRO',
        badgeColor: orangePremium,
        isUnlocked: currentPlan == 'PRO',
      ),
      _PremiumItem(
        title: 'E-Rapor',
        description: 'Pembuatan rapor digital otomatis, terintegrasi nilai harian, UTS, UAS, dan deskripsi kompetensi.',
        icon: Icons.description_rounded,
        badge: 'PRO',
        badgeColor: orangePremium,
        isUnlocked: currentPlan == 'PRO',
      ),
      _PremiumItem(
        title: 'WhatsApp Gateway',
        description: 'Pengiriman broadcast otomatis notifikasi absensi dan pengumuman sekolah langsung ke WhatsApp orang tua.',
        icon: Icons.chat_bubble_rounded,
        badge: 'PRO',
        badgeColor: orangePremium,
        isUnlocked: currentPlan == 'PRO',
      ),
      _PremiumItem(
        title: 'Manajemen Keuangan & SPP',
        description: 'Pencatatan tagihan SPP siswa, riwayat pembayaran, laporan keuangan sekolah secara real-time.',
        icon: Icons.account_balance_wallet_rounded,
        badge: 'PRO',
        badgeColor: orangePremium,
        isUnlocked: currentPlan == 'PRO',
      ),
      _PremiumItem(
        title: 'Manajemen Jurusan',
        description: 'Pengaturan program studi/jurusan sekolah untuk penyesuaian kurikulum dan pengelompokan kelas.',
        icon: Icons.account_tree_rounded,
        badge: 'BASIC',
        badgeColor: const Color(0xFF0EA5E9),
        isUnlocked: currentPlan == 'BASIC' || currentPlan == 'PRO',
      ),
    ];

    return Scaffold(
      body: AuthBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Elegant Sliver App Bar
            SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              leading: Container(
                margin: const EdgeInsets.only(left: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: const Text(
                'Fitur Premium',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Plan Status Info
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: currentPlan == 'PRO'
                              ? orangePremium.withValues(alpha: 0.15)
                              : currentPlan == 'BASIC'
                                  ? const Color(0xFF0EA5E9).withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          currentPlan == 'PRO'
                              ? Icons.workspace_premium_rounded
                              : currentPlan == 'BASIC'
                                  ? Icons.star_rounded
                                  : Icons.shield_outlined,
                          color: currentPlan == 'PRO'
                              ? orangePremium
                              : currentPlan == 'BASIC'
                                  ? const Color(0xFF0EA5E9)
                                  : Colors.white60,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Langganan Sekolah',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Paket $currentPlan',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (currentPlan == 'FREE')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                                    ),
                                    child: const Text(
                                      'Terbatas',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Header Text
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.white.withValues(alpha: 0.8), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Daftar Fitur Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Features List
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = features[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: item.isUnlocked ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.015),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: item.isUnlocked 
                              ? Colors.white.withValues(alpha: 0.08) 
                              : Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Feature Icon
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: item.badgeColor.withValues(alpha: item.isUnlocked ? 0.15 : 0.05),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.isUnlocked ? item.badgeColor : Colors.white24,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Title & Description
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: item.isUnlocked ? Colors.white : Colors.white30,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Level Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item.badgeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          item.badge,
                                          style: TextStyle(
                                            color: item.badgeColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.isUnlocked ? Colors.white70 : Colors.white24,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Lock / Unlock indicator
                                  Row(
                                    children: [
                                      Icon(
                                        item.isUnlocked ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded,
                                        size: 14,
                                        color: item.isUnlocked ? const Color(0xFF10B981) : Colors.white30,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.isUnlocked ? 'Fitur Aktif' : 'Terkunci di Paket Anda',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: item.isUnlocked ? const Color(0xFF10B981) : Colors.white30,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: features.length,
                ),
              ),
            ),

            // Upgrade Promotion Section
            if (currentPlan != 'PRO')
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.amber,
                          size: 44,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Optimalkan Sistem Sekolah Anda',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dapatkan integrasi WhatsApp Gateway, Portal Wali Murid, dan E-Rapor secara penuh dengan melakukan upgrade ke Paket PRO.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: const Color(0xFF1E1B4B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Get.snackbar(
                              'Informasi Upgrade',
                              'Hubungi sales/admin untuk melakukan upgrade plan sekolah Anda.',
                              backgroundColor: Colors.white,
                              colorText: Colors.black,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          },
                          child: const Text(
                            'Hubungi Admin/Upgrade',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumItem {
  final String title;
  final String description;
  final IconData icon;
  final String badge;
  final Color badgeColor;
  final bool isUnlocked;

  const _PremiumItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.badge,
    required this.badgeColor,
    required this.isUnlocked,
  });
}
