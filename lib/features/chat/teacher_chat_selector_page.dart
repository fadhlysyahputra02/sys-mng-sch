import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../authentication/widgets/auth_background.dart';
import 'teacher_chat_list_page.dart';
import 'teacher_parent_chat_list_page.dart';

class TeacherChatSelectorPage extends StatefulWidget {
  final String schoolId;
  final String teacherDocId;
  final String teacherName;

  const TeacherChatSelectorPage({
    super.key,
    required this.schoolId,
    required this.teacherDocId,
    required this.teacherName,
  });

  @override
  State<TeacherChatSelectorPage> createState() => _TeacherChatSelectorPageState();
}

class _TeacherChatSelectorPageState extends State<TeacherChatSelectorPage> {
  StreamSubscription<DocumentSnapshot>? _schoolSub;
  bool _lockDialogShown = false;

  @override
  void initState() {
    super.initState();
    _listenToSchoolConfig();
  }

  void _listenToSchoolConfig() {
    _schoolSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final isEnabled = data['enableChat'] ?? false;

      if (!isEnabled && !_lockDialogShown && mounted) {
        _lockDialogShown = true;
        _showPremiumDialogAndExit();
      }
    });
  }

  void _showPremiumDialogAndExit() {
    final isDark = AuthBackground.isDarkMode.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Fitur Terkunci', style: TextStyle(color: Colors.amber)),
            ],
          ),
          content: Text(
            'Sekolah belum berlangganan untuk mengaktifkan fitur ini.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                if (mounted) {
                  Get.offAllNamed('/teacher'); // Exit to Dashboard
                }
              },
              child: const Text('Tutup', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _schoolSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final iconBgColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);
        final cardBg = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AppBar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: textColor,
                              size: 18,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Pilih kategori chat yang ingin Anda buka:',
                      style: TextStyle(color: subTextColor, fontSize: 14),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Pilihan Chat
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Chat Murid
                        _buildChatOption(
                          context,
                          isDark: isDark,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          icon: Icons.school_rounded,
                          color: const Color(0xFF10B981),
                          title: 'Chat dengan Murid',
                          subtitle: 'Kirim & terima pesan langsung dari siswa',
                          onTap: () {
                            Get.to(
                              () => TeacherChatListPage(
                                schoolId: widget.schoolId,
                                teacherDocId: widget.teacherDocId,
                                teacherName: widget.teacherName,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Chat Wali Murid
                        _buildChatOption(
                          context,
                          isDark: isDark,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          icon: Icons.family_restroom_rounded,
                          color: const Color(0xFFF97316),
                          title: 'Chat dengan Wali Murid',
                          subtitle:
                              'Komunikasi langsung dengan orang tua siswa',
                          onTap: () {
                            Get.to(
                              () => TeacherParentChatListPage(
                                schoolId: widget.schoolId,
                                teacherDocId: widget.teacherDocId,
                                teacherName: widget.teacherName,
                              ),
                            );
                          },
                        ),
                      ],
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

  Widget _buildChatOption(
    BuildContext context, {
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subTextColor,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
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
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: subTextColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
