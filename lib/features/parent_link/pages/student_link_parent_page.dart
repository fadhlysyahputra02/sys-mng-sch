import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../authentication/widgets/auth_background.dart';
import '../services/link_service.dart';

class StudentLinkParentPage extends StatefulWidget {
  final String schoolId;
  final String studentId;
  final String studentName;

  const StudentLinkParentPage({
    super.key,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentLinkParentPage> createState() => _StudentLinkParentPageState();
}

class _StudentLinkParentPageState extends State<StudentLinkParentPage> {
  final _linkService = LinkService();

  Map<String, dynamic>? _payload;
  String? _qrData;
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _studentSub;
  Duration _remaining = Duration.zero;
  bool _isLoading = true;
  bool _isExpired = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateQr();
    _listenParentLinked();
  }

  void _listenParentLinked() {
    _studentSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('students')
        .doc(widget.studentId)
        .snapshots()
        .listen((doc) {
      if (!mounted || doc.data()?['parentLinked'] != true) return;

      _countdownTimer?.cancel();
      Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _studentSub?.cancel();
    super.dispose();
  }

  Future<void> _generateQr() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isExpired = false;
    });

    try {
      final payload = await _linkService.generateLinkPayload(
        schoolId: widget.schoolId,
        studentId: widget.studentId,
        studentName: widget.studentName,
      );

      final expiresAt = DateTime.parse(payload['expiresAt'] as String).toLocal();

      if (!mounted) return;

      setState(() {
        _payload = payload;
        _qrData = _linkService.encodePayload(payload);
        _expiresAt = expiresAt;
        _remaining = expiresAt.difference(DateTime.now());
        _isLoading = false;
      });

      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_expiresAt == null) return;
      final remaining = _expiresAt!.difference(DateTime.now());
      if (!mounted) return;

      if (remaining.isNegative || remaining == Duration.zero) {
        setState(() {
          _remaining = Duration.zero;
          _isExpired = true;
        });
        _countdownTimer?.cancel();
      } else {
        setState(() => _remaining = remaining);
      }
    });
  }

  String _formatCountdown(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: textColor, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sambungkan ke Orang Tua',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF8B5CF6),
                            ),
                          )
                        : _error != null
                            ? _buildError(textColor, subTextColor)
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Text(
                                      'Tunjukkan QR ini ke orang tua',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Orang tua scan QR saat mendaftar akun',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(color: cardBorder),
                                        boxShadow: isDark
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.06),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                      ),
                                      child: Column(
                                        children: [
                                          if (_isExpired)
                                            const Icon(
                                              Icons.timer_off_rounded,
                                              color: Color(0xFFEF4444),
                                              size: 48,
                                            )
                                          else if (_qrData != null)
                                            QrImageView(
                                              data: _qrData!,
                                              version: QrVersions.auto,
                                              size: 220,
                                              gapless: false,
                                              foregroundColor:
                                                  const Color(0xFF0F0C20),
                                            ),
                                          const SizedBox(height: 20),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _isExpired
                                                  ? const Color(0xFFEF4444)
                                                      .withValues(alpha: 0.15)
                                                  : const Color(0xFF8B5CF6)
                                                      .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isExpired
                                                      ? Icons.error_outline
                                                      : Icons.timer_rounded,
                                                  color: _isExpired
                                                      ? const Color(0xFFEF4444)
                                                      : const Color(0xFF8B5CF6),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _isExpired
                                                      ? 'QR kedaluwarsa'
                                                      : 'Berlaku: ${_formatCountdown(_remaining)}',
                                                  style: TextStyle(
                                                    color: _isExpired
                                                        ? const Color(0xFFEF4444)
                                                        : const Color(0xFF8B5CF6),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildInfoRow(
                                      icon: Icons.person_rounded,
                                      label: 'Murid',
                                      value: widget.studentName,
                                      textColor: textColor,
                                      subTextColor: subTextColor,
                                      cardBg: cardBg,
                                      cardBorder: cardBorder,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      icon: Icons.key_rounded,
                                      label: 'Token',
                                      value: (_payload?['token'] ?? '-')
                                          .toString()
                                          .substring(0, 8),
                                      textColor: textColor,
                                      subTextColor: subTextColor,
                                      cardBg: cardBg,
                                      cardBorder: cardBorder,
                                    ),
                                    const SizedBox(height: 28),
                                    if (_isExpired)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _generateQr,
                                          icon: const Icon(Icons.refresh_rounded),
                                          label: const Text('Buat QR Baru'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF8B5CF6),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
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
        );
      },
    );
  }

  Widget _buildError(Color textColor, Color subTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: subTextColor),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generateQr,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subTextColor,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: subTextColor, fontSize: 11)),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
