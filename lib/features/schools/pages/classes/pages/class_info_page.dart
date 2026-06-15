import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../students/data/student_admin_service.dart';
import '../../teachers/data/teacher_service.dart';
import '../data/class_service.dart';

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
                child: Row(
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
                            onTap: () => _showAddStudentDialog(context),
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

  void _showAddStudentDialog(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final emptyIconColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final tileBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final tileBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final studentNameColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final studentNisColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    showDialog(
      context: context,
      builder: (ctx) {
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
              Text(
                'Tambah Siswa ke Kelas',
                style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 380,
            child: StreamBuilder(
              stream: _studentService.getStudentsWithoutClass(
                SessionService.currentUser!.schoolId,
              ),
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

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final student = docs[index].data();
                    final inisial = student['nama'] != null && student['nama'].isNotEmpty
                        ? student['nama'][0].toUpperCase()
                        : '?';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tileBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
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
                                    student['nama'] ?? '',
                                    style: TextStyle(color: studentNameColor, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    student['nis'] ?? '',
                                    style: TextStyle(fontSize: 12, color: studentNisColor),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                                minimumSize: const Size(60, 34),
                              ),
                              onPressed: () async {
                                await _studentService.assignStudentToClass(
                                  studentId: docs[index].id,
                                  classId: classId,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${student['nama']} berhasil ditambahkan ke kelas'),
                                      duration: const Duration(seconds: 2),
                                    ),
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
                onPressed: () => Navigator.pop(ctx),
                child: Text('Tutup', style: TextStyle(color: titleTextColor, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
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

    final assignedTeacherIds = classesSnapshot.docs
        .map((doc) => doc.data()['teacherId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

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
                final availableDocs = allDocs
                    .where((doc) => !assignedTeacherIds.contains(doc.id))
                    .toList();

                if (availableDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_rounded, size: 48, color: emptyIconColor),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada guru yang tersedia\n(semua sudah menjadi wali kelas)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: emptyTextColor),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: availableDocs.length,
                  itemBuilder: (_, index) {
                    final doc = availableDocs[index];
                    final teacher = doc.data();
                    final teacherName = teacher['nama'] ?? '';
                    final inisial = teacherName.isNotEmpty ? teacherName[0].toUpperCase() : '?';

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
                              child: Text(
                                teacherName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: teacherNameColor),
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
}
