import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../students/data/student_admin_service.dart';
import '../../teachers/data/teacher_service.dart';
import '../data/class_service.dart';
import 'class_subject_quota_page.dart';

class ClassInfoPage extends StatelessWidget {
  final String classId;
  final String className;
  final StudentService _studentService = StudentService();
  final TeacherService _teacherService = TeacherService();
  final ClassService _classService = ClassService();

  ClassInfoPage({super.key, required this.classId, required this.className});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
        final cardBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
        final cardShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final textSecondaryColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

        final bottomBarBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
        final bottomBarBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);

        return Scaffold(
          body: AuthBackground(
            child: Column(
          children: [
            // AppBar
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonColor, size: 20),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        className,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.school_rounded, color: Color(0xFF6366F1)),
                      tooltip: 'Luluskan Kelas',
                      onPressed: () => _showGraduateClassDialog(context),
                    ),
                  ],
                ),
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informasi Kelas header
                    _sectionHeader('Informasi Kelas', Icons.info_outline_rounded, isDark),
                    const SizedBox(height: 12),

                    // Wali Kelas card
                    StreamBuilder(
                      stream: _classService.getClassById(classId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: cardBorder),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                              ),
                            ),
                          );
                        }

                        final data = snapshot.data!.data();
                        final teacherName = data?['teacherName'] ?? 'Belum ditentukan';
                        final teacherId = data?['teacherId'];
                        final hasTeacher = teacherId != null && teacherId.toString().isNotEmpty;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: cardShadow,
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wali Kelas',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      teacherName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: hasTeacher ? textPrimaryColor : textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasTeacher)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
                                    tooltip: 'Batalkan Wali Kelas',
                                    onPressed: () => _showRemoveWaliKelasConfirmation(context, teacherName),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Alokasi Jam Mapel button
                    StreamBuilder(
                      stream: _classService.getClassById(classId),
                      builder: (context, snapshot) {
                        Map<String, int> quotas = {};
                        if (snapshot.hasData && snapshot.data!.data() != null) {
                          final data = snapshot.data!.data()!;
                          if (data['subjectQuotas'] != null) {
                            quotas = Map<String, int>.from(data['subjectQuotas']);
                          }
                        }
                        
                        return InkWell(
                          onTap: () => _handleAlokasiJamTap(context, classId, className, quotas),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Alokasi Jam Pelajaran',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: textPrimaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'BASIC',
                                              style: TextStyle(
                                                color: Color(0xFF6366F1),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Atur jatah jam per mapel untuk kelas ini',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: textSecondaryColor, size: 24),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Daftar Siswa header
                    _sectionHeader('Daftar Siswa', Icons.groups_rounded, isDark),
                    const SizedBox(height: 12),

                    // Student list
                    Expanded(
                      child: StreamBuilder(
                        stream: _studentService.getStudentsByClass(classId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                              ),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Icon(Icons.group_off_rounded, size: 48, color: textSecondaryColor),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada siswa di kelas ini',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: textSecondaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final student = docs[index].data();
                              final nama = student['nama'] ?? '';
                              final inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder),
                                  boxShadow: isDark
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: cardShadow,
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Text(
                                            inisial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nama,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: textPrimaryColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'NIS: ${student['nis'] ?? '-'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Remove button
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Keluarkan dari kelas',
                                          onPressed: () => _showRemoveStudentConfirmation(context, docs[index].id, nama),
                                        ),
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
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              decoration: BoxDecoration(
                color: bottomBarBg,
                border: Border(
                  top: BorderSide(color: bottomBarBorder),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Wali Kelas button
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _showAddWaliKelasDialog(context),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_alt_1_rounded, size: 18, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Wali Kelas',
                                      style: TextStyle(
                                        color: Color(0xFFF59E0B),
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
                        const SizedBox(width: 12),
                        // Tambah Siswa button
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => _AddStudentDialog(
                                      schoolId: SessionService.currentUser!.schoolId,
                                      classId: classId,
                                    ),
                                  );
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.group_add_rounded, size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Tambah Siswa',
                                      style: TextStyle(
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
                    const SizedBox(height: 12),
                    // Kosongkan Kelas button
                    Container(
                      height: 48,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showEmptyClassConfirmation(context),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Kosongkan Kelas (Format)',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

  Widget _sectionHeader(String title, IconData icon, bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────────

  void _showEmptyClassConfirmation(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorderColor, width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kosongkan Kelas?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin mengeluarkan seluruh siswa dari kelas ini? Tindakan ini tidak dapat dibatalkan, namun data siswa tidak akan terhapus dari sistem.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: TextStyle(color: titleTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );
                
                await _studentService.emptyClass(
                  classId: classId,
                  schoolId: SessionService.currentUser!.schoolId,
                );
                
                if (context.mounted) {
                  Navigator.pop(context); // close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kelas berhasil dikosongkan.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Ya, Kosongkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showGraduateClassDialog(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.school_rounded, color: Color(0xFF6366F1), size: 28),
            const SizedBox(width: 10),
            Text(
              'Luluskan Kelas',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin meluluskan seluruh siswa di kelas "$className"?\n\n'
          'Siswa yang diluluskan tetap dapat login untuk melihat rekapan nilai dan absensi mereka, '
          'namun tidak dapat melakukan aktivitas harian (absen kelas, tugas, chat, dll), '
          'dan status mereka akan diubah menjadi Alumni (keluar dari kelas aktif ini).',
          style: TextStyle(color: subTextColor, fontSize: 14, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Batal', style: TextStyle(color: textColor)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Close confirmation dialog
                    
                    // Show loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      await _studentService.graduateClass(
                        classId: classId,
                        schoolId: SessionService.currentUser!.schoolId,
                      );

                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Seluruh siswa berhasil diluluskan!'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal meluluskan siswa: $e'),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Luluskan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddWaliKelasDialog(BuildContext context) async {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final emptyIconColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final tileBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final tileBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final teacherNameColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : const Color(0xFFF59E0B)),
        ),
      ),
    );

    final schoolId = SessionService.currentUser!.schoolId;
    final classesSnapshot = await FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .get();

    final assignedTeacherClasses = <String, List<String>>{};
    for (var doc in classesSnapshot.docs) {
      final data = doc.data();
      final tId = data['teacherId'] as String?;
      final classNameStr = data['namaKelas'] as String?;
      if (tId != null && tId.isNotEmpty && classNameStr != null) {
        assignedTeacherClasses.putIfAbsent(tId, () => []).add(classNameStr);
      }
    }

    if (context.mounted) Navigator.pop(context);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorderColor, width: 1.5),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFFF59E0B), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Pilih Wali Kelas',
                style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder(
              stream: _teacherService.getTeachers(schoolId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: titleTextColor.withValues(alpha: 0.6)),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs;
                final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(allDocs);
                sortedDocs.sort((a, b) {
                  final nameA = (a.data()['nama'] ?? '').toString().toLowerCase();
                  final nameB = (b.data()['nama'] ?? '').toString().toLowerCase();
                  return nameA.compareTo(nameB);
                });

                if (sortedDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_rounded, size: 48, color: emptyIconColor),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada guru yang terdaftar',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: emptyTextColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: sortedDocs.length,
                  itemBuilder: (_, index) {
                    final doc = sortedDocs[index];
                    final teacher = doc.data();
                    final teacherName = teacher['nama'] ?? '';
                    final inisial = teacherName.isNotEmpty ? teacherName[0].toUpperCase() : '?';

                    final existingClasses = assignedTeacherClasses[doc.id] ?? [];
                    final isAlreadyWali = existingClasses.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tileBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  inisial,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    teacherName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: teacherNameColor),
                                  ),
                                  if (isAlreadyWali)
                                    Text(
                                      'Wali Kelas: ${existingClasses.join(', ')}',
                                      style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                                minimumSize: const Size(60, 34),
                              ),
                              onPressed: () async {
                                if (isAlreadyWali) {
                                  // Tampilkan konfirmasi
                                  final classesStr = existingClasses.join(', ');
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (confirmCtx) {
                                      return AlertDialog(
                                        backgroundColor: dialogBgColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          side: BorderSide(color: dialogBorderColor, width: 1.5),
                                        ),
                                        title: Text('Konfirmasi', style: TextStyle(color: titleTextColor)),
                                        content: Text(
                                          'Guru $teacherName sudah menjadi walikelas $classesStr apakah ingin menambahkan lagi?',
                                          style: TextStyle(color: titleTextColor.withValues(alpha: 0.8)),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(confirmCtx, false),
                                            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                                            onPressed: () => Navigator.pop(confirmCtx, true),
                                            child: const Text('Ya, Tambahkan', style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirm != true) return;
                                }

                                await _classService.assignWaliKelas(
                                  classId: classId,
                                  teacherId: doc.id,
                                  teacherName: teacherName,
                                );
                                if (dialogContext.mounted) Navigator.pop(dialogContext);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$teacherName berhasil menjadi wali kelas')),
                                  );
                                }
                              },
                              child: const Text('Pilih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Tutup', style: TextStyle(color: titleTextColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRemoveWaliKelasConfirmation(BuildContext context, String teacherName) {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final bodyTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorderColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_remove_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Batalkan Wali Kelas',
                style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin membatalkan $teacherName sebagai wali kelas?',
                textAlign: TextAlign.center,
                style: TextStyle(color: bodyTextColor, fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Kembali', style: TextStyle(color: titleTextColor)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _classService.removeWaliKelas(classId: classId);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Wali kelas berhasil dibatalkan')),
                        );
                      }
                    },
                    child: const Text('Batalkan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showRemoveStudentConfirmation(BuildContext context, String studentId, String studentName) {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final bodyTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorderColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Keluarkan Siswa',
                style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin mengeluarkan $studentName dari kelas ini?',
                textAlign: TextAlign.center,
                style: TextStyle(color: bodyTextColor, fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Batal', style: TextStyle(color: titleTextColor)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      await _studentService.removeStudentFromClass(studentId);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$studentName berhasil dikeluarkan dari kelas')),
                        );
                      }
                    },
                    child: const Text('Keluarkan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAlokasiJamTap(BuildContext context, String classId, String className, Map<String, int> quotas) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
      ),
    );

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(schoolId).get();
      if (context.mounted) {
        Navigator.pop(context); // Tutup loading dialog
      }

      final plan = (schoolDoc.data()?['plan'] ?? 'FREE').toString().toUpperCase();

      if (plan == 'FREE') {
        if (context.mounted) {
          _showPremiumDialog(context, 'Fitur Alokasi Jam Pelajaran hanya tersedia untuk sekolah dengan Paket BASIC atau PRO.');
        }
      } else {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassSubjectQuotaPage(
                classId: classId,
                className: className,
                initialQuotas: quotas,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Tutup loading dialog jika error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memeriksa status paket: $e')),
        );
      }
    }
  }

  void _showPremiumDialog(BuildContext context, String message) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final mutedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorder, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Fitur Premium 🌟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Silakan hubungi administrator/sales untuk melakukan upgrade paket sekolah Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AddStudentDialog extends StatefulWidget {
  final String schoolId;
  final String classId;

  const _AddStudentDialog({
    required this.schoolId,
    required this.classId,
  });

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final StudentService _studentService = StudentService();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedStudentIds = {};
  final Map<String, Map<String, String>> _studentsMap = {}; // Cache to store details of selected students
  String _searchQuery = '';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _studentsStream;

  @override
  void initState() {
    super.initState();
    _studentsStream = _studentService.getStudentsWithoutClass(widget.schoolId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final emptyIconColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final tileBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final tileBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final studentNameColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final studentNisColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final searchBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final searchBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), 
          width: 1.5
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.group_add_rounded, color: Color(0xFF0EA5E9), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tambah Siswa ke Kelas',
              style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            // Search field
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: searchBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: searchBorderColor),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: titleTextColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari nama murid...',
                  hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),
            
            // Student List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _studentsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(
                      child: Text('Gagal memuat data', style: TextStyle(color: emptyTextColor)),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: emptyIconColor),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada siswa tersedia',
                            style: TextStyle(color: emptyTextColor),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter students by query and ignore graduated (alumni) students
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data();
                    if (data['lulus'] == true) return false;
                    final nama = (data['nama'] ?? '').toString().toLowerCase();
                    final nis = (data['nis'] ?? '').toString().toLowerCase();
                    return nama.contains(_searchQuery) || nis.contains(_searchQuery);
                  }).toList();

                  // Sort filtered students alphabetically
                  filteredDocs.sort((a, b) {
                    final nameA = (a.data()['nama'] ?? '').toString().toLowerCase();
                    final nameB = (b.data()['nama'] ?? '').toString().toLowerCase();
                    return nameA.compareTo(nameB);
                  });

                  // Update studentsMap with current loaded student details
                  for (var doc in docs) {
                    final data = doc.data();
                    _studentsMap[doc.id] = {
                      'id': doc.id,
                      'nama': data['nama'] ?? '',
                      'nis': data['nis'] ?? '',
                    };
                  }

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 40, color: emptyIconColor),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak menemukan siswa',
                            style: TextStyle(color: emptyTextColor, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (_, index) {
                      final doc = filteredDocs[index];
                      final student = doc.data();
                      final studentId = doc.id;
                      final isSelected = _selectedStudentIds.contains(studentId);
                      final nama = student['nama'] ?? '';
                      final inisial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF0EA5E9).withValues(alpha: 0.1) 
                              : tileBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF0EA5E9).withValues(alpha: 0.4) 
                                : tileBorder,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedStudentIds.remove(studentId);
                                } else {
                                  _selectedStudentIds.add(studentId);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  // Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: const Color(0xFF0EA5E9),
                                    onChanged: (bool? val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedStudentIds.add(studentId);
                                        } else {
                                          _selectedStudentIds.remove(studentId);
                                        }
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Avatar
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        inisial,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nama,
                                          style: TextStyle(color: studentNameColor, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        Text(
                                          student['nis'] ?? '',
                                          style: TextStyle(fontSize: 12, color: studentNisColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Batal', style: TextStyle(color: titleTextColor)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _selectedStudentIds.isEmpty
                    ? null
                    : () async {
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          final selectedStudents = _selectedStudentIds.map((id) {
                            return _studentsMap[id] ?? {
                              'id': id,
                              'nama': '',
                              'nis': '',
                            };
                          }).toList();

                          await _studentService.assignMultipleStudentsToClass(
                            classId: widget.classId,
                            students: selectedStudents,
                          );

                          if (mounted) {
                            Navigator.pop(context); // close loading dialog
                            Navigator.pop(context); // close add student dialog
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${_selectedStudentIds.length} murid berhasil ditambahkan ke kelas'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            Navigator.pop(context); // close loading dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal menambahkan murid: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: Text(
                  _selectedStudentIds.isEmpty 
                      ? 'Simpan' 
                      : 'Simpan (${_selectedStudentIds.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

