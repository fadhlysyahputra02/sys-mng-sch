import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/services/app_auth_service.dart';
import '../../../core/services/auth_service.dart';
import '../../schools/services/school_service.dart';
import '../../authentication/widgets/auth_background.dart';
import 'school_users_detail_page.dart';

class RegisterSchoolPage extends StatefulWidget {
  const RegisterSchoolPage({super.key});

  @override
  State<RegisterSchoolPage> createState() => _RegisterSchoolPageState();
}

class _RegisterSchoolPageState extends State<RegisterSchoolPage> {
  final namaSekolahController = TextEditingController();
  final schoolIdController = TextEditingController();
  final _searchController = TextEditingController();

  final schoolService = SchoolService();
  final authService = AuthService();

  // Selected plan defaults to free, but no longer customizable in UI
  String selectedPlan = 'free';
  String? generatedAdminCode;
  bool _isLoading = false;
  int _currentTab = 0; // 0 for Registration, 1 for Management
  String _searchQuery = '';

  bool get _isDark => AuthBackground.isDarkMode.value;
  Color get _textColor => _isDark ? Colors.white : Colors.black;
  Color get _subTextColor => _isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.6);
  Color get _cardBgColor => _isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
  Color get _borderColor => _isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
  Color get _inputFillColor => _isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.03);

  @override
  void dispose() {
    namaSekolahController.dispose();
    schoolIdController.dispose();
    _searchController.dispose();
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
          color: (isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  String generateAdminCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ADM-${timestamp.toString().substring(7)}';
  }

  Future<void> simpanSekolah() async {
    final namaSekolah = namaSekolahController.text.trim();
    final schoolId = schoolIdController.text.trim().toLowerCase();
    final domain = schoolId;

    if (namaSekolah.isEmpty || schoolId.isEmpty) {
      _showNotification(
        title: 'Gagal',
        message: 'Semua field wajib diisi',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final adminCode = generateAdminCode();

      await schoolService.createSchool(
        schoolId: schoolId,
        namaSekolah: namaSekolah,
        domain: domain,
        kodeAdmin: adminCode,
        plan: 'free',
      );

      setState(() {
        generatedAdminCode = adminCode;
      });

      if (mounted) {
        _showNotification(
          title: 'Berhasil',
          message: 'Sekolah berhasil didaftarkan!',
          isSuccess: true,
        );
        namaSekolahController.clear();
        schoolIdController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showNotification(
          title: 'Gagal Menyimpan',
          message: e.toString().replaceAll('Exception: ', ''),
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  void _showQuotaDialog(Map<String, dynamic> school) {
    int? tempTeacherQuota = school['teacherQuota'] as int?;
    int? tempStudentQuota = school['studentQuota'] as int?;

    final teacherController = TextEditingController(
        text: tempTeacherQuota != null ? tempTeacherQuota.toString() : '');
    final studentController = TextEditingController(
        text: tempStudentQuota != null ? tempStudentQuota.toString() : '');

    bool isTeacherUnlimited = tempTeacherQuota == null;
    bool isStudentUnlimited = tempStudentQuota == null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151026),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 28,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'PENGATURAN KUOTA USER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Atur batas kuota guru dan murid aktif untuk ${school['namaSekolah']}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Kuota Guru
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kuota Guru',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Tidak Terbatas',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Checkbox(
                            value: isTeacherUnlimited,
                            activeColor: const Color(0xFF8B5CF6),
                            checkColor: Colors.white,
                            onChanged: (val) {
                              setModalState(() {
                                isTeacherUnlimited = val ?? false;
                                if (isTeacherUnlimited) {
                                  teacherController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isTeacherUnlimited) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: teacherController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Masukkan batas kuota guru...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.02),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Kuota Murid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kuota Murid Aktif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Tidak Terbatas',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Checkbox(
                            value: isStudentUnlimited,
                            activeColor: const Color(0xFF8B5CF6),
                            checkColor: Colors.white,
                            onChanged: (val) {
                              setModalState(() {
                                isStudentUnlimited = val ?? false;
                                if (isStudentUnlimited) {
                                  studentController.clear();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isStudentUnlimited) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: studentController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Masukkan batas kuota murid...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.02),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        final teacherText = teacherController.text.trim();
                        final studentText = studentController.text.trim();
                        
                        final int? tQuota = isTeacherUnlimited ? null : int.tryParse(teacherText);
                        final int? sQuota = isStudentUnlimited ? null : int.tryParse(studentText);
                        
                        if (!isTeacherUnlimited && (tQuota == null || tQuota <= 0)) {
                          _showNotification(
                            title: 'Gagal',
                            message: 'Kuota guru harus berupa angka positif',
                            isSuccess: false,
                          );
                          return;
                        }
                        
                        if (!isStudentUnlimited && (sQuota == null || sQuota <= 0)) {
                          _showNotification(
                            title: 'Gagal',
                            message: 'Kuota murid harus berupa angka positif',
                            isSuccess: false,
                          );
                          return;
                        }
                        
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        try {
                          await schoolService.updateSchoolQuotas(
                            domain: school['domain'],
                            teacherQuota: tQuota,
                            studentQuota: sQuota,
                          );
                          _showNotification(
                            title: 'Berhasil',
                            message: 'Kuota user untuk ${school['namaSekolah']} berhasil disimpan!',
                            isSuccess: true,
                          );
                        } catch (e) {
                          final cleanMsg = e.toString()
                              .replaceAll('Exception: ', '')
                              .replaceAll('Exception ', '');
                          _showNotification(
                            title: 'Gagal',
                            message: cleanMsg,
                            isSuccess: false,
                          );
                        } finally {
                          setState(() => _isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'SIMPAN PERUBAHAN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
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

  Future<void> _toggleBypassScheduleLock(Map<String, dynamic> school) async {
    final bool currentBypass = school['allowBypassScheduleLock'] ?? false;
    final bool nextBypass = !currentBypass;
    
    setState(() => _isLoading = true);
    try {
      await schoolService.updateBypassScheduleLock(
        domain: school['domain'],
        allowBypass: nextBypass,
      );
      _showNotification(
        title: 'Berhasil',
        message: nextBypass 
            ? 'Bypass kunci jadwal ${school['namaSekolah']} diaktifkan!' 
            : 'Kunci jadwal ${school['namaSekolah']} diaktifkan kembali!',
        isSuccess: true,
      );
    } catch (e) {
      _showNotification(
        title: 'Gagal',
        message: e.toString(),
        isSuccess: false,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword(Map<String, dynamic> school) async {
    setState(() => _isLoading = true);
    try {
      final admin = await schoolService.getSchoolAdmin(school['domain']);
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (admin == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF151026),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Admin Belum Terdaftar', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin untuk sekolah ${school['namaSekolah']} belum mendaftar di sistem.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kode Registrasi Admin:',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              school['kodeAdmin'] ?? '-',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: school['kodeAdmin'] ?? ''));
                          _showNotification(
                            title: 'Disalin',
                            message: 'Kode admin disalin ke clipboard',
                            isSuccess: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        );
      } else {
        final email = admin['email'] ?? '';
        final nama = admin['nama'] ?? '';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF151026),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Reset Password Admin', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kirim email instruksi reset password kepada admin sekolah:',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                Text('Nama: $nama', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('Email: $email', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    await authService.sendPasswordResetEmail(email);
                    _showNotification(
                      title: 'Berhasil',
                      message: 'Email reset password telah dikirim ke $email',
                      isSuccess: true,
                    );
                  } catch (e) {
                    _showNotification(
                      title: 'Gagal',
                      message: e.toString(),
                      isSuccess: false,
                    );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
                child: const Text('Kirim Email Reset', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showNotification(
        title: 'Error',
        message: e.toString(),
        isSuccess: false,
      );
    }
  }

  void _confirmDeleteSchool(Map<String, dynamic> school) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF151026),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    color: Color(0xFFEF4444),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Hapus Sekolah?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // School name badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    school['namaSekolah'] ?? 'Sekolah',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Warning description
                const Text(
                  'Tindakan ini akan menghapus semua data sekolah, murid, guru, dan riwayat terkait secara PERMANEN dan tidak dapat dikembalikan.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showSecretCodeVerification(school);
                        },
                        child: const Text(
                          'Lanjutkan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSecretCodeVerification(Map<String, dynamic> school) {
    final codeController = TextEditingController();
    bool obscureCode = true;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: const Color(0xFF151026),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shield icon
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFF59E0B),
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'Verifikasi Keamanan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    const Text(
                      'Masukkan kode rahasia Super Admin untuk mengkonfirmasi penghapusan permanen ini.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Secret code input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: errorText != null
                              ? const Color(0xFFEF4444)
                              : Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: TextField(
                        controller: codeController,
                        obscureText: obscureCode,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '••••••',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.25),
                            letterSpacing: 6,
                            fontSize: 18,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: errorText != null
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFF59E0B),
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCode
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.white38,
                              size: 20,
                            ),
                            onPressed: () {
                              setModalState(() => obscureCode = !obscureCode);
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (_) {
                          if (errorText != null) {
                            setModalState(() => errorText = null);
                          }
                        },
                      ),
                    ),

                    // Error message
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            errorText!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white.withOpacity(0.15)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              codeController.dispose();
                              Navigator.pop(dialogContext);
                            },
                            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              const secretCode = '081987';
                              if (codeController.text.trim() != secretCode) {
                                setModalState(() {
                                  errorText = 'Kode rahasia tidak valid!';
                                });
                                return;
                              }

                              // Code correct — proceed
                              codeController.dispose();
                              Navigator.pop(dialogContext);
                              setState(() => _isLoading = true);
                              try {
                                await schoolService.deleteSchool(school['domain']);
                                _showNotification(
                                  title: 'Berhasil',
                                  message: 'Sekolah "${school['namaSekolah']}" berhasil dihapus!',
                                  isSuccess: true,
                                );
                              } catch (e) {
                                _showNotification(
                                  title: 'Gagal',
                                  message: e.toString(),
                                  isSuccess: false,
                                );
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                            child: const Text(
                              'Hapus',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _currentTab == index;
    final activeTabBg = _isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final activeTabBorder = _isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1);
    final tabTextColor = isSelected ? _textColor : _textColor.withValues(alpha: 0.5);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeTabBg : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? activeTabBorder : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: tabTextColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: tabTextColor,
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
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E1B4B),
            elevation: 0,
            title: const Text(
              'SUPER ADMIN PANEL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: () async {
                  await AppAuthService.logout();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              AuthBackground(
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
                            color: _isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _borderColor,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                blurRadius: 20,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _currentTab == 0 ? Icons.domain_add_rounded : Icons.list_alt_rounded,
                            size: 44,
                            color: _textColor,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          _currentTab == 0 ? 'REGISTER SEKOLAH' : 'KELOLA SEKOLAH',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _textColor,
                            letterSpacing: 2.0,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _currentTab == 0
                              ? 'Daftarkan institusi sekolah baru ke dalam sistem'
                              : 'Kelola langganan, reset password admin, atau hapus sekolah terdaftar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _subTextColor,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Custom Sliding Tab Selector
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildTabButton(0, 'Pendaftaran', Icons.domain_add_rounded),
                              const SizedBox(width: 8),
                              _buildTabButton(1, 'Kelola Sekolah', Icons.list_alt_rounded),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Content based on tab
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _currentTab == 0 ? _buildRegistrationForm() : _buildManagementList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      key: const ValueKey(0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: _isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nama Sekolah
          TextField(
            controller: namaSekolahController,
            style: TextStyle(color: _textColor),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Nama Sekolah',
              labelStyle: TextStyle(color: _subTextColor),
              prefixIcon: Icon(
                Icons.account_balance_rounded,
                color: _subTextColor,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _borderColor,
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
              fillColor: _inputFillColor,
            ),
          ),

          const SizedBox(height: 18),

          // School ID
          TextField(
            controller: schoolIdController,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              labelText: 'School ID (Domain)',
              hintText: 'ex: smpn1jakarta',
              hintStyle: TextStyle(color: _subTextColor.withValues(alpha: 0.5)),
              labelStyle: TextStyle(color: _subTextColor),
              prefixIcon: Icon(
                Icons.link_rounded,
                color: _subTextColor,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _borderColor,
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
              fillColor: _inputFillColor,
            ),
          ),

          const SizedBox(height: 24),



          const SizedBox(height: 32),

          // Tombol Simpan
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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : simpanSekolah,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'SIMPAN SEKOLAH',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          if (generatedAdminCode != null) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Kode Registrasi Admin',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SelectableText(
                        generatedAdminCode!,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.copy_rounded, color: _subTextColor, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: generatedAdminCode!));
                          _showNotification(
                            title: 'Disalin',
                            message: 'Kode berhasil disalin ke clipboard',
                            isSuccess: true,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Berikan kode ini kepada Admin Sekolah untuk mendaftar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _subTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementList() {
    return Container(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: 'Cari nama sekolah atau domain...',
              hintStyle: TextStyle(color: _subTextColor),
              prefixIcon: Icon(Icons.search_rounded, color: _subTextColor),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: _subTextColor),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _borderColor,
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
              fillColor: _inputFillColor,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 20),

          StreamBuilder<List<Map<String, dynamic>>>(
            stream: schoolService.getSchoolsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }

              final schools = snapshot.data ?? [];

              // Filter based on search query
              final filteredSchools = schools.where((school) {
                final name = (school['namaSekolah'] ?? '').toString().toLowerCase();
                final domain = (school['domain'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || domain.contains(_searchQuery);
              }).toList();

              if (filteredSchools.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: _subTextColor.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sekolah tidak ditemukan',
                          style: TextStyle(
                            color: _subTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Limit to 3 if no search query
              final displayedSchools = _searchQuery.isEmpty
                  ? filteredSchools.take(3).toList()
                  : filteredSchools;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedSchools.length,
                    itemBuilder: (context, index) {
                      final school = displayedSchools[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _cardBgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _borderColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => Get.to(() => SchoolUsersDetailPage(school: school)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          school['namaSekolah'] ?? '',
                                          style: TextStyle(
                                            color: _textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      // Removed plan badge display
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Domain: ${school['domain'] ?? ''}',
                                    style: TextStyle(
                                      color: _subTextColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Kode Admin: ',
                                        style: TextStyle(
                                          color: _subTextColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        school['kodeAdmin'] ?? '',
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.end,
                                     children: [
                                       // Toggle Bypass Schedule Lock (Icon Only)
                                       Builder(
                                         builder: (context) {
                                           final bool allowBypass = school['allowBypassScheduleLock'] ?? false;
                                           return Container(
                                             decoration: BoxDecoration(
                                               color: allowBypass
                                                   ? const Color(0xFF10B981).withValues(alpha: 0.1)
                                                   : Colors.grey.withValues(alpha: 0.1),
                                               shape: BoxShape.circle,
                                               border: Border.all(
                                                 color: allowBypass
                                                     ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                                     : Colors.grey.withValues(alpha: 0.2),
                                               ),
                                             ),
                                             child: IconButton(
                                               icon: Icon(
                                                 allowBypass ? Icons.lock_open_rounded : Icons.lock_rounded,
                                                 color: allowBypass ? const Color(0xFF10B981) : Colors.grey,
                                                 size: 20,
                                               ),
                                               tooltip: allowBypass ? 'Kunci Jadwal (Aktif)' : 'Bypass Kunci Jadwal (Nonaktif)',
                                               onPressed: () => _toggleBypassScheduleLock(school),
                                               constraints: const BoxConstraints(),
                                               padding: const EdgeInsets.all(8),
                                             ),
                                           );
                                         }
                                       ),
                                       const SizedBox(width: 10),
                                       // Edit Quota button (Icon Only)
                                       Container(
                                         decoration: BoxDecoration(
                                           color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                           shape: BoxShape.circle,
                                           border: Border.all(
                                             color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                           ),
                                         ),
                                         child: IconButton(
                                           icon: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF8B5CF6), size: 20),
                                           tooltip: 'Atur Kuota User',
                                           onPressed: () => _showQuotaDialog(school),
                                           constraints: const BoxConstraints(),
                                           padding: const EdgeInsets.all(8),
                                         ),
                                       ),
                                       const SizedBox(width: 10),
                                      // Reset Password Admin button (Icon Only)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.vpn_key_rounded, color: Color(0xFF6366F1), size: 20),
                                          tooltip: 'Reset Password Admin',
                                          onPressed: () => _handleResetPassword(school),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Delete school button (Icon Only)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 20),
                                          tooltip: 'Hapus Sekolah',
                                          onPressed: () => _confirmDeleteSchool(school),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
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
                  if (_searchQuery.isEmpty && filteredSchools.length > 3) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _borderColor,
                        ),
                      ),
                      child: Text(
                        'Menampilkan 3 dari ${filteredSchools.length} sekolah. Gunakan pencarian untuk menemukan sekolah lainnya.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _subTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

