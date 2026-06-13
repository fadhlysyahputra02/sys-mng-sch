import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../schools/services/school_service.dart';
import '../widgets/auth_background.dart';

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

  final authService = AuthService();
  final userService = UserService();
  final schoolService = SchoolService();

  // State dropdown sekolah
  List<Map<String, dynamic>> _sekolahList = [];
  Map<String, dynamic>? _selectedSekolah;
  bool _loadingSekolah = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

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
      debugPrint('Gagal load sekolah: $e');
    } finally {
      setState(() => _loadingSekolah = false);
    }
  }

  @override
  void dispose() {
    kodeController.dispose();
    namaController.dispose();
    nipNisController.dispose();
    emailController.dispose();
    passwordController.dispose();
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
      title: 'Pendaftaran Gagal',
      message: message,
      isSuccess: false,
    );
  }

  void _showSchoolSearchBottomSheet() {
    String searchQuery = "";
    List<Map<String, dynamic>> filteredSekolah = List.from(_sekolahList);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151026),
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
                      const Text(
                        'PILIH SEKOLAH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Field
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari nama sekolah...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.02),
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
                                    size: 48, color: Colors.white.withOpacity(0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  'Sekolah tidak ditemukan',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6366F1).withOpacity(0.15)
                                      : Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF6366F1)
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    school['namaSekolah'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: school['domain'] != null
                                      ? Text(
                                          'ID: ${school['domain']}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.4),
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF10B981))
                                      : const Icon(Icons.chevron_right_rounded,
                                          color: Colors.white54),
                                  onTap: () {
                                    setState(() {
                                      _selectedSekolah = school;
                                    });
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
    // Validasi form dasar
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      _showError('Email dan password wajib diisi.');
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
        _showError('Kode Registrasi wajib diisi.');
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
        throw Exception('Kode admin tidak valid');
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
      );

      if (mounted) {
        _showNotification(
          title: 'Registrasi Berhasil',
          message: 'Pendaftaran admin sekolah berhasil dilakukan!',
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
        throw Exception('NIP tidak ditemukan di sekolah terpilih');
      }

      if (teacher['aktif'] != true) {
        throw Exception('Akun Guru dinonaktifkan oleh sekolah');
      }

      if (teacher['sudahRegister'] == true) {
        throw Exception('NIP Guru sudah terdaftar sebelumnya');
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
          message: 'Registrasi Guru atas nama ${teacher['nama']} berhasil!',
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
        throw Exception('NIS tidak ditemukan di sekolah terpilih');
      }

      if (student['aktif'] != true) {
        throw Exception('Akun Murid dinonaktifkan oleh sekolah');
      }

      if (student['sudahRegister'] == true) {
        throw Exception('NIS Murid sudah terdaftar sebelumnya');
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
          message: 'Registrasi Murid atas nama ${student['nama']} berhasil!',
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
    final isSelected = selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedRole = value;
            _selectedSekolah = null;
            nipNisController.clear();
            namaController.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.5),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
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
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.app_registration_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'PENDAFTARAN',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Daftarkan akun Anda untuk mengakses sistem',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),

                const SizedBox(height: 28),

                // Glassmorphic Card Form
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Pilihan Role Kustom
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'Daftar Sebagai',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
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
                              const SizedBox(width: 12),
                              _buildRoleCard(
                                title: 'Murid',
                                icon: Icons.face_rounded,
                                value: 'student',
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Pilihan Sekolah (InkWell Selector dengan BottomSheet Pencarian)
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
                                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                  prefixIcon: Icon(
                                    Icons.account_balance_rounded,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  suffixIcon: Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: Colors.white.withOpacity(0.6),
                                    size: 28,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.15),
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
                                  fillColor: Colors.white.withOpacity(0.02),
                                ),
                                child: Text(
                                  _selectedSekolah != null
                                      ? (_selectedSekolah!['namaSekolah'] ?? '')
                                      : 'Pilih nama sekolah',
                                  style: TextStyle(
                                    color: _selectedSekolah != null
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.6),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 18),

                      // ── Fields Khusus Admin Sekolah ──
                      if (selectedRole == 'school_admin') ...[
                        // Nama Lengkap Admin
                        TextField(
                          controller: namaController,
                          style: const TextStyle(color: Colors.white),
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                            prefixIcon: Icon(
                              Icons.person_pin_rounded,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.15),
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
                            fillColor: Colors.white.withOpacity(0.02),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Kode Registrasi
                        TextField(
                          controller: kodeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Kode Registrasi',
                            labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                            prefixIcon: Icon(
                              Icons.key_rounded,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.15),
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
                          fillColor: Colors.white.withOpacity(0.02),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // ── Fields Khusus Guru & Murid ──
                    if (selectedRole == 'teacher' || selectedRole == 'student') ...[


                      // Field NIP / NIS
                      TextField(
                        controller: nipNisController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _nipNisLabel,
                          hintText: selectedRole == 'teacher'
                              ? 'Masukkan NIP Anda'
                              : 'Masukkan NIS Anda',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                          prefixIcon: Icon(
                            Icons.badge_outlined,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.15),
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
                          fillColor: Colors.white.withOpacity(0.02),
                        ),
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 18),
                    ],

                    // ── Email & Password (Semua Role) ──
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.15),
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
                        fillColor: Colors.white.withOpacity(0.02),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white.withOpacity(0.6),
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
                            color: Colors.white.withOpacity(0.15),
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
                        fillColor: Colors.white.withOpacity(0.02),
                      ),
                    ),

                    const SizedBox(height: 32),

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
                            color: const Color(0xFF8B5CF6).withOpacity(0.35),
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
                            : const Text(
                                'REGISTER',
                                style: TextStyle(
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
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'KEMBALI KE LOGIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}
}
