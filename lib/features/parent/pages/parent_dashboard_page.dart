import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/services/app_auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/services/school_service.dart';
import '../../students/widgets/monthly_attendance_table_section.dart';
import '../widgets/parent_student_grades_section.dart';

class ParentDashboardPage extends StatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  State<ParentDashboardPage> createState() => _ParentDashboardPageState();
}

class _ParentDashboardPageState extends State<ParentDashboardPage> {
  final _scrollController = ScrollController();
  final _infoKey = GlobalKey();
  final _attendanceKey = GlobalKey();
  final _violationKey = GlobalKey();
  final _gradesKey = GlobalKey();

  Map<String, dynamic>? _parentData;
  String? _schoolName;
  String? _tahunAjaran;
  String? _semester;
  String? _studentClassId;
  String? _waliKelas;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = SessionService.currentUser;
    if (user == null) return;

    try {
      final parentDocFuture = FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .collection('parents')
          .doc(user.uid)
          .get();
      final schoolDataFuture = SchoolService().getSchoolByDomain(user.schoolId);

      final parentDoc = await parentDocFuture;
      final schoolData = await schoolDataFuture;
      final parentData = parentDoc.data();
      final studentId = (parentData?['studentId'] ?? '').toString();

      String? classId;
      String? waliKelas;
      if (studentId.isNotEmpty) {
        final studentDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(user.schoolId)
            .collection('students')
            .doc(studentId)
            .get();
        classId = studentDoc.data()?['classId'] as String?;

        if (classId != null && classId.isNotEmpty) {
          final classDoc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(user.schoolId)
              .collection('classes')
              .doc(classId)
              .get();
          // Field yang tersimpan adalah 'teacherId' dan 'teacherName'
          // (bukan 'waliKelasId') — lihat class_service.dart assignWaliKelas()
          final teacherId = classDoc.data()?['teacherId'] as String?;
          // Gunakan teacherName dari class doc sebagai nilai cepat
          waliKelas = classDoc.data()?['teacherName'] as String?;
          // Jika teacherName kosong, ambil dari koleksi teachers berdasarkan teacherId
          if ((waliKelas == null || waliKelas!.isEmpty) &&
              teacherId != null &&
              teacherId.isNotEmpty) {
            final teacherDoc = await FirebaseFirestore.instance
                .collection('schools')
                .doc(user.schoolId)
                .collection('teachers')
                .doc(teacherId)
                .get();
            waliKelas = teacherDoc.data()?['nama'] as String?;
          }
        }
      }

      if (mounted) {
        setState(() {
          _parentData = parentData;
          _schoolName = schoolData?['namaSekolah'] as String?;
          _tahunAjaran = schoolData?['tahunAjaran'] as String?;
          _semester = schoolData?['semester'] as String?;
          _studentClassId = classId;
          _waliKelas = waliKelas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour <= 10) return 'Selamat Pagi';
    if (hour <= 14) return 'Selamat Siang';
    if (hour <= 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Future<void> _logout() async {
    final isDark = AuthBackground.isDarkMode.value;
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar Akun',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E1B4B),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar?',
          style: TextStyle(
            color: isDark
                ? Colors.white70
                : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) await AppAuthService.logout();
  }

  @override
  Widget build(BuildContext context) {
    if (SessionService.currentUser == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.login));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg =
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                      ),
                    )
                  : CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // --- HEADER SECTION ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getGreeting(),
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        user.nama,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _logout,
                                  icon: Icon(Icons.power_settings_new_rounded,
                                      color: const Color(0xFFEF4444)),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- HERO STUDENT CARD ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.2),
                                        child: Text(
                                          (_parentData?['studentName']?[0] ??
                                              'A'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'Siswa Terhubung',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _parentData?['studentName'] ?? '-',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'Kelas ${_parentData?['className'] ?? '-'}',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.8),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.2)),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _heroSmallInfo(
                                          Icons.business_rounded,
                                          _schoolName ?? 'Sekolah'),
                                      _heroSmallInfo(
                                          Icons.calendar_today_rounded,
                                          _tahunAjaran ?? '-'),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.event_note_rounded,
                                            color: Colors.white.withValues(alpha: 0.8),
                                            size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Semester ${_semester ?? '-'} • Tahun Ajaran ${_tahunAjaran ?? '-'}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- MENU GRID ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Menu Utama',
                                  Icons.dashboard_rounded,
                                  textColor,
                                  subTextColor,
                                ),
                                const SizedBox(height: 16),
                                _buildMenuGrid(isDark, textColor, cardBg, cardBorder),
                              ],
                            ),
                          ),
                        ),

                        // --- DETAIL INFO SECTION ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                            child: Column(
                              key: _infoKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Informasi Tambahan',
                                  Icons.info_outline_rounded,
                                  textColor,
                                  subTextColor,
                                ),
                                const SizedBox(height: 16),
                                _gridCard(
                                  icon: Icons.person_pin_rounded,
                                  label: 'Wali Kelas',
                                  value: _waliKelas ?? 'Belum tersedia',
                                  color: const Color(0xFF6366F1),
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  cardBorder: cardBorder,
                                  textColor: textColor,
                                  subTextColor: subTextColor,
                                  fullWidth: true,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- ATTENDANCE SECTION ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                            child: Column(
                              key: _attendanceKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Daftar Hadir Anak',
                                  Icons.fact_check_rounded,
                                  textColor,
                                  subTextColor,
                                ),
                                const SizedBox(height: 16),
                                MonthlyAttendanceTableSection(
                                  schoolId: user.schoolId,
                                  studentId: (_parentData?['studentId'] ?? '')
                                      .toString(),
                                  className: (_parentData?['className'] ?? '-')
                                      .toString(),
                                  studentName: (_parentData?['studentName'] ?? 'Anak')
                                      .toString(),
                                  isDark: isDark,
                                  textColor: textColor,
                                  subTextColor: subTextColor,
                                  cardBg: cardBg,
                                  cardBorder: cardBorder,
                                  showTitle: false,
                                  embedded: true,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- VIOLATION SECTION ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                            child: Column(
                              key: _violationKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Laporan Pelanggaran',
                                  Icons.warning_amber_rounded,
                                  textColor,
                                  subTextColor,
                                ),
                                const SizedBox(height: 16),
                                _ViolationCard(
                                  schoolId: user.schoolId,
                                  studentId: (_parentData?['studentId'] ?? '')
                                      .toString(),
                                  isDark: isDark,
                                  textColor: textColor,
                                  subTextColor: subTextColor,
                                  cardBg: cardBg,
                                  cardBorder: cardBorder,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- GRADES SECTION ---
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                            child: Column(
                              key: _gradesKey,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Laporan Nilai Anak',
                                  Icons.analytics_rounded,
                                  textColor,
                                  subTextColor,
                                ),
                                const SizedBox(height: 16),
                                _studentClassId != null &&
                                        _studentClassId!.isNotEmpty &&
                                        _tahunAjaran != null &&
                                        _semester != null
                                    ? ParentStudentGradesSection(
                                        schoolId: user.schoolId,
                                        studentId:
                                            (_parentData?['studentId'] ?? '')
                                                .toString(),
                                        classId: _studentClassId!,
                                        className:
                                            (_parentData?['className'] ?? '-')
                                                .toString(),
                                        tahunAjaran: _tahunAjaran!,
                                        semester: _semester!,
                                        isDark: isDark,
                                        textColor: textColor,
                                        subTextColor: subTextColor,
                                        cardBg: cardBg,
                                        cardBorder: cardBorder,
                                      )
                                    : Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: cardBg,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: cardBorder),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.info_outline_rounded,
                                                color: subTextColor, size: 32),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Data kelas anak belum lengkap.\nLaporan nilai belum tersedia.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: subTextColor,
                                                fontSize: 13,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color textColor,
    Color subTextColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: subTextColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  Widget _buildMenuGrid(
    bool isDark,
    Color textColor,
    Color cardBg,
    Color cardBorder,
  ) {
    final menus = [
      {
        'title': 'Daftar Hadir',
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFF10B981),
        'key': _attendanceKey,
      },
      {
        'title': 'Pelanggaran',
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFEF4444),
        'key': _violationKey,
      },
      {
        'title': 'Nilai Anak',
        'icon': Icons.grade_rounded,
        'color': const Color(0xFF8B5CF6),
        'key': _gradesKey,
      },
      {
        'title': 'Informasi',
        'icon': Icons.info_outline_rounded,
        'color': const Color(0xFF6366F1),
        'key': _infoKey,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final menu = menus[index];
        final color = menu['color'] as Color;
        final sectionKey = menu['key'] as GlobalKey;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _scrollToSection(sectionKey),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      menu['icon'] as IconData,
                      color: color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    menu['title'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heroSmallInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _gridCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color textColor,
    required Color subTextColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: fullWidth
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style:
                              TextStyle(color: subTextColor, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(label,
                    style: TextStyle(color: subTextColor, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
    );
  }
}

// ─── Violation Card ────────────────────────────────────────────────────────
class _ViolationCard extends StatelessWidget {
  final String schoolId;
  final String studentId;
  final bool isDark;
  final Color textColor;
  final Color subTextColor;
  final Color cardBg;
  final Color cardBorder;

  const _ViolationCard({
    required this.schoolId,
    required this.studentId,
    required this.isDark,
    required this.textColor,
    required this.subTextColor,
    required this.cardBg,
    required this.cardBorder,
  });

  @override
  Widget build(BuildContext context) {
    if (studentId.isEmpty) {
      return _emptyCard('Data pelanggaran belum tersedia.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('violations')
          .where('studentId', isEqualTo: studentId)
          .orderBy('date', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tidak Ada Pelanggaran',
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Anak Anda memiliki catatan pelanggaran yang bersih.',
                          style:
                              TextStyle(color: subTextColor, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${docs.length} Pelanggaran',
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final date = data['date'] != null
                    ? (data['date'] as Timestamp).toDate()
                    : null;
                final dateStr = date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : '-';
                final poin = data['poin'] ?? data['points'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.report_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['jenis'] ?? data['type'] ?? 'Pelanggaran',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            if ((data['keterangan'] ?? data['description'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text(
                                data['keterangan'] ?? data['description'] ?? '',
                                style: TextStyle(
                                    color: subTextColor, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateStr,
                              style: TextStyle(
                                  color: subTextColor, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            '-$poin poin',
                            style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: subTextColor, fontSize: 13)),
    );
  }
}