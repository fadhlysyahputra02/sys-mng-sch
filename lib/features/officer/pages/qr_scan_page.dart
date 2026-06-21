import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/services/session_service.dart';
import '../data/officer_repository.dart';
import 'package:flutter/services.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final OfficerRepository _repo = OfficerRepository();
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;

  // Toast state
  _ToastData? _toastData;
  AnimationController? _toastController;
  Animation<Offset>? _toastSlide;
  Animation<double>? _toastFade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        if (!_isProcessing) _scannerController.start();
      case AppLifecycleState.inactive:
        _scannerController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _toastController?.dispose();
    super.dispose();
  }

  // ─── Toast (sukses) ────────────────────────────────────────────────────────

  void _showSuccessToast(_ToastData data) {
    _toastController?.dispose();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
    );

    final slide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));

    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: controller, curve: const Interval(0, 0.6)),
    );

    setState(() {
      _toastController = controller;
      _toastSlide = slide;
      _toastFade = fade;
      _toastData = data;
    });

    controller.forward();

    // Tahan 2.5 detik lalu slide keluar
    Future.delayed(const Duration(milliseconds: 2800), () async {
      if (!mounted) return;
      await controller.reverse();
      if (!mounted) return;
      setState(() => _toastData = null);
      // Restart scanner setelah toast hilang
      _finishProcessing();
    });
  }

  void _finishProcessing() {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _scannerController.start();
  }

  // ─── Dialog (error) ────────────────────────────────────────────────────────

  void _showErrorDialog(String title, String message) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1A1A2E),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                  size: 52,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    _finishProcessing();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Scan Lagi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // ─── Scan handler ──────────────────────────────────────────────────────────

  Future<void> _handleScanResult(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _scannerController.stop();

    // Play beep sound (Native)
    HapticFeedback.vibrate();
    SystemSound.play(SystemSoundType.click);

    try {
      final data = jsonDecode(code) as Map<String, dynamic>;
      final user = SessionService.currentUser!;

      final String studentId = data['studentId'] ?? '';
      final String studentName = data['nama'] ?? '';
      final String schoolId = data['schoolId'] ?? '';
      final String className = data['className'] ?? '';

      if (studentId.isEmpty) {
        _showErrorDialog(
          'QR Tidak Valid',
          'Format QR Code tidak dikenali. Pastikan siswa menggunakan kartu QR dari aplikasi ini.',
        );
        return;
      }

      if (schoolId != user.schoolId) {
        _showErrorDialog(
          'Sekolah Berbeda',
          'QR Code ini berasal dari sekolah lain dan tidak dapat diproses.',
        );
        return;
      }

      final hasScanned = await _repo.hasStudentScannedToday(user.schoolId, studentId);
      if (hasScanned) {
        _showErrorDialog(
          'Sudah Tercatat',
          '$studentName sudah melakukan scan kehadiran hari ini.',
        );
        return;
      }

      // Fallback classId jika kosong di QR payload
      String classId = data['classId'] ?? '';
      if (classId.isEmpty) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(user.schoolId)
            .collection('students')
            .doc(studentId)
            .get();
        if (studentDoc.exists) {
          classId = studentDoc.data()?['classId'] ?? '';
        }
      }

      final isLate = await _repo.scanAttendance(
        schoolId: user.schoolId,
        studentId: studentId,
        studentName: studentName,
        classId: classId,
        className: className,
        officerId: user.uid,
      );

      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      _showSuccessToast(_ToastData(
        isLate: isLate,
        studentName: studentName,
        className: className,
        time: timeStr,
      ));
    } catch (e) {
      _showErrorDialog(
        'Gagal Membaca QR',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Live camera feed
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  _handleScanResult(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Layer 2: Overlay + viewfinder (saveLayer fix)
          CustomPaint(
            painter: _ViewfinderPainter(isProcessing: _isProcessing),
          ),

          // Layer 3: UI controls
          SafeArea(
            child: Column(
              children: [
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      const Text(
                        'Scan QR Kehadiran',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
                        onPressed: () => _scannerController.toggleTorch(),
                        tooltip: 'Nyalakan lampu',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.white70, size: 16),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Arahkan ke QR Code siswa.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                const SizedBox(height: _ViewfinderPainter.viewfinderSize + 8),
                const Spacer(flex: 2),

                // Status bar
                if (_isProcessing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: CircularProgressIndicator(
                      color: Colors.amber,
                      strokeWidth: 3,
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isProcessing ? Colors.amber : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isProcessing ? 'Memproses...' : 'Siap Scan',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Layer 4: Success toast (slide-up dari bawah)
          if (_toastData != null && _toastSlide != null && _toastFade != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 100,
              child: SlideTransition(
                position: _toastSlide!,
                child: FadeTransition(
                  opacity: _toastFade!,
                  child: _SuccessToast(data: _toastData!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Toast data model ─────────────────────────────────────────────────────────

class _ToastData {
  final bool isLate;
  final String studentName;
  final String className;
  final String time;

  const _ToastData({
    required this.isLate,
    required this.studentName,
    required this.className,
    required this.time,
  });
}

// ─── Success Toast Widget ─────────────────────────────────────────────────────

class _SuccessToast extends StatelessWidget {
  final _ToastData data;

  const _SuccessToast({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = data.isLate ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final icon = data.isLate ? Icons.schedule_rounded : Icons.check_circle_rounded;
    final label = data.isLate ? 'Terlambat' : 'Hadir';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon bulat
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),

          // Info teks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      data.time,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  data.studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelas ${data.className}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Ikon centang kecil di kanan
          Icon(Icons.done_all_rounded, color: color, size: 20),
        ],
      ),
    );
  }
}

// ─── Viewfinder Painter ────────────────────────────────────────────────────────

class _ViewfinderPainter extends CustomPainter {
  final bool isProcessing;

  static const double viewfinderSize = 260.0;
  static const double cornerSize = 28.0;
  static const double cornerWidth = 4.0;
  static const double borderRadius = 20.0;
  static const double cornerRadius = 8.0;

  const _ViewfinderPainter({required this.isProcessing});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: viewfinderSize,
      height: viewfinderSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(borderRadius));

    // 1. Overlay gelap + lubang transparan (saveLayer agar BlendMode.clear benar)
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.60),
    );
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // 2. Border
    final borderColor = isProcessing ? Colors.amber : const Color(0xFF10B981);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // 3. Corner decorations
    _drawCorners(canvas, rect, borderColor);
  }

  void _drawCorners(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round;

    final l = rect.left;
    final t = rect.top;
    final r = rect.right;
    final b = rect.bottom;
    const cr = cornerRadius;
    const cs = cornerSize;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(l, t + cs)
        ..lineTo(l, t + cr)
        ..arcToPoint(Offset(l + cr, t), radius: const Radius.circular(cr), clockwise: true)
        ..lineTo(l + cs, t),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(r - cs, t)
        ..lineTo(r - cr, t)
        ..arcToPoint(Offset(r, t + cr), radius: const Radius.circular(cr), clockwise: false)
        ..lineTo(r, t + cs),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(l, b - cs)
        ..lineTo(l, b - cr)
        ..arcToPoint(Offset(l + cr, b), radius: const Radius.circular(cr), clockwise: false)
        ..lineTo(l + cs, b),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(r - cs, b)
        ..lineTo(r - cr, b)
        ..arcToPoint(Offset(r, b - cr), radius: const Radius.circular(cr), clockwise: true)
        ..lineTo(r, b - cs),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.isProcessing != isProcessing;
}
