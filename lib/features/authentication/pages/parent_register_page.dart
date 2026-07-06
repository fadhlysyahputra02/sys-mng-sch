import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_listener_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/user_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../authentication/widgets/theme_toggle_button.dart';
import '../../parent_link/services/link_service.dart';

class ParentRegisterPage extends StatefulWidget {
  const ParentRegisterPage({super.key});

  @override
  State<ParentRegisterPage> createState() => _ParentRegisterPageState();
}

class _ParentRegisterPageState extends State<ParentRegisterPage> {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _authService = AuthService();
  final _userService = UserService();
  final _linkService = LinkService();

  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _showScanner = false;
  bool _hasScanned = false;
  String? _parentUid;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['showScanner'] == true) {
      _showScanner = true;
      _parentUid = SessionService.currentUser?.uid;
      _namaController.text = SessionService.currentUser?.nama ?? '';
      _emailController.text = SessionService.currentUser?.email ?? '';
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _showNotification({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    Get.rawSnackbar(
      titleText: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      icon: Icon(
        isSuccess
            ? Icons.check_circle_outline_rounded
            : Icons.warning_amber_rounded,
        color: Colors.white,
        size: 28,
      ),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      backgroundColor:
          isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
    );
  }

  Future<void> _registerAccount() async {
    final nama = _namaController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (nama.isEmpty || email.isEmpty || password.isEmpty) {
      _showNotification(
        title: 'Form Belum Lengkap',
        message: 'Nama, email, dan password wajib diisi.',
        isSuccess: false,
      );
      return;
    }

    if (password != confirm) {
      _showNotification(
        title: 'Password Tidak Cocok',
        message: 'Konfirmasi password harus sama.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.register(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      await _userService.createUser(
        uid: uid,
        email: email,
        nama: nama,
        role: 'parent',
        schoolId: '',
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _parentUid = uid;
        _showScanner = true;
        _isLoading = false;
      });

      _showNotification(
        title: 'Akun Dibuat',
        message: 'Sekarang scan QR Code dari anak Anda.',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showNotification(
        title: 'Registrasi Gagal',
        message: e.toString().replaceAll('Exception: ', ''),
        isSuccess: false,
      );
    }
  }

  Future<void> _onQrDetected(String raw) async {
    if (_hasScanned || _parentUid == null) return;
    _hasScanned = true;
    await _scannerController.stop();

    setState(() => _isLoading = true);

    try {
      await _linkService.linkParentToStudent(
        parentUid: _parentUid!,
        parentName: _namaController.text.trim(),
        parentEmail: _emailController.text.trim(),
        qrRaw: raw,
      );

      final userData = await _userService.getUserById(_parentUid!);
      if (userData == null) throw ('Data user tidak ditemukan.');

      SessionService.currentUser = UserModel.fromMap(_parentUid!, userData);
      NotificationListenerService().startListening();
      PushNotificationService().registerUserDevice();

      if (!mounted) return;

      _showNotification(
        title: 'Berhasil Terhubung',
        message: 'Akun orang tua berhasil dihubungkan ke anak.',
        isSuccess: true,
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Get.offAllNamed(AppRoutes.parent);
    } catch (e) {
      _hasScanned = false;
      await _scannerController.start();
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showNotification(
        title: 'Gagal Menghubungkan',
        message: e.toString().replaceAll('Exception: ', ''),
        isSuccess: false,
      );
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _onQrDetected(raw);
        return;
      }
    }
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
        final cardColor =
            isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
        final cardBorder =
            isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
        final fieldFill =
            isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01);
        final fieldBorder =
            isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12);
        final labelColor = isDark
            ? Colors.white.withValues(alpha: 0.6)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

        final hasUppercase = RegExp(r'[A-Z]').hasMatch(_passwordController.text);
        final hasLowercase = RegExp(r'[a-z]').hasMatch(_passwordController.text);
        final hasNumber = RegExp(r'[0-9]').hasMatch(_passwordController.text);
        final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(_passwordController.text);
        final isPasswordValid = hasUppercase && hasLowercase && hasNumber && hasSpecialChar;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 18),
              onPressed: () async {
                final args = Get.arguments as Map<String, dynamic>?;
                if (args != null && args['showScanner'] == true) {
                  await FirebaseAuth.instance.signOut();
                  SessionService.currentUser = null;
                  Get.offAllNamed(AppRoutes.login);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            actions: const [ThemeToggleButton()],
          ),
          body: AuthBackground(
            child: SizedBox.expand(
              child: _showScanner
                  ? _buildScannerView(textColor, subTextColor)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.03),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: Icon(
                                    Icons.family_restroom_rounded,
                                    size: 44,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'DAFTAR ORANG TUA',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Buat akun lalu scan QR dari anak Anda',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: subTextColor,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 28,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildField(
                                        controller: _namaController,
                                        label: 'Nama Lengkap',
                                        icon: Icons.person_rounded,
                                        textColor: textColor,
                                        labelColor: labelColor,
                                        fieldFill: fieldFill,
                                        fieldBorder: fieldBorder,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildField(
                                        controller: _emailController,
                                        label: 'Email',
                                        icon: Icons.email_rounded,
                                        textColor: textColor,
                                        labelColor: labelColor,
                                        fieldFill: fieldFill,
                                        fieldBorder: fieldBorder,
                                        keyboard: TextInputType.emailAddress,
                                      ),
                                      const SizedBox(height: 16),
                                      _buildField(
                                        controller: _passwordController,
                                        label: 'Password',
                                        icon: Icons.lock_rounded,
                                        textColor: textColor,
                                        labelColor: labelColor,
                                        fieldFill: fieldFill,
                                        fieldBorder: fieldBorder,
                                        obscure: _obscurePassword,
                                        onChanged: (val) => setState(() {}),
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: labelColor,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      _buildPasswordRequirements(_passwordController.text, isDark),
                                      const SizedBox(height: 16),
                                      _buildField(
                                        controller: _confirmController,
                                        label: 'Konfirmasi Password',
                                        icon: Icons.lock_outline_rounded,
                                        textColor: textColor,
                                        labelColor: labelColor,
                                        fieldFill: fieldFill,
                                        fieldBorder: fieldBorder,
                                        obscure: _obscureConfirm,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscureConfirm
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: labelColor,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscureConfirm =
                                                !_obscureConfirm,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed:
                                              (_isLoading || !isPasswordValid) ? null : _registerAccount,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF8B5CF6),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text(
                                                  'BUAT AKUN & LANJUT SCAN QR',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScannerView(Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              Text(
                'Scan QR Anak',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Buka menu "Sambungkan ke Orang Tua" di akun anak, lalu arahkan kamera ke QR.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: subTextColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'QR terdeteksi otomatis',
                style: TextStyle(color: subTextColor, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements(String password, bool isDark) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

    final activeColor = const Color(0xFF10B981);
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    Widget buildItem(String label, bool isMet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: isMet ? activeColor : inactiveColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isMet ? activeColor : textColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 6, right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildItem('Memiliki huruf besar (A-Z)', hasUppercase),
          buildItem('Memiliki huruf kecil (a-z)', hasLowercase),
          buildItem('Memiliki angka (0-9)', hasNumber),
          buildItem('Memiliki karakter khusus (!@#\$%^&* dll)', hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
    required Color labelColor,
    required Color fieldFill,
    required Color fieldBorder,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: textColor),
      keyboardType: keyboard,
      obscureText: obscure,
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor),
        prefixIcon: Icon(icon, color: labelColor),
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
        filled: true,
        fillColor: fieldFill,
      ),
    );
  }
}
