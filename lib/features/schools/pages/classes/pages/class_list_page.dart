import 'package:flutter/material.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/class_service.dart';
import 'class_info_page.dart';
import '../../students/data/student_admin_service.dart';

class ClassListPage extends StatelessWidget {
  final bool hideBackButton;
  ClassListPage({super.key, this.hideBackButton = false});

  final ClassService _service = ClassService();
  final StudentService _studentService = StudentService();


  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

            final listTileBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
            final listTileBorder = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
            final listTileShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

            final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
            final arrowColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);

            final emptyBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03);
            final emptyBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
            final emptyIconColor = isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
            final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
            final emptySubtitleColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

            return Scaffold(
              body: AuthBackground(
                child: Column(
                  children: [
                    // AppBar Area
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          children: [
                            if (!hideBackButton)
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonColor, size: 20),
                              ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AppLocalization.isIndonesian ? 'Data\nKelas' : 'Classes\nData',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                              ),
                            ),
                            // Kosongkan Kelas Button
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showKosongkanKelasConfirmation(context, schoolId),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          AppLocalization.isIndonesian ? 'Kosongkan Kelas' : 'Empty Classes',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showAddClassDialog(context, schoolId),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 6),
                                        Text(
                                          AppLocalization.isIndonesian ? 'Tambah' : 'Add',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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

                    // Body
                    Expanded(
                      child: StreamBuilder(
                        stream: _service.getClasses(schoolId),
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
                                    child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    AppLocalization.isIndonesian ? 'Terjadi kesalahan' : 'An error occurred',
                                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                              ),
                            );
                          }

                          final docs = snapshot.data!.docs.toList();
                          docs.sort((a, b) => (a.data()['namaKelas'] ?? '').toString().toLowerCase().compareTo((b.data()['namaKelas'] ?? '').toString().toLowerCase()));

                          if (docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: emptyBg,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: emptyBorder),
                                    ),
                                    child: Icon(Icons.class_outlined, size: 48, color: emptyIconColor),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    AppLocalization.isIndonesian ? 'Belum ada kelas' : 'No classes yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: emptyTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppLocalization.isIndonesian
                                        ? 'Tap "Tambah" untuk membuat kelas baru'
                                        : 'Tap "Add" to create a new class',
                                    style: TextStyle(fontSize: 13, color: emptySubtitleColor),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                            itemCount: docs.length,
                            itemBuilder: (_, index) {
                              final data = docs[index].data();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: listTileBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: listTileBorder),
                                  boxShadow: isDark
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: listTileShadow,
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ClassInfoPage(
                                            classId: docs[index].id,
                                            className: data['namaKelas'] ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: const Icon(Icons.class_rounded, color: Colors.white, size: 26),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  data['namaKelas'] ?? '-',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: titleColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Row(
                                                  children: [
                                                    Icon(Icons.person_rounded, size: 13, color: subtitleColor),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        AppLocalization.isIndonesian
                                                            ? 'Wali Kelas: ${data['teacherName'] ?? 'Belum ditentukan'}'
                                                            : 'Homeroom Teacher: ${data['teacherName'] ?? 'Not set'}',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: subtitleColor,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _showDeleteConfirmationDialog(context, docs[index].id, data['namaKelas'] ?? ''),
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
                                          ),
                                          Icon(Icons.chevron_right_rounded, color: arrowColor, size: 22),
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
            );
          },
        );
      },
    );
  }

  Future<void> _showAddClassDialog(BuildContext context, String schoolId) async {
    final isDark = AuthBackground.isDarkMode.value;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final fieldBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final fieldBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final hintColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
        final labelColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final textStyleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), 
              width: 1.5
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.class_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalization.isIndonesian ? 'Tambah Kelas' : 'Add Class',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleTextColor),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: fieldBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: fieldBorderColor),
                ),
                child: TextField(
                  controller: controller,
                  style: TextStyle(color: textStyleColor),
                  decoration: InputDecoration(
                    labelText: AppLocalization.isIndonesian ? 'Nama Kelas' : 'Class Name',
                    hintText: AppLocalization.isIndonesian ? 'Contoh: X IPA 1' : 'E.g., 10 Science 1',
                    labelStyle: TextStyle(color: labelColor),
                    hintStyle: TextStyle(color: hintColor),
                    prefixIcon: Icon(Icons.class_outlined, color: labelColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
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
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                      style: TextStyle(color: textStyleColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final namaKelas = controller.text.trim();
                      if (namaKelas.isEmpty) return;

                      try {
                        await _service.addClass(schoolId: schoolId, namaKelas: namaKelas);

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalization.isIndonesian
                                    ? 'Kelas berhasil ditambahkan'
                                    : 'Class successfully added',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      AppLocalization.isIndonesian ? 'Simpan' : 'Save',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String classId, String className) {
    final isDark = AuthBackground.isDarkMode.value;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
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
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalization.isIndonesian ? 'Hapus Kelas?' : 'Delete Class?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1B4B), fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalization.isIndonesian
                    ? 'Apakah Anda yakin ingin menghapus kelas $className?'
                    : 'Are you sure you want to delete class $className?',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.7), fontSize: 13, height: 1.5),
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
                    child: Text(
                      AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1B4B)),
                    ),
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
                      Navigator.pop(ctx);
                      
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                      );

                      try {
                        await _service.deleteClass(classId);
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalization.isIndonesian
                                    ? 'Kelas berhasil dihapus.'
                                    : 'Class successfully deleted.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalization.isIndonesian
                                    ? 'Gagal menghapus kelas: $e'
                                    : 'Failed to delete class: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      AppLocalization.isIndonesian ? 'Hapus' : 'Delete',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showKosongkanKelasConfirmation(BuildContext context, String schoolId) {
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
                  AppLocalization.isIndonesian ? 'Kosongkan Seluruh Kelas?' : 'Empty All Classes?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalization.isIndonesian
                ? 'Apakah Anda yakin ingin mengeluarkan seluruh murid dari semua kelas? Tindakan ini bertujuan untuk pergantian semester baru. Seluruh kelas akan dikosongkan (tanpa murid), tetapi data murid dan histori nilai semester lalu tetap tersimpan di sistem.'
                : 'Are you sure you want to remove all students from all classes? This action is for the transition to a new semester. All classes will be emptied (without students), but student data and past semester grade history will remain saved in the system.',
            style: const TextStyle(fontSize: 14),
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
                    child: Text(
                      AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                      style: TextStyle(color: titleTextColor),
                    ),
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
                      Navigator.pop(ctx);
                      
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        await _studentService.formatAllClasses(schoolId);
                        
                        if (context.mounted) {
                          Navigator.pop(context); // close loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalization.isIndonesian
                                    ? 'Seluruh kelas berhasil dikosongkan.'
                                    : 'All classes successfully emptied.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // close loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalization.isIndonesian
                                    ? 'Gagal mengosongkan kelas: $e'
                                    : 'Failed to empty classes: $e',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      AppLocalization.isIndonesian ? 'Kosongkan' : 'Empty',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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

