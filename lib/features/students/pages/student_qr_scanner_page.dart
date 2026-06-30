import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Halaman scanner QR kamera penuh.
/// Mengembalikan payload String (isi QR) saat berhasil scan,
/// atau null jika pengguna menutup halaman.
class StudentQrScannerPage extends StatefulWidget {
  final String title;
  final String subtitle;

  const StudentQrScannerPage({
    super.key,
    this.title = 'Scan QR Absensi',
    this.subtitle = 'Arahkan kamera ke QR yang ditampilkan guru',
  });

  @override
  State<StudentQrScannerPage> createState() => _StudentQrScannerPageState();
}

class _StudentQrScannerPageState extends State<StudentQrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
  );

  bool _hasScanned = false;
  bool _isTorchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _hasScanned = true;
        _controller.stop();
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            tooltip: 'Tukar Kamera',
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: _isTorchOn ? const Color(0xFFF59E0B) : Colors.white54,
            ),
            tooltip: 'Flash',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Kamera Tidak Tersedia',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pastikan Anda telah memberikan izin akses kamera pada browser/perangkat Anda, dan kamera tidak sedang digunakan oleh aplikasi lain (seperti Zoom/Meet).',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Overlay dimming + scan frame
          _buildScanOverlay(context),

          // Instruction text at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Colors.white54, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'QR akan terdeteksi secara otomatis',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    const frameSize = 240.0;
    const cornerLength = 28.0;
    const cornerWidth = 4.0;
    const cornerRadius = 6.0;
    const cornerColor = Color(0xFF8B5CF6);

    return CustomPaint(
      painter: _OverlayPainter(frameSize: frameSize),
      child: Align(
        alignment: const Alignment(0, -0.15),
        child: SizedBox(
          width: frameSize,
          height: frameSize,
          child: Stack(
            children: [
              // Top-left corner
              Positioned(
                top: 0,
                left: 0,
                child: _Corner(
                  length: cornerLength,
                  width: cornerWidth,
                  radius: cornerRadius,
                  color: cornerColor,
                  topLeft: true,
                ),
              ),
              // Top-right corner
              Positioned(
                top: 0,
                right: 0,
                child: _Corner(
                  length: cornerLength,
                  width: cornerWidth,
                  radius: cornerRadius,
                  color: cornerColor,
                  topRight: true,
                ),
              ),
              // Bottom-left corner
              Positioned(
                bottom: 0,
                left: 0,
                child: _Corner(
                  length: cornerLength,
                  width: cornerWidth,
                  radius: cornerRadius,
                  color: cornerColor,
                  bottomLeft: true,
                ),
              ),
              // Bottom-right corner
              Positioned(
                bottom: 0,
                right: 0,
                child: _Corner(
                  length: cornerLength,
                  width: cornerWidth,
                  radius: cornerRadius,
                  color: cornerColor,
                  bottomRight: true,
                ),
              ),
              // Animated scan laser
              const _ScanLaser(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter to dim everything outside the scan frame.
class _OverlayPainter extends CustomPainter {
  final double frameSize;
  const _OverlayPainter({required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);

    // Center frame rect (aligned -0.15 vertically with Align layout)
    final cx = size.width / 2;
    final cy = size.height / 2 + (-0.15) * (size.height - frameSize) / 2;
    final half = frameSize / 2;

    final frameRect = Rect.fromLTWH(cx - half, cy - half, frameSize, frameSize);

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Sudut (corner bracket) dekoratif di sekitar scan frame.
class _Corner extends StatelessWidget {
  final double length;
  final double width;
  final double radius;
  final Color color;
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  const _Corner({
    required this.length,
    required this.width,
    required this.radius,
    required this.color,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(
        painter: _CornerPainter(
          color: color,
          strokeWidth: width,
          radius: radius,
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final bool topLeft, topRight, bottomLeft, bottomRight;

  _CornerPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final path = Path();

    if (topLeft) {
      path.moveTo(0, h);
      path.lineTo(0, radius);
      path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
      path.lineTo(w, 0);
    }
    if (topRight) {
      path.moveTo(0, 0);
      path.lineTo(w - radius, 0);
      path.arcToPoint(Offset(w, radius), radius: Radius.circular(radius));
      path.lineTo(w, h);
    }
    if (bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, h - radius);
      path.arcToPoint(Offset(radius, h), radius: Radius.circular(radius));
      path.lineTo(w, h);
    }
    if (bottomRight) {
      path.moveTo(0, h);
      path.lineTo(w - radius, h);
      path.arcToPoint(Offset(w, h - radius), radius: Radius.circular(radius));
      path.lineTo(w, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Laser scan animasi dalam frame.
class _ScanLaser extends StatefulWidget {
  const _ScanLaser();

  @override
  State<_ScanLaser> createState() => _ScanLaserState();
}

class _ScanLaserState extends State<_ScanLaser> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Align(
        alignment: Alignment(0, (_anim.value * 2) - 1),
        child: Container(
          height: 2.5,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.transparent, Color(0xFFD946EF), Color(0xFF8B5CF6), Color(0xFFD946EF), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD946EF).withValues(alpha: 0.7),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
