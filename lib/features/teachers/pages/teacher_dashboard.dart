import 'dart:convert';
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
import 'teacher_grades_page.dart';
import 'teacher_reports_page.dart';


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
  String? _tahunAjaran;
  String? _activeSemester;
  String? _schoolLogoBase64;

  @override
  void initState() {
    super.initState();
    _resolveTeacherDocId();
  }

  /// Langkah paling penting: cari dokumen guru di subcollection teachers
  /// berdasarkan Firebase Auth UID, lalu simpan teacherId (doc.id)
  Future<void> _resolveTeacherDocId() async {
    if (SessionService.currentUser == null) return;
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
          _tahunAjaran = schoolData['tahunAjaran'];
          _activeSemester = schoolData['semester'];
          _schoolLogoBase64 = schoolData['logoBase64'] as String?;
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
    final bool isDark = AuthBackground.isDarkMode.value;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun guru Anda?',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
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
    if (SessionService.currentUser == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.login));
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        if (_isLoadingTeacher || _isLoadingSchool) {
          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: CircularProgressIndicator(
                  color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                ),
              ),
            ),
          );
        }

        if (_teacherDocId == null) {
          final infoTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final infoSubtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
          final infoBorderColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.3);

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
                      Text(
                        'Akun Anda belum terhubung',
                        style: TextStyle(color: infoTextColor, fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data guru Anda tidak ditemukan di sekolah ini. Hubungi Admin Sekolah untuk menghubungkan akun Anda.',
                        style: TextStyle(color: infoSubtitleColor, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => _confirmLogout(context),
                        icon: Icon(Icons.logout_rounded, color: infoTextColor),
                        label: Text('Keluar', style: TextStyle(color: infoTextColor)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: infoBorderColor),
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
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return Scaffold(
          body: AuthBackground(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _scheduleService.getSchedulesByTeacher(user.schoolId, teacherId),
                  builder: (context, scheduleSnapshot) {
                    final schedules = scheduleSnapshot.data?.docs.map((e) => e.data()).toList() ?? [];

                    final Set<String> teacherClassIds = schedules
                        .map((e) => (e['classId'] ?? '') as String)
                        .where((id) => id.isNotEmpty)
                        .toSet();

                    final currentDay = _getCurrentDay();
                    final todaySchedules = schedules.where((s) => s['hari'] == currentDay).toList();
                    todaySchedules.sort((a, b) {
                      return _timeToMinutes(a['jamMulai'] ?? '').compareTo(_timeToMinutes(b['jamMulai'] ?? ''));
                    });

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _teacherService.getClassesByTeacher(user.schoolId, teacherId),
                      builder: (context, classSnapshot) {
                        final waliKelasClasses = classSnapshot.data?.docs ?? [];

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _teacherSubjectService.getSubjectsByTeacher(user.schoolId, teacherId),
                          builder: (context, subjectSnapshot) {
                            final teacherSubjects = subjectSnapshot.data?.docs.map((e) => e.data()).toList() ?? [];

                            return RefreshIndicator(
                              onRefresh: _resolveTeacherDocId,
                              child: CustomScrollView(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              slivers: [
                                SliverAppBar(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  pinned: true,
                                  toolbarHeight: 56,
                                  title: Row(
                                    children: [
                                      if (_schoolLogoBase64 != null && _schoolLogoBase64!.isNotEmpty) ...[
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.memory(
                                              base64Decode(_schoolLogoBase64!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(Icons.school_rounded, size: 18, color: titleColor),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Text(
                                          _getGreeting(),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.notifications_rounded, color: iconColor, size: 20),
                                        tooltip: 'Notifikasi',
                                        onPressed: () => Get.toNamed(AppRoutes.notifications),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.settings_rounded, color: iconColor, size: 20),
                                        tooltip: 'Pengaturan',
                                        onPressed: () => Get.to(() => const TeacherSettingsPage()),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      margin: const EdgeInsets.only(right: 16),
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: Icon(Icons.logout_rounded, color: iconColor, size: 20),
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
                                        _buildProfileHeader(teacherNama, user.email, teacherNip, waliKelasClasses, isDark),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(child: _buildStatCard(
                                              title: 'Kelas Mengajar',
                                              value: teacherClassIds.length.toString(),
                                              icon: Icons.class_rounded,
                                              color: const Color(0xFF6366F1),
                                              isDark: isDark,
                                            )),
                                            const SizedBox(width: 12),
                                            Expanded(child: _buildStatCard(
                                              title: 'Mata Pelajaran',
                                              value: teacherSubjects.length.toString(),
                                              icon: Icons.menu_book_rounded,
                                              color: const Color(0xFF10B981),
                                              isDark: isDark,
                                            )),
                                          ],
                                        ),
                                        const SizedBox(height: 28),
                                        _buildSectionTitle('Mata Pelajaran Saya', Icons.menu_book_rounded, isDark),
                                        const SizedBox(height: 16),
                                        _buildSubjectsList(teacherSubjects, isDark),
                                        const SizedBox(height: 28),
                                        _buildSectionTitle('Jadwal Hari Ini ($currentDay)', Icons.calendar_today_rounded, isDark),
                                        const SizedBox(height: 16),
                                        _buildTodaySchedule(todaySchedules, isDark),
                                        const SizedBox(height: 28),
                                        _buildSectionTitle('Menu Utama', Icons.dashboard_rounded, isDark),
                                        const SizedBox(height: 16),
                                        _buildMenuGrid(isDark),
                                        const SizedBox(height: 40),
                                      ],
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
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- WIDGETS ---

  Widget _buildProfileHeader(String nama, String email, String nip, List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses, bool isDark) {
    // Ambil nama kelas wali kelas (jika ada)
    final waliKelasNames = waliKelasClasses.map((doc) => doc.data()['namaKelas'] ?? 'Kelas').toList();
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final nipColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
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
                child: _schoolLogoBase64 != null && _schoolLogoBase64!.isNotEmpty
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(_schoolLogoBase64!),
                          fit: BoxFit.cover,
                          width: 70,
                          height: 70,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 36, color: Color(0xFF8B5CF6)),
                        ),
                      )
                    : const Icon(Icons.person_rounded, size: 36, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nama, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
                    const SizedBox(height: 4),
                    Text(email, style: TextStyle(fontSize: 13, color: subtitleColor)),
                    const SizedBox(height: 4),
                    Text('NIP: $nip', style: TextStyle(fontSize: 12, color: nipColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.school_rounded, color: nipColor, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _schoolName ?? 'Sekolah',
                            style: TextStyle(
                              fontSize: 12, 
                              color: nipColor, 
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
          if (_tahunAjaran != null || _activeSemester != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tahun Ajaran: ${_tahunAjaran ?? "-"}  |  ${_activeSemester ?? "-"}',
                      style: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color, required bool isDark}) {
    final cardBg = isDark ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.08);
    final cardBorderColor = isDark ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.2);
    final valueColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final titleColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: valueColor)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: titleColor)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSubjectsList(List<Map<String, dynamic>> subjects, bool isDark) {
    if (subjects.isEmpty) {
      final emptyBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
      final emptyBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
      final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
      
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: emptyBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: emptyBorder),
        ),
        child: Text(
          'Belum ada mata pelajaran yang di-assign',
          style: TextStyle(color: emptyTextColor, fontSize: 14),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: subjects.map((s) {
        final name = s['subjectName'] ?? 'Mapel';
        final textLabelColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final itemBg = isDark ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.1);
        final itemBorder = isDark ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.25);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: itemBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(color: textLabelColor, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodaySchedule(List<Map<String, dynamic>> schedules, bool isDark) {
    if (schedules.isEmpty) {
      final emptyBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
      final emptyBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
      final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: emptyBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: emptyBorder),
        ),
        child: Text(
          'Tidak ada jadwal hari ini 🎉',
          style: TextStyle(color: emptyTextColor, fontSize: 16),
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

  Widget _buildMenuGrid(bool isDark) {
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

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 1.1;

    if (screenWidth >= 900) {
      crossAxisCount = 4;
      childAspectRatio = 1.4;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.25;
    }

    final cardBg = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
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
              } else if (menu['title'] == 'Input Nilai') {
                Get.to(() => TeacherGradesPage(teacherId: _teacherDocId!));
              } else if (menu['title'] == 'Laporan & Rapor') {
                Get.to(() => TeacherReportsPage(
                      schoolId: user.schoolId,
                      teacherId: _teacherDocId!,
                    ));
              }
            },
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
                    child: Icon(menu['icon'] as IconData, color: color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    menu['title'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
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
