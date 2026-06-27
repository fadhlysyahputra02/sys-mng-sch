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
        plan: selectedPlan,
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

  void _showPlanDialog(Map<String, dynamic> school) {
    String tempPlan = school['plan'] ?? 'free';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151026),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget planOption(String plan, String label, IconData icon, Color activeColor) {
              final isSelected = tempPlan == plan;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setModalState(() => tempPlan = plan),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.5),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
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

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ATUR PAKET LANGGANAN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Atur paket langganan untuk ${school['namaSekolah']}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      planOption('free', 'Free', Icons.star_outline_rounded, Colors.white70),
                      const SizedBox(width: 8),
                      planOption('basic', 'Basic', Icons.star_half_rounded, const Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      planOption('pro', 'Pro', Icons.star_rounded, const Color(0xFFF59E0B)),
                    ],
                  ),
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
                        Navigator.pop(context);
                        setState(() => _isLoading = true);
                        try {
                          await schoolService.updateSchoolPlan(
                            domain: school['domain'],
                            plan: tempPlan,
                          );
                          _showNotification(
                            title: 'Berhasil',
                            message: 'Paket langganan ${school['namaSekolah']} diupdate ke ${tempPlan.toUpperCase()}!',
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151026),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Hapus Sekolah?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus sekolah "${school['namaSekolah']}"? Aksi ini akan menghapus semua data sekolah dan pengguna terkait secara permanen.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
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
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

  Widget _planCard(String plan, String label, IconData icon, Color activeColor) {
    final isSelected = selectedPlan == plan;
    final cardBorder = _isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final unselectedBg = _isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedPlan = plan),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.15) : unselectedBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? activeColor : cardBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? activeColor : _textColor.withValues(alpha: 0.5),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _textColor : _textColor.withValues(alpha: 0.5),
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

  Widget _buildPlanBadge(String plan) {
    Color badgeColor;
    String label;
    switch (plan.toLowerCase()) {
      case 'pro':
        badgeColor = const Color(0xFFF59E0B);
        label = 'Pro';
        break;
      case 'basic':
        badgeColor = const Color(0xFF3B82F6);
        label = 'Basic';
        break;
      default:
        badgeColor = _isDark ? Colors.white54 : Colors.grey;
        label = 'Free';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
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

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Paket Langganan',
              style: TextStyle(
                color: _subTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Row(
            children: [
              _planCard('free', 'Free', Icons.star_outline_rounded, _isDark ? Colors.white70 : Colors.grey),
              const SizedBox(width: 8),
              _planCard('basic', 'Basic', Icons.star_half_rounded, const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _planCard('pro', 'Pro', Icons.star_rounded, const Color(0xFFF59E0B)),
            ],
          ),

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
                                      _buildPlanBadge(school['plan'] ?? 'free'),
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
                                      // Edit Plan button (Icon Only)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
                                          tooltip: 'Atur Paket Langganan',
                                          onPressed: () => _showPlanDialog(school),
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

