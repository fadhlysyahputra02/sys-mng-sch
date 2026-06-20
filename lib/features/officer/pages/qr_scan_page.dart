import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/services/session_service.dart';
import '../data/officer_repository.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> with WidgetsBindingObserver {
  final OfficerRepository _repo = OfficerRepository();
  late final MobileScannerController _scannerController;
  bool _isProcessing = false;

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
    super.dispose();
  }

  void _showResultDialog(bool isSuccess, String title, String message) {
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
                  color: isSuccess
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
                    setState(() => _isProcessing = false);
                    _scannerController.start();
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

  Future<void> _handleScanResult(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      final data = jsonDecode(code) as Map<String, dynamic>;
      final user = SessionService.currentUser!;

      final String studentId = data['studentId'] ?? '';
      final String studentName = data['nama'] ?? '';
      final String schoolId = data['schoolId'] ?? '';
      final String className = data['className'] ?? '';

      if (studentId.isEmpty) {
        _showResultDialog(false, 'QR Tidak Valid', 'Format QR Code tidak dikenali. Pastikan siswa menggunakan kartu QR dari aplikasi ini.');
        return;
      }

      if (schoolId != user.schoolId) {
        _showResultDialog(false, 'Sekolah Berbeda', 'QR Code ini berasal dari sekolah lain dan tidak dapat diproses.');
        return;
      }

      final hasScanned = await _repo.hasStudentScannedToday(user.schoolId, studentId);
      if (hasScanned) {
        _showResultDialog(false, 'Sudah Tercatat', '$studentName sudah melakukan scan kehadiran hari ini.');
        return;
      }

      await _repo.scanAttendance(
        schoolId: user.schoolId,
        studentId: studentId,
        studentName: studentName,
        classId: data['classId'] ?? '',
        className: className,
        officerId: user.uid,
      );

      // Tentukan pesan berdasarkan waktu
      final now = DateTime.now();
      final isLate = now.hour > 7 || (now.hour == 7 && now.minute > 15);
      final statusText = isLate ? '⏰ Terlambat' : '✅ Hadir';

      _showResultDialog(
        true,
        '$statusText Tercatat',
        '$studentName\nKelas: $className\nWaktu: ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      );
    } catch (e) {
      _showResultDialog(
        false,
        'Gagal Membaca QR',
        e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Live Camera feed — selalu di paling bawah
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleScanResult(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Layer 2: Dark overlay dengan lubang di tengah (efek viewfinder)
          CustomPaint(
            painter: _ViewfinderOverlayPainter(),
          ),

          // Layer 3: UI controls (AppBar + info + viewfinder frame)
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
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
                      // Toggle Flashlight
                      IconButton(
                        icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
                        onPressed: () => _scannerController.toggleTorch(),
                        tooltip: 'Nyalakan lampu',
                      ),
                    ],
                  ),
                ),

                // Info di atas viewfinder
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
                          'Arahkan ke QR Code siswa. Otomatis Terlambat jika > 07:15',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Viewfinder frame box
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isProcessing
                          ? Colors.amber
                          : const Color(0xFF10B981),
                      width: 3,
                    ),
                  ),
                  child: _isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.amber,
                            strokeWidth: 3,
                          ),
                        )
                      : Stack(
                          children: [
                            // Corner decorations
                            ..._buildCorners(),
                          ],
                        ),
                ),

                const Spacer(flex: 2),

                // Status bar
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
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 24.0;
    const width = 3.5;
    const color = Color(0xFF10B981);
    const radius = 8.0;

    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: width),
              left: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(radius)),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: width),
              right: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(topRight: Radius.circular(radius)),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: width),
              left: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(radius)),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: width),
              right: BorderSide(color: color, width: width),
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(radius)),
          ),
        ),
      ),
    ];
  }
}

/// Custom painter untuk efek semi-transparan di luar area scan
class _ViewfinderOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    const viewfinderSize = 260.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: viewfinderSize,
      height: viewfinderSize,
    );

    // Gambar overlay gelap di seluruh layar
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Hapus area viewfinder (buat transparan)
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      Paint()..blendMode = BlendMode.clear,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
