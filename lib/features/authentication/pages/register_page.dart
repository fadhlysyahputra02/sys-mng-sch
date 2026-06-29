import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../schools/services/school_service.dart';
import '../widgets/auth_background.dart';
import '../widgets/theme_toggle_button.dart';
import 'parent_register_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String selectedRole = 'school_admin';

  // Controllers school_admin
  final kodeController = TextEditingController();
  final namaController = TextEditingController();

  // Controllers guru & murid
  final nipNisController = TextEditingController();

  // Controllers bersama
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final authService = AuthService();
  final userService = UserService();
  final schoolService = SchoolService();

  // State dropdown sekolah
  List<Map<String, dynamic>> _sekolahList = [];
  Map<String, dynamic>? _selectedSekolah;
  bool _loadingSekolah = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _schoolLogoBase64;

  @override
  void initState() {
    super.initState();
    _loadSekolah();
  }

  Future<void> _loadSekolah() async {
    setState(() => _loadingSekolah = true);
    try {
      final list = await schoolService.getAllSchools();
      setState(() => _sekolahList = list);
    } catch (e) {
      debugPrint('Failed to load schools: $e');
    } finally {
      setState(() => _loadingSekolah = false);
    }
  }

  Future<void> _loadSelectedSchoolLogo(String schoolId) async {
    try {
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();
      if (schoolDoc.exists && mounted) {
        setState(() {
          _schoolLogoBase64 = schoolDoc.data()?['logoBase64'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading school logo: $e');
    }
  }

  @override
  void dispose() {
    kodeController.dispose();
    namaController.dispose();
    nipNisController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String get _nipNisLabel {
    if (selectedRole == 'teacher') return 'NIP';
    if (selectedRole == 'student') return 'NIS';
    return '';
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
        isSuccess ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
        color: Colors.white,
        size: 28,
      ),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      backgroundColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
      barBlur: 8,
      boxShadows: [
        BoxShadow(
          color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  void _showError(String message) {
    _showNotification(
      title: 'Registrasi Gagal',
      message: message,
      isSuccess: false,
    );
  }

  void _showSchoolSearchBottomSheet() {
    String searchQuery = "";
    List<Map<String, dynamic>> filteredSekolah = List.from(_sekolahList);
    final isDark = AuthBackground.isDarkMode.value;

    final sheetBgColor = isDark ? const Color(0xFF151026) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final closeIconColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.6);
    final inputStyleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final hintTextColor = isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF1E1B4B).withOpacity(0.4);
    final searchIconColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.5);
    final enabledBorderColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15);
    final fieldFillColor = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
    final notFoundIconColor = isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF1E1B4B).withOpacity(0.3);
    final notFoundTextColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1E1B4B).withOpacity(0.5);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PILIH SEKOLAH',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: closeIconColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Field
                  TextField(
                    style: TextStyle(color: inputStyleColor),
                    decoration: InputDecoration(
                      hintText: 'Cari nama sekolah...',
                      hintStyle: TextStyle(color: hintTextColor),
                      prefixIcon: Icon(Icons.search_rounded, color: searchIconColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: enabledBorderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                      ),
                      filled: true,
                      fillColor: fieldFillColor,
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val.trim().toLowerCase();
                        filteredSekolah = _sekolahList.where((school) {
                          final name = (school['namaSekolah'] ?? '').toString().toLowerCase();
                          return name.contains(searchQuery);
                        }).toList();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // List of schools
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: filteredSekolah.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 48, color: notFoundIconColor),
                                const SizedBox(height: 12),
                                Text(
                                  'Sekolah tidak ditemukan',
                                  style: TextStyle(color: notFoundTextColor),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredSekolah.length,
                            itemBuilder: (context, index) {
                              final school = filteredSekolah[index];
                              final isSelected = _selectedSekolah != null &&
                                  _selectedSekolah!['schoolId'] == school['schoolId'];
                              
                              final itemBg = isSelected
                                  ? const Color(0xFF6366F1).withOpacity(0.15)
                                  : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01));
                              final itemBorder = isSelected
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08));
                              final itemTitleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
                              final itemSubtitleColor = isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF1E1B4B).withOpacity(0.5);
                              final trailingIconColor = isSelected
                                  ? const Color(0xFF10B981)
                                  : (isDark ? Colors.white54 : Colors.black26);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: itemBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: itemBorder,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    school['namaSekolah'] ?? '',
                                    style: TextStyle(
                                      color: itemTitleColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: school['domain'] != null
                                      ? Text(
                                          'ID: ${school['domain']}',
                                          style: TextStyle(
                                            color: itemSubtitleColor,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF10B981))
                                      : Icon(Icons.chevron_right_rounded,
                                          color: trailingIconColor),
                                  onTap: () {
                                    setState(() {
                                      _selectedSekolah = school;
                                    });
                                    final schoolId = school['schoolId'] as String?;
                                    if (schoolId != null) {
                                      _loadSelectedSchoolLogo(schoolId);
                                    }
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onRegister() async {
    if (selectedRole == 'parent') {
      Get.to(() => const ParentRegisterPage());
      return;
    }

    if (kIsWeb && selectedRole != 'school_admin') {
      _showError('Akses pendaftaran website hanya diizinkan untuk Admin Sekolah.');
      return;
    }

    // Validasi form dasar
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      _showError('Email dan password wajib diisi.');
      return;
    }

    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    if (password != confirmPassword) {
      _showError('Password tidak cocok.');
      return;
    }

    // ── KODE RAHASIA SUPER ADMIN ──
    if (selectedRole == 'school_admin' && kodeController.text.trim() == '081987') {
      if (namaController.text.trim().isEmpty) {
        _showError('Nama lengkap wajib diisi.');
        return;
      }
      setState(() => _isLoading = true);
      try {
        await _registerSuperAdmin();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (_selectedSekolah == null) {
      _showError('Silakan pilih sekolah Anda.');
      return;
    }

    if (selectedRole == 'school_admin') {
      if (namaController.text.trim().isEmpty) {
        _showError('Nama lengkap wajib diisi.');
        return;
      }
      if (kodeController.text.trim().isEmpty) {
        _showError('Kode registrasi wajib diisi.');
        return;
      }
    } else {
      if (nipNisController.text.trim().isEmpty) {
        _showError('$_nipNisLabel wajib diisi.');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      if (selectedRole == 'school_admin') {
        await _registerAdmin();
      } else if (selectedRole == 'teacher') {
        await _registerGuru();
      } else if (selectedRole == 'student') {
        await _registerMurid();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Register Super Admin (Rahasia) ──
  Future<void> _registerSuperAdmin() async {
    try {
      final credential = await authService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userService.createUser(
        uid: credential.user!.uid,
        email: emailController.text.trim(),
        nama: namaController.text.trim(),
        role: 'super_admin', // Identitas khusus agar tidak error jika dicek null
        schoolId: 'SYS_ADMIN',
        password: passwordController.text.trim(),
      );

      if (mounted) {
        _showNotification(
          title: 'Akses Rahasia Berhasil',
          message: 'Akun Super Admin berhasil dibuat!',
          isSuccess: true,
        );
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Register Admin Sekolah ──
  Future<void> _registerAdmin() async {
    try {
      final school = _selectedSekolah!;

      if (school['kodeAdmin'] != kodeController.text.trim()) {
        throw ('Kode administrator tidak valid');
      }

      final credential = await authService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userService.createUser(
        uid: credential.user!.uid,
        email: emailController.text.trim(),
        nama: namaController.text.trim(),
        role: 'school_admin',
        schoolId: school['schoolId'],
        password: passwordController.text.trim(),
      );

      if (mounted) {
        _showNotification(
          title: 'Registrasi Berhasil',
          message: 'Pendaftaran admin sekolah berhasil!',
          isSuccess: true,
        );
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Register Guru ──
  Future<void> _registerGuru() async {
    try {
      final nip = nipNisController.text.trim();
      final schoolId = _selectedSekolah!['schoolId'] as String;

      // Cari data guru
      final teacher = await schoolService.getTeacherByNip(
        schoolId: schoolId,
        nip: nip,
      );

      if (teacher == null) {
        throw ('NIP tidak ditemukan di sekolah yang dipilih');
      }

      if (teacher['aktif'] != true) {
        throw ('Akun guru dinonaktifkan oleh sekolah');
      }

      if (teacher['sudahRegister'] == true) {
        throw ('NIP Guru sudah terdaftar');
      }

      final credential = await authService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      await userService.createUser(
        uid: uid,
        email: emailController.text.trim(),
        nama: teacher['nama'],
        role: 'teacher',
        schoolId: schoolId,
        password: passwordController.text.trim(),
      );

      // Update data guru
      await schoolService.updateTeacherRegistration(
        schoolId: schoolId,
        teacherId: teacher['teacherId'],
        nama: teacher['nama'],
        uid: uid,
        email: emailController.text.trim(),
      );

      if (mounted) {
        _showNotification(
          title: 'Registrasi Berhasil',
          message: 'Registrasi guru atas nama ${teacher['nama']} berhasil!',
          isSuccess: true,
        );
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Register Murid ──
  Future<void> _registerMurid() async {
    try {
      final nis = nipNisController.text.trim();
      final schoolId = _selectedSekolah!['schoolId'] as String;

      // Cari data murid
      final student = await schoolService.getStudentByNis(
        schoolId: schoolId,
        nis: nis,
      );

      if (student == null) {
        throw ('NIS tidak ditemukan di sekolah yang dipilih');
      }

      if (student['aktif'] != true) {
        throw ('Akun murid dinonaktifkan oleh sekolah');
      }

      if (student['sudahRegister'] == true) {
        throw ('NIS Murid sudah terdaftar');
      }

      final credential = await authService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      await userService.createUser(
        uid: uid,
        email: emailController.text.trim(),
        nama: student['nama'],
        role: 'student',
        schoolId: schoolId,
        password: passwordController.text.trim(),
      );

      // Update data murid
      await schoolService.updateStudentRegistration(
        schoolId: schoolId,
        studentId: student['studentId'],
        nama: student['nama'],
        uid: uid,
        email: emailController.text.trim(),
      );

      if (mounted) {
        _showNotification(
          title: 'Registrasi Berhasil',
          message: 'Registrasi murid atas nama ${student['nama']} berhasil!',
          isSuccess: true,
        );
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final isDark = AuthBackground.isDarkMode.value;
    final isSelected = selectedRole == value;
    
    final unselectedBg = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02);
    final unselectedBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withOpacity(0.08);
    final unselectedTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withOpacity(0.6);
    
    final selectedTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedRole = value;
            _selectedSekolah = null;
            _schoolLogoBase64 = null;
            nipNisController.clear();
            namaController.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : unselectedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : unselectedBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF6366F1) : unselectedTextColor,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1E1B4B).withOpacity(0.6);
        final cardColor = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06);
        final fieldFillColor = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01);
        final fieldBorderColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12);
        final labelColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF1E1B4B).withOpacity(0.6);
        final shadowColor = isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: const [
              ThemeToggleButton(),
            ],
          ),
          body: AuthBackground(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Icon - dynamic with school logo
                    _schoolLogoBase64 != null && _schoolLogoBase64!.isNotEmpty
                        ? Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.memory(
                                base64Decode(_schoolLogoBase64!),
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                                errorBuilder: (_, __, ___) => Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.app_registration_rounded, size: 44, color: textColor),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.app_registration_rounded,
                              size: 44,
                              color: textColor,
                            ),
                          ),

                    const SizedBox(height: 16),

                    Text(
                      'REGISTRASI',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 2.0,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Daftarkan akun Anda untuk mengakses sistem',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Glassmorphic Card Form
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: cardBorderColor,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          children: [
                            // Latar belakang motif geometris modern
                            if (!isDark)
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.10, // Dipertipis
                                  child: Image.asset(
                                    'assets/images/motif_mandala.png',
                                    fit: BoxFit.cover,
                                    repeat: ImageRepeat.repeat,
                                  ),
                                ),
                              ),
                            // Konten Form
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Pilihan Role Kustom
                          if (!kIsWeb) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                                  child: Text(
                                    'Daftar Sebagai',
                                    style: TextStyle(
                                      color: labelColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildRoleCard(
                                      title: 'Admin',
                                      icon: Icons.admin_panel_settings_rounded,
                                      value: 'school_admin',
                                    ),
                                    const SizedBox(width: 12),
                                    _buildRoleCard(
                                      title: 'Guru',
                                      icon: Icons.school_rounded,
                                      value: 'teacher',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildRoleCard(
                                      title: 'Murid',
                                      icon: Icons.face_rounded,
                                      value: 'student',
                                    ),
                                    const SizedBox(width: 12),
                                    _buildRoleCard(
                                      title: 'Orang Tua',
                                      icon: Icons.family_restroom_rounded,
                                      value: 'parent',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],

                          // Pilihan Sekolah (InkWell Selector dengan BottomSheet Pencarian)
                          if (selectedRole != 'parent')
                            _loadingSekolah
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                )
                              : InkWell(
                                  onTap: _showSchoolSearchBottomSheet,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Pilih Sekolah',
                                      labelStyle: TextStyle(color: labelColor),
                                      prefixIcon: Icon(
                                        Icons.account_balance_rounded,
                                        color: labelColor,
                                      ),
                                      suffixIcon: Icon(
                                        Icons.arrow_drop_down_rounded,
                                        color: labelColor,
                                        size: 28,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: fieldBorderColor,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF6366F1),
                                          width: 1.5,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: fieldFillColor,
                                    ),
                                    child: Text(
                                      _selectedSekolah != null
                                          ? (_selectedSekolah!['namaSekolah'] ?? '')
                                          : 'Pilih nama sekolah',
                                      style: TextStyle(
                                        color: _selectedSekolah != null
                                            ? textColor
                                            : labelColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),

                          if (selectedRole != 'parent') const SizedBox(height: 18),

                          if (selectedRole == 'parent') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Daftar sebagai orang tua memerlukan scan QR dari akun anak. Tap tombol di bawah untuk melanjutkan.',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // ── Fields Khusus Admin Sekolah ──
                          if (selectedRole == 'school_admin') ...[
                            // Nama Lengkap Admin
                            TextField(
                              controller: namaController,
                              style: TextStyle(color: textColor),
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Nama Lengkap',
                                labelStyle: TextStyle(color: labelColor),
                                prefixIcon: Icon(
                                  Icons.person_pin_rounded,
                                  color: labelColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: fieldBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: fieldFillColor,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Kode Registrasi
                            TextField(
                              controller: kodeController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: 'Kode Registrasi',
                                labelStyle: TextStyle(color: labelColor),
                                prefixIcon: Icon(
                                  Icons.key_rounded,
                                  color: labelColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: fieldBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: fieldFillColor,
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // ── Fields Khusus Guru & Murid ──
                          if (selectedRole == 'teacher' || selectedRole == 'student') ...[
                            // Field NIP / NIS
                            TextField(
                              controller: nipNisController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: _nipNisLabel,
                                hintText: selectedRole == 'teacher'
                                    ? 'Masukkan NIP Anda'
                                    : 'Masukkan NIS Anda',
                                hintStyle: TextStyle(color: isDark ? Colors.white.withOpacity(0.3) : const Color(0xFF1E1B4B).withOpacity(0.3), fontSize: 14),
                                labelStyle: TextStyle(color: labelColor),
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  color: labelColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: fieldBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6366F1),
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: fieldFillColor,
                              ),
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 18),
                          ],

                          // ── Email & Password (Semua Role kecuali Orang Tua) ──
                          if (selectedRole != 'parent') ...[
                          TextField(
                            controller: emailController,
                            style: TextStyle(color: textColor),
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: labelColor),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: labelColor,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: fieldBorderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF6366F1),
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: fieldFillColor,
                            ),
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: labelColor),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: labelColor,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: labelColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: fieldBorderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF6366F1),
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: fieldFillColor,
                            ),
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Konfirmasi Password',
                              labelStyle: TextStyle(color: labelColor),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: labelColor,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: labelColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: fieldBorderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF6366F1),
                                  width: 1.5,
                                ),
                              ),
                              filled: true,
                              fillColor: fieldFillColor,
                            ),
                          ),

                          const SizedBox(height: 32),
                          ],

                          if (selectedRole == 'parent') const SizedBox(height: 32),

                          // Tombol Register
                          Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8B5CF6), // Purple
                                  Color(0xFFD946EF), // Pink
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.35 : 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _onRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      selectedRole == 'parent'
                                          ? 'LANJUT DAFTAR ORANG TUA'
                                          : 'DAFTAR',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Tombol Kembali Ke Login
                          OutlinedButton(
                            onPressed: () {
                              Get.toNamed(AppRoutes.login);
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFF1E1B4B).withOpacity(0.2)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'KEMBALI KE LOGIN',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
