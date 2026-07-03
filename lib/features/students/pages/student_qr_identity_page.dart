import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../authentication/widgets/auth_background.dart';

class StudentQrIdentityPage extends StatelessWidget {
  final String studentDocId;
  final Map<String, dynamic> studentData;
  final String schoolId;
  final String? schoolName;

  const StudentQrIdentityPage({
    super.key,
    required this.studentDocId,
    required this.studentData,
    required this.schoolId,
    this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
    final nama = studentData['nama'] ?? '-';
    final nis = studentData['nis'] ?? '-';
    final className = studentData['className'] ?? '-';

    // QR payload — JSON yang akan di-scan petugas
    final qrData = jsonEncode({
      'studentId': studentDocId,
      'schoolId': schoolId,
      'nis': nis,
      'nama': nama,
      'className': className,
    });

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.6)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
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
                  // AppBar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: textColor),
                        ),
                        Text(
                          'QR Saya',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Info card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              children: [
                                // Avatar
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.15),
                                    border: Border.all(
                                        color: const Color(0xFF8B5CF6),
                                        width: 2),
                                  ),
                                  child: const Icon(Icons.person_rounded,
                                      size: 38, color: Color(0xFF8B5CF6)),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  nama,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'NIS: $nis',
                                  style: TextStyle(
                                      color: subTextColor, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Kelas $className',
                                  style: TextStyle(
                                      color: subTextColor, fontSize: 13),
                                ),
                                if (schoolName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    schoolName!,
                                    style: TextStyle(
                                        color: subTextColor, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // QR Code card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Tunjukkan QR ini ke petugas',
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 220,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape:
                                          QrDataModuleShape.square,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          color: Color(0xFF8B5CF6), size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'QR ini unik untuk identitas kamu',
                                        style: TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
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