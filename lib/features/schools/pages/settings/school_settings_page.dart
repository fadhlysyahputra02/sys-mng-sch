import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../authentication/widgets/auth_background.dart';

class SchoolSettingsPage extends StatefulWidget {
  final String schoolId;
  final bool hideBackButton;

  const SchoolSettingsPage({
    super.key,
    required this.schoolId,
    this.hideBackButton = false,
  });

  @override
  State<SchoolSettingsPage> createState() => _SchoolSettingsPageState();
}

class _SchoolSettingsPageState extends State<SchoolSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // ── Akun ──────────────────────────────────────────────────────────
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── Grade Templates ───────────────────────────────────────────────
  final _aplusController  = TextEditingController(text: '95');
  final _aController      = TextEditingController(text: '90');
  final _aminusController = TextEditingController(text: '85');
  final _bplusController  = TextEditingController(text: '80');
  final _bController      = TextEditingController(text: '75');
  final _bminusController = TextEditingController(text: '70');
  final _cplusController  = TextEditingController(text: '65');
  final _cController      = TextEditingController(text: '60');
  final _cminusController = TextEditingController(text: '55');
  final _tahunAjaranController = TextEditingController(text: '${DateTime.now().year}/${DateTime.now().year + 1}');
  String _activeSemester = 'Semester 1';
  final _jamMasukController = TextEditingController(text: '07:15');

  String? _logoBase64;
  bool _isLoading    = true;
  bool _isSavingAkun = false;
  bool _isSavingNilai = false;
  bool _obscureCurrent = true;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchoolData();
  }

  Future<void> _loadSchoolData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        final gradeTemplates =
            data['grade_templates'] as Map<String, dynamic>? ?? {};

        setState(() {
          _logoBase64 = data['logoBase64'];
          _tahunAjaranController.text = data['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
          _activeSemester = data['semester'] ?? 'Semester 1';
          _jamMasukController.text = data['jamMasuk'] ?? '07:15';

          if (gradeTemplates.isNotEmpty) {
            _aplusController.text  = (gradeTemplates['aplus']  ?? 95).toString();
            _aController.text      = (gradeTemplates['a']      ?? 90).toString();
            _aminusController.text = (gradeTemplates['aminus'] ?? 85).toString();
            _bplusController.text  = (gradeTemplates['bplus']  ?? 80).toString();
            _bController.text      = (gradeTemplates['b']      ?? 75).toString();
            _bminusController.text = (gradeTemplates['bminus'] ?? 70).toString();
            _cplusController.text  = (gradeTemplates['cplus']  ?? 65).toString();
            _cController.text      = (gradeTemplates['c']      ?? 60).toString();
            _cminusController.text = (gradeTemplates['cminus'] ?? 55).toString();
          }

          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pick Logo ────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() => _logoBase64 = base64Encode(bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e')),
        );
      }
    }
  }

  // ── Save: Tab Profil Akun ────────────────────────────────────────
  Future<void> _saveAkun() async {
    final password        = _passwordController.text.trim();
    final confirm         = _confirmPasswordController.text.trim();
    final currentPassword = _currentPasswordController.text.trim();

    if (password.isNotEmpty) {
      if (currentPassword.isEmpty) {
        _snack('Password saat ini wajib diisi untuk mengubah password');
        return;
      }
      if (password.length < 6) {
        _snack('Password baru minimal 6 karakter');
        return;
      }
      if (password != confirm) {
        _snack('Konfirmasi password baru tidak cocok');
        return;
      }
    }

    try {
      setState(() => _isSavingAkun = true);

      // Simpan logo
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .update({'logoBase64': _logoBase64});

      // Ubah password jika diisi
      if (password.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.email != null) {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: currentPassword,
          );
          await user.reauthenticateWithCredential(credential);
          await user.updatePassword(password);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'password': password});

          // Clear password fields
          _currentPasswordController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
        }
      }

      if (mounted) _snack('Profil akun berhasil disimpan');
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isSavingAkun = false);
    }
  }

  // ── Save: Tab Pengaturan Sekolah ─────────────────────────────────
  Future<void> _saveNilai() async {
    try {
      setState(() => _isSavingNilai = true);

      final Map<String, int> templates = {
        'aplus':  int.tryParse(_aplusController.text)  ?? 95,
        'a':      int.tryParse(_aController.text)      ?? 90,
        'aminus': int.tryParse(_aminusController.text) ?? 85,
        'bplus':  int.tryParse(_bplusController.text)  ?? 80,
        'b':      int.tryParse(_bController.text)      ?? 75,
        'bminus': int.tryParse(_bminusController.text) ?? 70,
        'cplus':  int.tryParse(_cplusController.text)  ?? 65,
        'c':      int.tryParse(_cController.text)      ?? 60,
        'cminus': int.tryParse(_cminusController.text) ?? 55,
      };

      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .update({
        'grade_templates': templates,
        'tahunAjaran': _tahunAjaranController.text.trim(),
        'semester': _activeSemester,
        'jamMasuk': _jamMasukController.text.trim(),
      });

      if (mounted) _snack('Pengaturan sekolah berhasil disimpan');
    } catch (e) {
      if (mounted) _snack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isSavingNilai = false);
    }
  }

  Future<void> _selectJamMasuk() async {
    TimeOfDay initialTime = const TimeOfDay(hour: 7, minute: 15);
    try {
      final parts = _jamMasukController.text.split(':');
      if (parts.length == 2) {
        initialTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (_) {}

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        _jamMasukController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _tabController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _aplusController.dispose();
    _aController.dispose();
    _aminusController.dispose();
    _bplusController.dispose();
    _bController.dispose();
    _bminusController.dispose();
    _cplusController.dispose();
    _cController.dispose();
    _cminusController.dispose();
    _tahunAjaranController.dispose();
    _jamMasukController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor       = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonColor  = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final tabUnselColor    = isDark
            ? Colors.white.withValues(alpha: 0.45)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.45);
        final tabBg = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // ── AppBar ─────────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        if (!widget.hideBackButton)
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_ios_new_rounded,
                                color: backButtonColor, size: 20),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Pengaturan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Tab Bar ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tabBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: tabUnselColor,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.all(4),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.manage_accounts_rounded, size: 17),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Profil Akun',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.tune_rounded, size: 17),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Pengaturan Sekolah',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Tab Body ───────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6366F1)),
                          ),
                        )
                      : Form(
                          key: _formKey,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildProfilTab(isDark),
                              _buildNilaiTab(isDark),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  TAB 1 — Profil Akun
  // ════════════════════════════════════════════════════════════════════
  Widget _buildProfilTab(bool isDark) {
    final cardBg     = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.04);
    final textPrimary   = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          // ── Logo ─────────────────────────────────────────────────
          _sectionLabel('Logo Sekolah', Icons.image_outlined, isDark),
          const SizedBox(height: 16),

          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: _logoBase64 != null
                          ? Image.memory(base64Decode(_logoBase64!),
                              fit: BoxFit.cover)
                          : const Icon(Icons.school_rounded,
                              color: Color(0xFF6366F1), size: 52),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Ketuk untuk mengganti logo sekolah',
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),

          const SizedBox(height: 32),

          // ── Password ──────────────────────────────────────────────
          _sectionLabel('Keamanan Akun', Icons.shield_outlined, isDark),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                          color: cardShadow,
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: Color(0xFF6366F1), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ubah Password',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Biarkan kosong jika tidak ingin mengubah password.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 20),

                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: 'Password Saat Ini',
                  obscure: _obscureCurrent,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildPasswordField(
                  controller: _passwordController,
                  label: 'Password Baru',
                  obscure: _obscurePass,
                  onToggle: () =>
                      setState(() => _obscurePass = !_obscurePass),
                  isDark: isDark,
                ),
                const SizedBox(height: 14),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Konfirmasi Password',
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  isConfirm: true,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // ── Save button (Profil) ──────────────────────────────────
          _buildSaveButton(
            label: 'Simpan Profil Akun',
            icon: Icons.person_rounded,
            isSaving: _isSavingAkun,
            onPressed: _saveAkun,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  TAB 2 — Pengaturan Sekolah
  // ════════════════════════════════════════════════════════════════════
  Widget _buildNilaiTab(bool isDark) {
    final cardBg     = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark
        ? Colors.transparent
        : Colors.black.withValues(alpha: 0.04);
    final textPrimary   = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),

          _sectionLabel('Batas Nilai Rapor', Icons.speed_rounded, isDark),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                          color: cardShadow,
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Color(0xFF6366F1), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Atur Batas Minimum Nilai Predikat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Nilai minimum untuk setiap predikat yang akan ditampilkan di E-Rapor.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 24),

                // ── Predikat A ────────────────────────────────────
                _gradeGroupLabel('Predikat A', const Color(0xFF10B981), isDark),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _aplusController,
                        label: 'Min A+',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        controller: _aController,
                        label: 'Min A',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        controller: _aminusController,
                        label: 'Min A-',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Predikat B ────────────────────────────────────
                _gradeGroupLabel('Predikat B', const Color(0xFF3B82F6), isDark),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _bplusController,
                        label: 'Min B+',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        controller: _bController,
                        label: 'Min B',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        controller: _bminusController,
                        label: 'Min B-',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // ── Predikat C ────────────────────────────────────
                _gradeGroupLabel('Predikat C', const Color(0xFFF59E0B), isDark),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _cplusController,
                        label: 'Min C+',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        controller: _cController,
                        label: 'Min C',
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberField(
                        controller: _cminusController,
                        label: 'Min C-',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Info note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF6366F1), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nilai yang dimasukkan adalah nilai minimum untuk mendapatkan predikat tersebut.',
                          style: TextStyle(
                              fontSize: 11, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          _sectionLabel('Tahun Ajaran & Semester Aktif', Icons.calendar_today_rounded, isDark),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                          color: cardShadow,
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.date_range_rounded,
                          color: Color(0xFF6366F1), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Konfigurasi Kalender Akademik',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tahun ajaran dan semester aktif yang menjadi rujukan penilaian, absensi, dan cetak rapor.',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 20),

                // Tahun Ajaran Input
                Text(
                  'Tahun Ajaran',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: TextFormField(
                    controller: _tahunAjaranController,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. 2025/2026',
                      hintStyle: TextStyle(color: textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Semester Selection
                Text(
                  'Semester Aktif',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Semester 1',
                        label: Text('Semester 1'),
                        icon: Icon(Icons.looks_one_rounded),
                      ),
                      ButtonSegment(
                        value: 'Semester 2',
                        label: Text('Semester 2'),
                        icon: Icon(Icons.looks_two_rounded),
                      ),
                    ],
                    selected: {_activeSemester},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _activeSemester = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: const Color(0xFF6366F1),
                      selectedForegroundColor: Colors.white,
                      foregroundColor: textPrimary,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      side: BorderSide(color: cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Jam Masuk Input
                Text(
                  'Jam Masuk Sekolah (Toleransi)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: TextFormField(
                    controller: _jamMasukController,
                    readOnly: true,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    onTap: _selectJamMasuk,
                    decoration: InputDecoration(
                      hintText: 'e.g. 07:15',
                      hintStyle: TextStyle(color: textSecondary),
                      prefixIcon: const Icon(Icons.access_time_rounded, color: Color(0xFF6366F1)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // ── Save button (Nilai) ───────────────────────────────────
          _buildSaveButton(
            label: 'Simpan Pengaturan Sekolah',
            icon: Icons.save_rounded,
            isSaving: _isSavingNilai,
            onPressed: _saveNilai,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════════

  Widget _sectionLabel(String title, IconData icon, bool isDark) {
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.75);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return Row(
      children: [
        Icon(icon, color: textSecondary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _gradeGroupLabel(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton({
    required String label,
    required IconData icon,
    required bool isSaving,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: isSaving ? null : onPressed,
        child: isSaving
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDark,
    bool isConfirm = false,
  }) {
    final fieldBg    = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final fieldBorder= isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final textColor  = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final iconColor  = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fieldBorder),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelColor, fontSize: 14),
          prefixIcon: Icon(
            isConfirm ? Icons.lock_rounded : Icons.lock_outline_rounded,
            color: const Color(0xFF6366F1),
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: iconColor,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
  }) {
    final fieldBg    = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final fieldBorder= isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final textColor  = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fieldBorder),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelColor, fontSize: 12),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
