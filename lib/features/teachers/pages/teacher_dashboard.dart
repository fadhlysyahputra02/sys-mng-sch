import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/app_auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';
import '../../schools/pages/teachers/data/teacher_service.dart';
import '../../schools/pages/teachers/data/teacher_subject_service.dart';
import '../../schools/services/school_service.dart';
import 'teacher_schedule_page.dart';
import 'teacher_settings_page.dart';
import 'teacher_attendance_schedule_page.dart';
import 'teacher_behavior_records_page.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _teacherService = TeacherService();
  final _scheduleService = ClassScheduleService();
  final _teacherSubjectService = TeacherSubjectService();

  // Teacher Firestore doc ID (berbeda dengan Firebase Auth UID)
  String? _teacherDocId;
  Map<String, dynamic>? _teacherData;
  bool _isLoadingTeacher = true;

  String? _schoolName;
  String _plan = 'FREE';
  bool _isLoadingSchool = true;

  @override
  void initState() {
    super.initState();
    _resolveTeacherDocId();
  }

  /// Langkah paling penting: cari dokumen guru di subcollection teachers
  /// berdasarkan Firebase Auth UID, lalu simpan teacherId (doc.id)
  Future<void> _resolveTeacherDocId() async {
    final user = SessionService.currentUser!;

    // Load school and teacher in parallel
    final results = await Future.wait([
      SchoolService().getSchoolByDomain(user.schoolId),
      _teacherService.getTeacherByUid(user.schoolId, user.uid),
    ]);

    final schoolData = results[0] as Map<String, dynamic>?;
    final doc = results[1] as DocumentSnapshot<Map<String, dynamic>>?;

    if (mounted) {
      setState(() {
        if (schoolData != null) {
          _schoolName = schoolData['namaSekolah'];
          _plan = (schoolData['plan'] ?? 'FREE').toString().toUpperCase();
        }
        _teacherDocId = doc?.id;
        _teacherData = doc?.data();
        _isLoadingTeacher = false;
        _isLoadingSchool = false;
      });
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _getCurrentDay() {
    switch (DateTime.now().weekday) {
      case DateTime.monday: return 'Senin';
      case DateTime.tuesday: return 'Selasa';
      case DateTime.wednesday: return 'Rabu';
      case DateTime.thursday: return 'Kamis';
      case DateTime.friday: return 'Jumat';
      case DateTime.saturday: return 'Sabtu';
      case DateTime.sunday: return 'Minggu';
      default: return 'Senin';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour <= 10) return 'Selamat Pagi';
    if (hour <= 14) return 'Selamat Siang';
    if (hour <= 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0C20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun guru Anda?',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppAuthService.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    if (_isLoadingTeacher || _isLoadingSchool) {
      return Scaffold(
        body: AuthBackground(
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    if (_teacherDocId == null) {
      return Scaffold(
        body: AuthBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Akun Anda belum terhubung',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data guru Anda tidak ditemukan di sekolah ini. Hubungi Admin Sekolah untuk menghubungkan akun Anda.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: const Text('Keluar', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final teacherId = _teacherDocId!;
    final teacherNama = _teacherData?['nama'] ?? user.nama;
    final teacherNip = _teacherData?['nip'] ?? '-';

    return Scaffold(
      body: AuthBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Ambil SEMUA jadwal guru ini berdasarkan teacherId (doc ID di subcollection)
          stream: _scheduleService.getSchedulesByTeacher(user.schoolId, teacherId),
          builder: (context, scheduleSnapshot) {
            final schedules = scheduleSnapshot.data?.docs.map((e) => e.data()).toList() ?? [];

            // Hitung jumlah kelas unik yang diajar
            final Set<String> teacherClassIds = schedules
                .map((e) => (e['classId'] ?? '') as String)
                .where((id) => id.isNotEmpty)
                .toSet();

            // Filter jadwal hari ini & urutkan
            final currentDay = _getCurrentDay();
            final todaySchedules = schedules.where((s) => s['hari'] == currentDay).toList();
            todaySchedules.sort((a, b) {
              return _timeToMinutes(a['jamMulai'] ?? '').compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
            });

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // Ambil kelas-kelas yang wali kelasnya guru ini
              stream: _teacherService.getClassesByTeacher(user.schoolId, teacherId),
              builder: (context, classSnapshot) {
                final waliKelasClasses = classSnapshot.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  // Ambil mata pelajaran yang di-assign ke guru ini
                  stream: _teacherSubjectService.getSubjectsByTeacher(user.schoolId, teacherId),
                  builder: (context, subjectSnapshot) {
                    final teacherSubjects = subjectSnapshot.data?.docs.map((e) => e.data()).toList() ?? [];

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // AppBar (dengan judul ucapan)
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      toolbarHeight: 56,
                      title: Text(
                        '${_getGreeting()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      actions: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
                            tooltip: 'Notifikasi',
                            onPressed: () => Get.toNamed(AppRoutes.notifications),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                            tooltip: 'Pengaturan',
                            onPressed: () => Get.to(() => const TeacherSettingsPage()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                            tooltip: 'Keluar',
                            onPressed: () => _confirmLogout(context),
                          ),
                        ),
                      ],
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. HEADER PROFILE + WALI KELAS
                            _buildProfileHeader(teacherNama, user.email, teacherNip, waliKelasClasses),

                            const SizedBox(height: 24),

                            // 2. QUICK STATS
                            Row(
                              children: [
                                Expanded(child: _buildStatCard(
                                  title: 'Kelas Mengajar',
                                  value: teacherClassIds.length.toString(),
                                  icon: Icons.class_rounded,
                                  color: const Color(0xFF6366F1),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStatCard(
                                  title: 'Mata Pelajaran',
                                  value: teacherSubjects.length.toString(),
                                  icon: Icons.menu_book_rounded,
                                  color: const Color(0xFF10B981),
                                )),
                              ],
                            ),

                            const SizedBox(height: 28),

                            // 3. MATA PELAJARAN SAYA
                            _buildSectionTitle('Mata Pelajaran Saya', Icons.menu_book_rounded),
                            const SizedBox(height: 16),
                            _buildSubjectsList(teacherSubjects),

                            const SizedBox(height: 28),

                            // 4. JADWAL HARI INI
                            _buildSectionTitle('Jadwal Hari Ini ($currentDay)', Icons.calendar_today_rounded),
                            const SizedBox(height: 16),
                            _buildTodaySchedule(todaySchedules),

                            const SizedBox(height: 28),

                            // 5. MENU UTAMA
                            _buildSectionTitle('Menu Utama', Icons.dashboard_rounded),
                            const SizedBox(height: 16),
                            _buildMenuGrid(),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildProfileHeader(String nama, String email, String nip, List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses) {
    // Ambil nama kelas wali kelas (jika ada)
    final waliKelasNames = waliKelasClasses.map((doc) => doc.data()['namaKelas'] ?? 'Kelas').toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
                ),
                child: const Icon(Icons.person_rounded, size: 36, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nama, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(email, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text('NIP: $nip', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.school_rounded, color: Colors.white.withValues(alpha: 0.5), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _schoolName ?? 'Sekolah',
                            style: TextStyle(
                              fontSize: 12, 
                              color: Colors.white.withValues(alpha: 0.5), 
                              fontWeight: FontWeight.w500
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: const Text(
                            'Guru',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPlanBadge(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Wali Kelas (di dalam card yang sama)
          if (waliKelasNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Wali Kelas: ${waliKelasNames.join(", ")}',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildPlanBadge() {
    Color badgeColor;
    Gradient badgeGradient;
    IconData icon;
    String label = _plan;

    if (label == 'PRO') {
      badgeColor = const Color(0xFFD97706);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.workspace_premium_rounded;
    } else if (label == 'BASIC') {
      badgeColor = const Color(0xFF2563EB);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.star_rounded;
    } else {
      badgeColor = const Color(0xFF4B5563);
      badgeGradient = const LinearGradient(
        colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      icon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: badgeGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSubjectsList(List<Map<String, dynamic>> subjects) {
    if (subjects.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          'Belum ada mata pelajaran yang di-assign',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: subjects.map((s) {
        final name = s['subjectName'] ?? 'Mapel';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodaySchedule(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          'Tidak ada jadwal hari ini 🎉',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: schedules.length,
        itemBuilder: (context, index) {
          final s = schedules[index];
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${s['jamMulai'] ?? '-'} - ${s['jamSelesai'] ?? '-'}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text(
                  s['subjectName'] ?? 'Pelajaran',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.class_outlined, color: Colors.white.withValues(alpha: 0.8), size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        s['className'] ?? 'Kelas',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuGrid() {
    final menus = [
      {'title': 'Jadwal Mengajar', 'icon': Icons.calendar_month_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Absensi Murid', 'icon': Icons.fact_check_rounded, 'color': const Color(0xFF10B981)},
      {'title': 'Input Nilai', 'icon': Icons.grade_rounded, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Manajemen Tugas', 'icon': Icons.assignment_rounded, 'color': const Color(0xFF3B82F6)},
      {'title': 'Laporan & Rapor', 'icon': Icons.bar_chart_rounded, 'color': const Color(0xFFEC4899)},
      {'title': 'Pengumuman', 'icon': Icons.campaign_rounded, 'color': const Color(0xFFEF4444)},
      {'title': 'Daftar Siswa', 'icon': Icons.groups_rounded, 'color': const Color(0xFF0EA5E9)},
      {'title': 'Wali Murid / Chat', 'icon': Icons.chat_rounded, 'color': const Color(0xFFF97316)},
      {'title': 'Bank Soal', 'icon': Icons.question_answer_rounded, 'color': const Color(0xFF14B8A6)},
      {'title': 'Realtime Control', 'icon': Icons.settings_remote_rounded, 'color': const Color(0xFF84CC16)},
      {'title': 'Fitur Premium', 'icon': Icons.workspace_premium_rounded, 'color': const Color(0xFFF97316)},
      {'title': 'Pengaturan Profil', 'icon': Icons.manage_accounts_rounded, 'color': const Color(0xFF64748B)},
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
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final user = SessionService.currentUser!;
              if (menu['title'] == 'Fitur Premium') {
                Get.toNamed(AppRoutes.premiumFeatures, arguments: {
                  'plan': _plan,
                  'schoolId': user.schoolId,
                });
              } else if (menu['title'] == 'Pengumuman') {
                Get.toNamed(AppRoutes.notifications);
              } else if (menu['title'] == 'Pengaturan Profil') {
                Get.to(() => const TeacherSettingsPage());
              } else if (menu['title'] == 'Jadwal Mengajar') {
                Get.to(() => TeacherSchedulePage(teacherId: _teacherDocId!));
              } else if (menu['title'] == 'Absensi Murid') {
                Get.to(() => TeacherAttendanceSchedulePage(teacherId: _teacherDocId!));
              } else if (menu['title'] == 'Realtime Control') {
                Get.to(() => TeacherBehaviorRecordsPage(teacherId: _teacherDocId!));
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    child: Icon(menu['icon'] as IconData, color: color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    menu['title'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
