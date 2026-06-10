import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../schools/services/school_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String selectedRole = 'school_admin';

  // Controllers school_admin
  final domainController = TextEditingController();
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
    domainController.dispose();
    kodeController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Daftar Sebagai',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                  value: 'school_admin',
                  child: Text('Admin Sekolah'),
                ),
                DropdownMenuItem(value: 'teacher', child: Text('Guru')),
                DropdownMenuItem(value: 'student', child: Text('Murid')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                  _selectedSekolah = null;
                  nipNisController.clear();
                  namaController.clear();
                });
              },
            ),

            const SizedBox(height: 16),

            // ── Kolom khusus Admin Sekolah ──
            if (selectedRole == 'school_admin') ...[
              TextField(
                controller: domainController,
                decoration: const InputDecoration(
                  labelText: 'Domain Sekolah',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: kodeController,
                decoration: const InputDecoration(
                  labelText: 'Kode Registrasi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Kolom khusus Guru & Murid ──
            if (selectedRole == 'teacher' || selectedRole == 'student') ...[
              // Dropdown pilih sekolah
              _loadingSekolah
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _selectedSekolah,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Sekolah',
                        border: OutlineInputBorder(),
                      ),
                      items: _sekolahList.map((school) {
                        return DropdownMenuItem(
                          value: school,
                          child: Text(school['namaSekolah'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedSekolah = val),
                      hint: const Text('Pilih nama sekolah'),
                    ),

              const SizedBox(height: 16),

              // Field NIP / NIS
              TextField(
                controller: nipNisController,
                decoration: InputDecoration(
                  labelText: _nipNisLabel,
                  hintText: selectedRole == 'teacher'
                      ? 'Masukkan NIP kamu'
                      : 'Masukkan NIS kamu',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 16),
            ],

            // ── Email & Password (semua role) ──
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onRegister,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('REGISTER'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Get.toNamed(AppRoutes.login);
                },
                child: const Text('KEMBALI KE LOGIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRegister() async {
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

  // ── Register Admin Sekolah (logika lama, tidak berubah) ──
  Future<void> _registerAdmin() async {
    try {
      final domain = domainController.text.trim().toLowerCase();
      final school = await schoolService.getSchoolByDomain(domain);

      if (school == null) throw Exception('Domain sekolah tidak ditemukan');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Register berhasil')));
        Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  // ── Register Guru ──
  Future<void> _registerGuru() async {
    try {
      if (_selectedSekolah == null) {
        throw Exception('Pilih sekolah terlebih dahulu');
      }

      final nip = nipNisController.text.trim();

      if (nip.isEmpty) {
        throw Exception('NIP wajib diisi');
      }

      final schoolId = _selectedSekolah!['schoolId'] as String;

      // Cari data guru
      final teacher = await schoolService.getTeacherByNip(
        schoolId: schoolId,
        nip: nip,
      );

      if (teacher == null) {
        throw Exception('NIP tidak ditemukan');
      }

      if (teacher['aktif'] != true) {
        throw Exception('Guru tidak aktif');
      }

      if (teacher['sudahRegister'] == true) {
        throw Exception('Guru sudah pernah register');
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
        teacherId: teacher['teacherId'],
        nama: teacher['nama'],
        uid: uid,
        email: emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Register guru berhasil')));

        Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  // ── Register Murid ──
  Future<void> _registerMurid() async {
    try {
      if (_selectedSekolah == null) {
        throw Exception('Pilih sekolah terlebih dahulu');
      }

      final nis = nipNisController.text.trim();

      if (nis.isEmpty) {
        throw Exception('NIS wajib diisi');
      }

      final schoolId = _selectedSekolah!['schoolId'] as String;

      // Cari data murid
      final student = await schoolService.getStudentByNis(
        schoolId: schoolId,
        nis: nis,
      );

      if (student == null) {
        throw Exception('NIS tidak ditemukan');
      }

      if (student['aktif'] != true) {
        throw Exception('Murid tidak aktif');
      }

      if (student['sudahRegister'] == true) {
        throw Exception('Murid sudah pernah register');
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
        studentId: student['studentId'],
        nama: student['nama'],
        uid: uid,
        email: emailController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Register murid berhasil')),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
