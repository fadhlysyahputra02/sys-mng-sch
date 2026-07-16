import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../authentication/widgets/auth_background.dart';
import '../../../authentication/widgets/theme_toggle_button.dart';
import '../../../authentication/widgets/language_toggle_button.dart';
import '../../../../core/localization/app_localization.dart';
import '../../../../core/services/semester_state_service.dart';
import '../../../../core/services/session_service.dart';

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

  // ── Identitas Sekolah ─────────────────────────────────────────────
  final _schoolNameController = TextEditingController();

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

  // ── Reset Semester ─────────────────────────────────────────────────
  Map<String, dynamic>? _resetRequest; // null = tidak ada pengajuan
  bool _isResetting = false;
  bool _isSubmittingRequest = false;

  // ── Tanggal Mulai Semester ────────────────────────────────────────
  DateTime? _tanggalMulaiSemester;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchoolData();
    _listenResetRequest();
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
          _schoolNameController.text = data['namaSekolah'] ?? data['name'] ?? data['nama'] ?? '';
          _tahunAjaranController.text = data['tahunAjaran'] ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
          _activeSemester = data['semester'] ?? 'Semester 1';
          _jamMasukController.text = data['jamMasuk'] ?? '07:15';

          // Tanggal mulai semester
          final ts = data['tanggalMulaiSemester'];
          _tanggalMulaiSemester = ts is Timestamp ? ts.toDate() : null;

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

  void _listenResetRequest() {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _resetRequest = data['resetRequest'] as Map<String, dynamic>?;
      });
    });
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
        _snack(AppLocalization.passwordRequired);
        return;
      }
      if (password.length < 6) {
        _snack(AppLocalization.passwordMinLength);
        return;
      }
      final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      final hasNumber = RegExp(r'[0-9]').hasMatch(password);
      final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
      if (!hasUppercase || !hasLowercase || !hasNumber || !hasSpecialChar) {
        _snack(AppLocalization.isIndonesian
            ? 'Password baru harus mengandung huruf besar, huruf kecil, angka, dan karakter spesial'
            : 'New password must contain uppercase, lowercase, number, and special character');
        return;
      }
      if (password == currentPassword) {
        _snack(AppLocalization.isIndonesian
            ? 'Password baru tidak boleh sama dengan password saat ini'
            : 'New password cannot be the same as the current password');
        return;
      }
      if (password != confirm) {
        _snack(AppLocalization.passwordNotMatch);
        return;
      }
    }

    final schoolName = _schoolNameController.text.trim();
    if (schoolName.isEmpty) {
      _snack(AppLocalization.schoolNameRequired);
      return;
    }

    try {
      setState(() => _isSavingAkun = true);

      // Simpan logo & nama sekolah
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .update({
        'logoBase64': _logoBase64,
        'namaSekolah': schoolName,
      });

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

      if (mounted) _snack(AppLocalization.profileSaved);
    } catch (e) {
      if (mounted) _snack('${AppLocalization.saveFailed}: $e');
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
        if (_tanggalMulaiSemester != null)
          'tanggalMulaiSemester': Timestamp.fromDate(_tanggalMulaiSemester!)
        else
          'tanggalMulaiSemester': FieldValue.delete(),
        // Membuka semester baru / mengubah tanggal mulai juga mereset status penutupan
        'semesterDitutup': false,
        'tanggalSemesterDitutup': FieldValue.delete(),
      });

      if (mounted) _snack(AppLocalization.settingsSaved);
    } catch (e) {
      if (mounted) _snack('${AppLocalization.saveFailed}: $e');
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

  // ── Reset Semester: TU Submits Request ──────────────────────────────
  Future<void> _submitResetRequest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = AuthBackground.isDarkMode.value;
        final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.send_rounded, color: Color(0xFF6366F1)),
              const SizedBox(width: 10),
              Text('Ajukan Akhiri Semester', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            'Pengajuan akan dikirimkan ke Admin Sekolah untuk disetujui.\n\nData berikut akan direset setelah disetujui:\n• Jadwal kelas\n• Penugasan wali kelas & murid\n• Alokasi jam pelajaran\n• Bobot nilai per kelas\n• Surat izin\n• Data realtime control',
            style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirim Pengajuan'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      setState(() => _isSubmittingRequest = true);
      final user = SessionService.currentUser;
      await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update({
        'resetRequest': {
          'status': 'pending',
          'requestedBy': user?.uid ?? '',
          'requestedByName': user?.nama ?? '',
          'requestedAt': FieldValue.serverTimestamp(),
          'tahunAjaran': _tahunAjaranController.text.trim(),
          'semester': _activeSemester,
        },
      });
      if (mounted) _snack(AppLocalization.proposalSent);
    } catch (e) {
      if (mounted) _snack('${AppLocalization.isIndonesian ? "Gagal mengirim pengajuan" : "Failed to send request"}: $e');
    } finally {
      if (mounted) setState(() => _isSubmittingRequest = false);
    }
  }

  // ── Reset Semester: Admin Cancels TU Request ─────────────────────────
  Future<void> _cancelResetRequest() async {
    try {
      await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).update({
        'resetRequest': FieldValue.delete(),
      });
      if (mounted) _snack(AppLocalization.proposalRejected);
    } catch (e) {
      if (mounted) _snack('${AppLocalization.proposalRejectFailed}: $e');
    }
  }

  // ── Reset Semester: Admin Confirms & Executes ───────────────────────
  Future<void> _confirmAndExecuteReset({bool isApproving = false}) async {
    final tahunAjaran = _tahunAjaranController.text.trim();
    final semester = _activeSemester;
    final expectedKeyword = 'akhiri $tahunAjaran $semester'.toLowerCase();
    final keywordController = TextEditingController();
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = AuthBackground.isDarkMode.value;
        final dialogBg = isDark ? const Color(0xFF1E1B4B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(AppLocalization.isIndonesian ? 'Konfirmasi Akhiri Semester' : 'Confirm Ending Semester', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    AppLocalization.isIndonesian
                        ? 'Aksi ini akan mereset konfigurasi kelas, jadwal, dan perizinan untuk tahun ajaran $tahunAjaran $semester. Tindakan ini tidak dapat dibatalkan.'
                        : 'This action will reset class, schedule, and permit configurations for the academic year $tahunAjaran $semester. This action cannot be undone.',
                    style: TextStyle(color: Colors.red.withValues(alpha: 0.85), fontSize: 12, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalization.isIndonesian
                      ? 'Ketik teks berikut untuk konfirmasi (klik untuk menyalin):'
                      : 'Type the following text to confirm (click to copy):',
                  style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
                ),
                const SizedBox(height: 8),
                // Selectable keyword box — user can tap to copy
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
                  ),
                  child: SelectableText(
                    'akhiri $tahunAjaran $semester',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: keywordController,
                  onChanged: (_) => setDialogState(() => errorText = null),
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'akhiri $tahunAjaran $semester',
                    hintStyle: TextStyle(color: textColor.withValues(alpha: 0.35), fontSize: 13),
                    errorText: errorText,
                    filled: true,
                    fillColor: textColor.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: textColor.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalization.cancelButton)),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (keywordController.text.trim().toLowerCase() != expectedKeyword) {
                    setDialogState(() => errorText = AppLocalization.isIndonesian ? 'Teks konfirmasi tidak sesuai' : 'Confirmation text does not match');
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text(AppLocalization.isIndonesian ? 'Akhiri Semester' : 'End Semester'),
              ),
            ],
          ),
        );
      },
    );
    keywordController.dispose();
    if (confirmed != true) return;
    await _runSemesterReset(isApproving: isApproving);
  }

  // ── Reset Semester: Actual Reset Logic ──────────────────────────────
  Future<void> _runSemesterReset({bool isApproving = false}) async {
    try {
      setState(() => _isResetting = true);
      final db = FirebaseFirestore.instance;
      final schoolRef = db.collection('schools').doc(widget.schoolId);

      // Helper: delete a subcollection in batches of 400
      Future<void> deleteSubcollection(String subcollection) async {
        while (true) {
          final snap = await schoolRef.collection(subcollection).limit(400).get();
          if (snap.docs.isEmpty) break;
          final batch = db.batch();
          for (final doc in snap.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // Helper: delete chat collections including subcollection 'messages'
      Future<void> deleteChatSubcollection(String subcollection) async {
        final roomsSnap = await schoolRef.collection(subcollection).get();
        for (final roomDoc in roomsSnap.docs) {
          while (true) {
            final messagesSnap = await roomDoc.reference.collection('messages').limit(400).get();
            if (messagesSnap.docs.isEmpty) break;
            final batch = db.batch();
            for (final msgDoc in messagesSnap.docs) {
              batch.delete(msgDoc.reference);
            }
            await batch.commit();
          }
          await roomDoc.reference.delete();
        }
      }

      // 1. Delete class_schedules
      await deleteSubcollection('class_schedules');

      // 2. Reset classes: clear teacherId, teacherName, subjectQuotas
      final classesSnap = await schoolRef.collection('classes').get();
      for (var i = 0; i < classesSnap.docs.length; i += 400) {
        final batch = db.batch();
        final chunk = classesSnap.docs.skip(i).take(400);
        for (final doc in chunk) {
          batch.update(doc.reference, {
            'teacherId': null,
            'teacherName': null,
            'subjectQuotas': FieldValue.delete(),
          });
        }
        await batch.commit();
      }

      // 3. Reset students: clear classId, className
      final studentsSnap = await schoolRef.collection('students').get();
      for (var i = 0; i < studentsSnap.docs.length; i += 400) {
        final batch = db.batch();
        final chunk = studentsSnap.docs.skip(i).take(400);
        for (final doc in chunk) {
          batch.update(doc.reference, {
            'classId': null,
            'className': null,
          });
        }
        await batch.commit();
      }

      // 4. Delete subject_weights
      await deleteSubcollection('subject_weights');

      // 5. Delete permits
      await deleteSubcollection('permits');

      // 6. Delete behavior_records
      await deleteSubcollection('behavior_records');

      // 7. Delete chat data (chats & parent_chats)
      await deleteChatSubcollection('chats');
      await deleteChatSubcollection('parent_chats');

      // 8. Tandai semester sebagai ditutup
      await schoolRef.update({
        'semesterDitutup': true,
        'tanggalSemesterDitutup': FieldValue.serverTimestamp(),
      });

      // 9. Clear resetRequest field (if this was an approval)
      if (isApproving) {
        await schoolRef.update({'resetRequest': FieldValue.delete()});
      }

      if (mounted) {
        _snack(AppLocalization.semesterEnded);
      }
    } catch (e) {
      if (mounted) _snack('${AppLocalization.semesterEndFailed}: $e');
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

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
    _schoolNameController.dispose();
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
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
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
                          child: ValueListenableBuilder<String>(
                            valueListenable: AppLocalization.currentLocale,
                            builder: (context, locale, _) {
                              return Text(
                                AppLocalization.isIndonesian ? 'Pengaturan' : 'Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: titleColor,
                                ),
                              );
                            },
                          ),
                        ),
                        const LanguageToggleButton(),
                        const SizedBox(width: 8),
                        const ThemeToggleButton(),
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
                            children: [
                              const Icon(Icons.manage_accounts_rounded, size: 17),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  AppLocalization.tabAccountProfile,
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
                            children: [
                              const Icon(Icons.tune_rounded, size: 17),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  AppLocalization.tabSchoolSettings,
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

    final user = SessionService.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cardBorder),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: cardShadow,
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF6366F1), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nama,
                          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Logo ─────────────────────────────────────────────────
          _sectionLabel(AppLocalization.sectionSchoolLogo, Icons.image_outlined, isDark),
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
              AppLocalization.tapToChangeLogo,
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ),

          const SizedBox(height: 32),

          // ── Nama Sekolah ───────────────────────────────────────────
          _sectionLabel(AppLocalization.sectionSchoolName, Icons.school_outlined, isDark),
          const SizedBox(height: 16),
          TextFormField(
            controller: _schoolNameController,
            style: TextStyle(color: textPrimary, fontSize: 14),
            decoration: InputDecoration(
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              filled: true,
              hintText: AppLocalization.enterSchoolName,
              hintStyle: TextStyle(color: textSecondary, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cardBorder),
              ),
              prefixIcon: Icon(Icons.school_rounded, color: const Color(0xFF6366F1), size: 20),
            ),
          ),
          const SizedBox(height: 32),

          // ── Password ──────────────────────────────────────────────
          _sectionLabel(AppLocalization.sectionAccountSecurity, Icons.shield_outlined, isDark),
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
                      AppLocalization.changePassword,
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
                  AppLocalization.leaveBlankPassword,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 20),

                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: AppLocalization.currentPassword,
                  obscure: _obscureCurrent,
                  onToggle: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  isDark: isDark,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                _buildPasswordField(
                  controller: _passwordController,
                  label: AppLocalization.newPassword,
                  obscure: _obscurePass,
                  onToggle: () =>
                      setState(() => _obscurePass = !_obscurePass),
                  isDark: isDark,
                  onChanged: (_) => setState(() {}),
                ),
                _buildPasswordRequirements(_passwordController.text, isDark),
                const SizedBox(height: 14),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: AppLocalization.confirmPassword,
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  isConfirm: true,
                  isDark: isDark,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Save button (Profil) ──────────────────────────────────
          Builder(
            builder: (context) {
              final currentPass = _currentPasswordController.text;
              final newPass = _passwordController.text;
              final confirmPass = _confirmPasswordController.text;

              bool canSubmit = true;
              if (newPass.isNotEmpty) {
                final hasUppercase = RegExp(r'[A-Z]').hasMatch(newPass);
                final hasLowercase = RegExp(r'[a-z]').hasMatch(newPass);
                final hasNumber = RegExp(r'[0-9]').hasMatch(newPass);
                final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(newPass);
                final isNewPasswordValid = newPass.length >= 6 && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;
                
                canSubmit = currentPass.isNotEmpty && isNewPasswordValid && confirmPass == newPass;
              }

              return _buildSaveButton(
                label: AppLocalization.saveAccountProfile,
                icon: Icons.person_rounded,
                isSaving: _isSavingAkun,
                onPressed: _saveAkun,
                enabled: canSubmit,
              );
            },
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

          _sectionLabel(AppLocalization.sectionGradeThreshold, Icons.speed_rounded, isDark),
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
                        AppLocalization.minPredicateThreshold,
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
                  AppLocalization.gradePredicateSubtitle,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 24),

                // ── Predikat A ────────────────────────────────────
                _gradeGroupLabel(AppLocalization.gradeA, const Color(0xFF10B981), isDark),
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
                _gradeGroupLabel(AppLocalization.gradeB, const Color(0xFF3B82F6), isDark),
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
                _gradeGroupLabel(AppLocalization.gradeC, const Color(0xFFF59E0B), isDark),
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
                          AppLocalization.infoMinScore,
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
          _sectionLabel(AppLocalization.sectionAcademicCalendar, Icons.calendar_today_rounded, isDark),
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
                        AppLocalization.calendarConfigTitle,
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
                  AppLocalization.calendarConfigSubtitle,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
                const SizedBox(height: 20),

                // Tahun Ajaran Input
                Text(
                  AppLocalization.academicYear,
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
                  AppLocalization.activeSemester,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'Semester 1',
                        label: Text(AppLocalization.isIndonesian ? 'Semester 1' : 'Semester 1'),
                        icon: const Icon(Icons.looks_one_rounded),
                      ),
                      ButtonSegment(
                        value: 'Semester 2',
                        label: Text(AppLocalization.isIndonesian ? 'Semester 2' : 'Semester 2'),
                        icon: const Icon(Icons.looks_two_rounded),
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
                  AppLocalization.schoolHours,
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

                const SizedBox(height: 20),

                // ── Tanggal Mulai Semester ──────────────────────────────
                Text(
                  AppLocalization.semesterStartDate,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalization.semesterStartDateSubtitle,
                  style: TextStyle(fontSize: 11, color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _tanggalMulaiSemester ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: ColorScheme.fromSeed(
                                  seedColor: const Color(0xFF6366F1),
                                  brightness: isDark ? Brightness.dark : Brightness.light,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setState(() => _tanggalMulaiSemester = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _tanggalMulaiSemester != null
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                                  : cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_rounded,
                                color: _tanggalMulaiSemester != null
                                    ? const Color(0xFF6366F1)
                                    : textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _tanggalMulaiSemester != null
                                      ? '${_tanggalMulaiSemester!.day.toString().padLeft(2, '0')}'
                                        '/${_tanggalMulaiSemester!.month.toString().padLeft(2, '0')}'
                                        '/${_tanggalMulaiSemester!.year}'
                                      : AppLocalization.selectStartDate,
                                  style: TextStyle(
                                    color: _tanggalMulaiSemester != null ? textPrimary : textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (_tanggalMulaiSemester != null)
                                const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_tanggalMulaiSemester != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: AppLocalization.deleteStartDate,
                        onPressed: () => setState(() => _tanggalMulaiSemester = null),
                        icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _buildSemesterStatusBadge(isDark),

              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Save button (Nilai) ───────────────────────────────────
          _buildSaveButton(
            label: AppLocalization.saveSchoolSettings,
            icon: Icons.save_rounded,
            isSaving: _isSavingNilai,
            onPressed: _saveNilai,
          ),

          const SizedBox(height: 40),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 32),

          // ── Akhiri Semester ───────────────────────────────────────
          _buildEndSemesterSection(isDark),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  SECTION — Akhiri Semester
  // ════════════════════════════════════════════════════════════════════
  Widget _buildEndSemesterSection(bool isDark) {
    final user = SessionService.currentUser;
    if (user == null) return const SizedBox.shrink();
    final role = user.role; // 'school_admin' or 'tu'
    final isAdmin = role == 'school_admin';

    final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondary = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final hasPendingRequest = _resetRequest != null && _resetRequest!['status'] == 'pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(AppLocalization.sectionEndSemester, Icons.flag_rounded, isDark),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restart_alt_rounded, color: Colors.red, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalization.resetAcademicConfig,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalization.resetAcademicSubtitle,
                style: TextStyle(fontSize: 12, color: textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),

              // ── Banner: TU — sudah ada pengajuan pending ──────────
              if (!isAdmin && hasPendingRequest)
                _buildPendingBannerTu(isDark, textPrimary, textSecondary)

              // ── Banner: Admin — ada pengajuan TU menunggu ─────────
              else if (isAdmin && hasPendingRequest)
                _buildApprovalBannerAdmin(isDark, textPrimary)

              // ── Button: TU — belum ada pengajuan ──────────────────
              else if (!isAdmin)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmittingRequest ? null : _submitResetRequest,
                    icon: _isSubmittingRequest
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(_isSubmittingRequest ? AppLocalization.sending : AppLocalization.proposeEndSemester),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )

              // ── Button: Admin — tidak ada pengajuan, inisiasi sendiri ─
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isResetting ? null : () => _confirmAndExecuteReset(),
                    icon: _isResetting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.flag_rounded, size: 18),
                    label: Text(_isResetting ? AppLocalization.resetting : AppLocalization.endSemesterNow),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingBannerTu(bool isDark, Color textPrimary, Color textSecondary) {
    final req = _resetRequest!;
    final requestedAt = (req['requestedAt'] as Timestamp?)?.toDate();
    final dateStr = requestedAt != null
        ? '${requestedAt.day}/${requestedAt.month}/${requestedAt.year} ${requestedAt.hour.toString().padLeft(2, '0')}:${requestedAt.minute.toString().padLeft(2, '0')}'
        : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalization.submissionSent,
                  style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${AppLocalization.waitingAdminApproval}${ dateStr.isNotEmpty ? '\n${AppLocalization.isIndonesian ? "Dikirim" : "Sent"}: $dateStr' : ''}',
                  style: TextStyle(color: const Color(0xFFF59E0B).withValues(alpha: 0.8), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalBannerAdmin(bool isDark, Color textPrimary) {
    final req = _resetRequest!;
    final requesterName = req['requestedByName'] ?? 'Tata Usaha';
    final tahunAjaran = req['tahunAjaran'] ?? _tahunAjaranController.text;
    final semester = req['semester'] ?? _activeSemester;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inbox_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.incomingSubmission,
                      style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      AppLocalization.proposeEndSemesterMsg(requesterName, semester, tahunAjaran),
                      style: TextStyle(color: const Color(0xFF6366F1).withValues(alpha: 0.8), fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isResetting ? null : _cancelResetRequest,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(AppLocalization.reject),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isResetting ? null : () => _confirmAndExecuteReset(isApproving: true),
                icon: _isResetting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(_isResetting ? AppLocalization.resetting : AppLocalization.approveEndSemester),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
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
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? const [Color(0xFF6366F1), Color(0xFF8B5CF6)]
              : [Colors.grey.shade400, Colors.grey.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: (isSaving || !enabled) ? null : onPressed,
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
    ValueChanged<String>? onChanged,
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
        onChanged: onChanged,
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

  Widget _buildPasswordRequirements(String password, bool isDark) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

    final activeColor = const Color(0xFF10B981);
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    final itemTextColor = isDark ? Colors.white70 : Colors.black87;

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
                color: isMet ? activeColor : itemTextColor,
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
          buildItem(AppLocalization.passwordValidationMinLength, password.length >= 6),
          buildItem(AppLocalization.passwordValidationUppercase, hasUppercase),
          buildItem(AppLocalization.passwordValidationLowercase, hasLowercase),
          buildItem(AppLocalization.passwordValidationNumber, hasNumber),
          buildItem(AppLocalization.passwordValidationSpecialChar, hasSpecialChar),
        ],
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
  Widget _buildSemesterStatusBadge(bool isDark) {
    final status = SemesterStateService.status;
    final Color color;
    final IconData icon;
    final String label;
    final String desc;

    switch (status) {
      case SemesterStatus.aktif:
        color = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        label = AppLocalization.isIndonesian ? 'Semester Aktif' : 'Active Semester';
        desc = AppLocalization.isIndonesian ? 'Input absensi, nilai, dan perizinan dapat dilakukan.' : 'Attendance, grade, and permit input is allowed.';
        break;
      case SemesterStatus.liburan:
        final d = SemesterStateService.tanggalMulai;
        final dateStr = d != null
            ? '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'
            : '';
        color = const Color(0xFFF59E0B);
        icon = Icons.beach_access_rounded;
        label = AppLocalization.isIndonesian ? 'Masa Liburan' : 'Holiday Period';
        desc = AppLocalization.isIndonesian ? 'Input data ditolak hingga $dateStr.' : 'Data input is rejected until $dateStr.';
        break;
      case SemesterStatus.ditutup:
        color = Colors.red;
        icon = Icons.lock_rounded;
        label = AppLocalization.isIndonesian ? 'Semester Ditutup' : 'Semester Closed';
        desc = AppLocalization.isIndonesian ? 'Admin telah menutup semester ini. Input data tidak dapat dilakukan.' : 'The admin has closed this semester. Data input cannot be performed.';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $label',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
