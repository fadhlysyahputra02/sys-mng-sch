import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../authentication/widgets/auth_background.dart';

/// Halaman placeholder universal untuk fitur-fitur yang akan datang.
/// Menampilkan icon, nama fitur, badge paket, dan pesan Coming Soon.
class ComingSoonPage extends StatelessWidget {
  final String featureName;
  final String description;
  final IconData icon;
  final Color iconColor;

  /// Badge paket: 'BASIC', 'PRO', atau null (tidak menampilkan badge paket)
  final String? packageBadge;

  const ComingSoonPage({
    super.key,
    required this.featureName,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.packageBadge,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark
            ? Colors.white.withValues(alpha: 0.65)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
        final cardBg =
            isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: Column(
                children: [
                  // AppBar custom
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: titleColor,
                              size: 18,
                            ),
                            onPressed: () => Get.back(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            featureName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 24),
                        child: Container(
                          padding: const EdgeInsets.all(36),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: cardBorder),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon besar
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: iconColor.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  color: iconColor,
                                  size: 56,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Badge row: COMING SOON + paket badge
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  // Badge COMING SOON
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFF97316),
                                          Color(0xFFEA580C),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF97316)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.schedule_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        SizedBox(width: 5),
                                        Text(
                                          'COMING SOON',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Badge Paket (BASIC / PRO)
                                  if (packageBadge != null)
                                    _PackageBadge(package: packageBadge!),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Nama Fitur
                              Text(
                                featureName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Deskripsi singkat
                              Text(
                                description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtitleColor,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Divider
                              Container(
                                height: 1,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                              const SizedBox(height: 24),

                              // Pesan pengembangan
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF97316)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFF97316)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFFF97316),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Fitur ini sedang dalam tahap pengembangan dan akan tersedia pada update berikutnya.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.75)
                                              : const Color(0xFF1E1B4B)
                                                  .withValues(alpha: 0.75),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Tombol Kembali
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => Get.back(),
                                  icon: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 16),
                                  label: const Text('Kembali'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: iconColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

/// Widget badge untuk paket BASIC atau PRO
class _PackageBadge extends StatelessWidget {
  final String package;
  const _PackageBadge({required this.package});

  @override
  Widget build(BuildContext context) {
    final isBasic = package.toUpperCase() == 'BASIC';
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
    final shadowColor =
        isBasic ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    final icon =
        isBasic ? Icons.star_rounded : Icons.workspace_premium_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            package.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
