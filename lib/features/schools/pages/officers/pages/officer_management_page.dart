import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';

class OfficerManagementPage extends StatefulWidget {
  final bool hideBackButton;

  const OfficerManagementPage({super.key, this.hideBackButton = false});

  @override
  State<OfficerManagementPage> createState() => _OfficerManagementPageState();
}

class _OfficerManagementPageState extends State<OfficerManagementPage> {
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

  Future<void> _addOfficer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final nama = _namaController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      // 1. Buat temporary Firebase App untuk registrasi user Auth baru
      // tanpa men-logout admin yang sedang aktif
      final tempApp = await Firebase.initializeApp(
        name: 'TempRegisterApp',
        options: Firebase.app().options,
      );

      final credential = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(email: email, password: password);

      // Hapus temporary Firebase App context
      await tempApp.delete();

      final uid = credential.user!.uid;

      // 2. Simpan profil data user ke Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'nama': nama,
        'role': 'officer',
        'schoolId': _schoolId,
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Reset controller & tutup dialog
      _namaController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      Get.back();

      Get.snackbar(
        'Berhasil',
        'Akun petugas $nama berhasil dibuat.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteOfficer(String uid, String nama) async {
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
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Hapus Petugas', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menonaktifkan petugas "$nama" dari otoritas scan absensi?',
          style: TextStyle(color: textColor.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Batal',
              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data();
      final role = data?['role'] as String?;

      if (role == 'teacher') {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isGateOfficer': false,
          'scanGuruEnabled': false,
          'scanMuridEnabled': false,
        });
        Get.snackbar(
          'Berhasil',
          'Akses petugas untuk guru $nama berhasil dinonaktifkan.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        Get.snackbar(
          'Berhasil',
          'Akun petugas $nama berhasil dinonaktifkan.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Gagal',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showAddTeacherOfficerDialog() {
    String searchQuery = '';
    
    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = AuthBackground.isDarkMode.value;
          final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
          final fieldFill = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02);
          final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12);

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: fieldBorder),
            ),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tambah Guru Sebagai Petugas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aktifkan akses scan absensi gerbang untuk guru yang dipilih.',
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search field
                  TextField(
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari nama guru...',
                      hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) {
                      setStateDialog(() {
                        searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // List of teachers
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('schoolId', isEqualTo: _schoolId)
                            .where('role', isEqualTo: 'teacher')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text(
                                'Tidak ada guru yang terdaftar.',
                                style: TextStyle(color: subTextColor),
                              ),
                            );
                          }

                          final teachers = snapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final nama = (data['nama'] ?? '').toString().toLowerCase();
                            return nama.contains(searchQuery);
                          }).toList();

                          if (teachers.isEmpty) {
                            return Center(
                              child: Text(
                                'Nama guru tidak cocok.',
                                style: TextStyle(color: subTextColor),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: teachers.length,
                            itemBuilder: (context, idx) {
                              final doc = teachers[idx];
                              final data = doc.data() as Map<String, dynamic>;
                              final nama = data['nama'] ?? '-';
                              final isGateOfficer = data['isGateOfficer'] as bool? ?? false;
                              final scanGuruEnabled = data['scanGuruEnabled'] as bool? ?? isGateOfficer;
                              final scanMuridEnabled = data['scanMuridEnabled'] as bool? ?? isGateOfficer;

                              return Card(
                                color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isGateOfficer
                                        ? const Color(0xFF6366F1).withOpacity(0.4)
                                        : fieldBorder,
                                    width: isGateOfficer ? 1.5 : 1,
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_rounded,
                                            color: isGateOfficer ? const Color(0xFF6366F1) : subTextColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              nama,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Switch(
                                            value: isGateOfficer,
                                            activeColor: const Color(0xFF6366F1),
                                            onChanged: (val) async {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(doc.id)
                                                  .update({
                                                'isGateOfficer': val,
                                                'scanGuruEnabled': val,
                                                'scanMuridEnabled': val,
                                              });
                                              Get.snackbar(
                                                'Berhasil',
                                                val
                                                    ? '$nama diaktifkan sebagai petugas scan.'
                                                    : '$nama dinonaktifkan dari petugas scan.',
                                                backgroundColor: const Color(0xFF10B981),
                                                colorText: Colors.white,
                                                duration: const Duration(seconds: 2),
                                              );
                                              setStateDialog(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                      if (isGateOfficer) ...[
                                        const Divider(height: 16),
                                        Text(
                                          'Hak Akses Scan:',
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: CheckboxListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  'Scan Guru',
                                                  style: TextStyle(color: textColor, fontSize: 12),
                                                ),
                                                value: scanGuruEnabled,
                                                activeColor: const Color(0xFF3B82F6),
                                                dense: true,
                                                controlAffinity: ListTileControlAffinity.leading,
                                                onChanged: (val) async {
                                                  if (val != null) {
                                                    final newScanGuru = val;
                                                    final newScanMurid = scanMuridEnabled;
                                                    final newIsGate = newScanGuru || newScanMurid;

                                                    await FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(doc.id)
                                                        .update({
                                                      'scanGuruEnabled': newScanGuru,
                                                      'isGateOfficer': newIsGate,
                                                    });
                                                    setStateDialog(() {});
                                                  }
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: CheckboxListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: Text(
                                                  'Scan Murid',
                                                  style: TextStyle(color: textColor, fontSize: 12),
                                                ),
                                                value: scanMuridEnabled,
                                                activeColor: const Color(0xFF10B981),
                                                dense: true,
                                                controlAffinity: ListTileControlAffinity.leading,
                                                onChanged: (val) async {
                                                  if (val != null) {
                                                    final newScanGuru = scanGuruEnabled;
                                                    final newScanMurid = val;
                                                    final newIsGate = newScanGuru || newScanMurid;

                                                    await FirebaseFirestore.instance
                                                        .collection('users')
                                                        .doc(doc.id)
                                                        .update({
                                                      'scanMuridEnabled': newScanMurid,
                                                      'isGateOfficer': newIsGate,
                                                    });
                                                    setStateDialog(() {});
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Close Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Get.back(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddOfficerDialog() {
    _namaController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = AuthBackground.isDarkMode.value;
          final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
          final fieldFill = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02);
          final fieldBorder = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12);

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
                        'Tambah Petugas Baru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Buat akun masuk khusus untuk petugas / satpam / piket sekolah.',
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
                          labelText: 'Nama Lengkap',
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
                            val == null || val.trim().isEmpty ? 'Nama lengkap harus diisi' : null,
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
                          if (val == null || val.trim().isEmpty) return 'Email harus diisi';
                          if (!GetUtils.isEmail(val.trim())) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        style: TextStyle(color: textColor),
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: subTextColor),
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
                          if (val == null || val.trim().isEmpty) return 'Password harus diisi';
                          if (val.trim().length < 6) return 'Password minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        style: TextStyle(color: textColor),
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Password',
                          labelStyle: TextStyle(color: subTextColor),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: subTextColor),
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
                          if (val == null || val.trim().isEmpty) return 'Konfirmasi password harus diisi';
                          if (val.trim() != _passwordController.text.trim()) return 'Password tidak cocok';
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
                              'Batal',
                              style: TextStyle(color: textColor.withValues(alpha: 0.5)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setStateDialog(() {});
                                    await _addOfficer();
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
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Simpan',
                                    style: TextStyle(
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
                            'Data Petugas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        // Add Button wrap
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _showAddOfficerDialog,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Petugas Baru',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _showAddTeacherOfficerDialog,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Petugas Guru',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
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
                                'Terjadi kesalahan memuat data',
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

                      final docs = (snapshot.data?.docs ?? []).where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final role = data['role'] as String?;
                        final isGateOfficer = data['isGateOfficer'] as bool? ?? false;
                        return role == 'officer' || (role == 'teacher' && isGateOfficer);
                      }).toList();

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
                                child: Icon(Icons.security_rounded, size: 48, color: mutedColor),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Belum ada data petugas',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap tombol di atas untuk mendaftarkan petugas baru',
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
                          final role = data['role'] ?? 'officer';
                          final isTeacher = role == 'teacher';

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
                                  // Avatar bulat security / teacher
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isTeacher
                                            ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                            : [const Color(0xFF8B5CF6), const Color(0xFFD946EF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                        isTeacher
                                            ? Icons.school_rounded
                                            : Icons.security_rounded,
                                        color: Colors.white,
                                        size: 26),
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
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (isTeacher
                                                        ? const Color(0xFF10B981)
                                                        : const Color(0xFF8B5CF6))
                                                    .withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: (isTeacher
                                                          ? const Color(0xFF10B981)
                                                          : const Color(0xFF8B5CF6))
                                                      .withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                isTeacher ? 'Petugas Guru' : 'Petugas Kehadiran',
                                                style: TextStyle(
                                                  color: isTeacher
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFF8B5CF6),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (data['scanGuruEnabled'] as bool? ?? (data['isGateOfficer'] as bool? ?? !isTeacher))
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                                ),
                                                child: const Text(
                                                  'Scan Guru',
                                                  style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            if (data['scanMuridEnabled'] as bool? ?? (data['isGateOfficer'] as bool? ?? !isTeacher))
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                                ),
                                                child: const Text(
                                                  'Scan Murid',
                                                  style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Delete button
                                  IconButton(
                                    onPressed: () => _deleteOfficer(doc.id, name),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                    tooltip: 'Hapus Petugas',
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
