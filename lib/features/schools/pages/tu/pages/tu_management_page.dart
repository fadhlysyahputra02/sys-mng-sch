import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../../../../core/localization/app_localization.dart';

class TuManagementPage extends StatefulWidget {
  final bool hideBackButton;

  const TuManagementPage({super.key, this.hideBackButton = false});

  @override
  State<TuManagementPage> createState() => _TuManagementPageState();
}

class _TuManagementPageState extends State<TuManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _schoolId => SessionService.currentUser?.schoolId ?? '';

  Future<void> _addTu() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nama = _namaController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final tempApp = await Firebase.initializeApp(
        name: 'TempRegisterApp',
        options: Firebase.app().options,
      );

      final credential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      await tempApp.delete();

      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'nama': nama,
        'role': 'tu',
        'schoolId': _schoolId,
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _namaController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      Get.back();

      Get.snackbar(
        AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
        AppLocalization.isIndonesian ? 'Akun Tata Usaha $nama berhasil dibuat.' : 'TU account $nama successfully created.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTu(String uid, String nama) async {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dialogBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              AppLocalization.isIndonesian ? 'Hapus Tata Usaha' : 'Delete TU Staff',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          AppLocalization.isIndonesian
              ? 'Apakah Anda yakin ingin menghapus akun "$nama"? Tindakan ini akan menolak akses login mereka ke sistem.'
              : 'Are you sure you want to delete the account "$nama"? This action will deny their login access to the system.',
          style: TextStyle(color: textColor.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              AppLocalization.isIndonesian ? 'Hapus' : 'Delete',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      Get.snackbar(
        AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
        AppLocalization.isIndonesian ? 'Akun $nama berhasil dinonaktifkan.' : 'Account $nama successfully deactivated.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showAddTuDialog() {
    _namaController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();

    bool obscurePassword = true;
    bool obscureConfirm = true;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = AuthBackground.isDarkMode.value;
          final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
          final fieldFill = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02);
          final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12);

          final pass = _passwordController.text;
          final hasUppercase = RegExp(r'[A-Z]').hasMatch(pass);
          final hasLowercase = RegExp(r'[a-z]').hasMatch(pass);
          final hasNumber = RegExp(r'[0-9]').hasMatch(pass);
          final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass);
          final isPasswordValid = pass.length >= 6 && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;

          Widget buildRequirementItem(String label, bool isMet) {
            final activeColor = const Color(0xFF10B981);
            final inactiveColor = isDark ? Colors.white38 : Colors.black38;
            final itemTextColor = isDark ? Colors.white70 : Colors.black87;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Icon(
                    isMet ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isMet ? activeColor : inactiveColor,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isMet ? activeColor : itemTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: fieldBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalization.isIndonesian ? 'Tambah Tata Usaha Baru' : 'Add New TU Staff',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalization.isIndonesian
                            ? 'Buat akun masuk khusus untuk staf back office sekolah.'
                            : 'Create a dedicated login account for school back office staff.',
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Nama Field
                      TextFormField(
                        controller: _namaController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: AppLocalization.isIndonesian ? 'Nama Lengkap' : 'Full Name',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.person_outline_rounded, color: subTextColor),
                          filled: true,
                          fillColor: fieldFill,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? (AppLocalization.isIndonesian ? 'Nama lengkap harus diisi' : 'Full name is required') : null,
                      ),
                      const SizedBox(height: 16),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: textColor),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.email_outlined, color: subTextColor),
                          filled: true,
                          fillColor: fieldFill,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return AppLocalization.isIndonesian ? 'Email harus diisi' : 'Email is required';
                          if (!GetUtils.isEmail(val.trim())) return AppLocalization.isIndonesian ? 'Format email tidak valid' : 'Invalid email format';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        style: TextStyle(color: textColor),
                        obscureText: obscurePassword,
                        onChanged: (_) => setStateDialog(() {}),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: subTextColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: subTextColor,
                            ),
                            onPressed: () => setStateDialog(() => obscurePassword = !obscurePassword),
                          ),
                          filled: true,
                          fillColor: fieldFill,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return AppLocalization.isIndonesian ? 'Password harus diisi' : 'Password is required';
                          final passVal = val.trim();
                          final hasUpper = RegExp(r'[A-Z]').hasMatch(passVal);
                          final hasLower = RegExp(r'[a-z]').hasMatch(passVal);
                          final hasNum = RegExp(r'[0-9]').hasMatch(passVal);
                          final hasSpec = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(passVal);
                          final isValid = passVal.length >= 6 && hasUpper && hasLower && hasNum && hasSpec;
                          if (!isValid) return AppLocalization.isIndonesian ? 'Password tidak memenuhi syarat keamanan' : 'Password does not meet security requirements';
                          return null;
                        },
                      ),
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildRequirementItem(AppLocalization.isIndonesian ? 'Minimal 6 karakter' : 'At least 6 characters', pass.length >= 6),
                              buildRequirementItem(AppLocalization.isIndonesian ? 'Memiliki huruf besar (A-Z)' : 'Must have uppercase (A-Z)', hasUppercase),
                              buildRequirementItem(AppLocalization.isIndonesian ? 'Memiliki huruf kecil (a-z)' : 'Must have lowercase (a-z)', hasLowercase),
                              buildRequirementItem(AppLocalization.isIndonesian ? 'Memiliki angka (0-9)' : 'Must have number (0-9)', hasNumber),
                              buildRequirementItem(AppLocalization.isIndonesian ? 'Memiliki karakter khusus (!@#\$%^&* dll)' : 'Must have special character (!@#\$%^&* etc)', hasSpecialChar),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: TextStyle(color: textColor),
                        obscureText: obscureConfirm,
                        onChanged: (_) => setStateDialog(() {}),
                        decoration: InputDecoration(
                          labelText: AppLocalization.isIndonesian ? 'Konfirmasi Password' : 'Confirm Password',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: subTextColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: subTextColor,
                            ),
                            onPressed: () => setStateDialog(() => obscureConfirm = !obscureConfirm),
                          ),
                          filled: true,
                          fillColor: fieldFill,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return AppLocalization.isIndonesian ? 'Konfirmasi password harus diisi' : 'Confirm password is required';
                          if (val.trim() != _passwordController.text.trim()) return AppLocalization.isIndonesian ? 'Password tidak cocok' : 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                           TextButton(
                            onPressed: _isLoading ? null : () => Get.back(),
                            child: Text(
                              AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: (_isLoading || !isPasswordValid)
                                ? null
                                : () async {
                                    setStateDialog(() {});
                                    await _addTu();
                                    setStateDialog(() {});
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    AppLocalization.isIndonesian ? 'Simpan' : 'Save',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
        final mutedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
        final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFF1E1B4B).withValues(alpha: 0.04);
        final borderCol = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // Custom AppBar
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        if (!widget.hideBackButton)
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalization.isIndonesian ? 'Data Tata Usaha' : 'TU Administration Data',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        // Add Button
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _showAddTuDialog,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalization.isIndonesian ? 'Tambah' : 'Add',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main List Content
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('schoolId', isEqualTo: _schoolId)
                        .where('role', isEqualTo: 'tu')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.error_outline_rounded,
                                    size: 40, color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalization.isIndonesian ? 'Terjadi kesalahan memuat data' : 'An error occurred loading data',
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderCol),
                                ),
                                child: Icon(Icons.support_agent_rounded, size: 48, color: mutedColor),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                AppLocalization.isIndonesian ? 'Belum ada data Tata Usaha' : 'No TU data yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalization.isIndonesian
                                    ? 'Tap "Tambah" untuk mendaftarkan akun TU'
                                    : 'Tap "Add" to register a TU account',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['nama'] ?? '-';
                          final email = data['email'] ?? '-';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderCol),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.15 : 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Avatar bulat
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.support_agent_rounded,
                                        color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Icon(Icons.mail_outline_rounded,
                                                size: 13, color: mutedColor),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                email,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: subtitleColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Role badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3B82F6)
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: const Color(0xFF3B82F6)
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            AppLocalization.isIndonesian ? 'Tata Usaha' : 'Administration',
                                            style: const TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Delete button
                                  IconButton(
                                    onPressed: () => _deleteTu(doc.id, name),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                    tooltip: AppLocalization.isIndonesian ? 'Hapus Tata Usaha' : 'Delete TU Staff',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
