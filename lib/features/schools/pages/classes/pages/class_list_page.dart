import 'package:flutter/material.dart';
import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/class_service.dart';
import 'class_info_page.dart';

class ClassListPage extends StatelessWidget {
  final bool hideBackButton;
  ClassListPage({super.key, this.hideBackButton = false});

  final ClassService _service = ClassService();

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
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
                            'Data Kelas',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
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
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Tambah',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                                'Terjadi kesalahan',
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

                      final docs = snapshot.data!.docs;

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
                                'Belum ada kelas',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: emptyTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap "Tambah" untuk membuat kelas baru',
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
                                                    'Wali Kelas: ${data['teacherName'] ?? 'Belum ditentukan'}',
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
                'Tambah Kelas',
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
                    labelText: 'Nama Kelas',
                    hintText: 'Contoh: X IPA 1',
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
                    child: Text('Batal', style: TextStyle(color: textStyleColor)),
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

                      await _service.addClass(schoolId: schoolId, namaKelas: namaKelas);

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kelas berhasil ditambahkan')),
                        );
                      }
                    },
                    child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
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
