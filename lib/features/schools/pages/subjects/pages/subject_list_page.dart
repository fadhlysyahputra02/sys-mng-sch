import 'package:flutter/material.dart';
import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/subject_service.dart';
import 'add_subject_page.dart';

class SubjectListPage extends StatelessWidget {
  final bool hideBackButton;
  SubjectListPage({super.key, this.hideBackButton = false});

  final service = SubjectService();

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
        final tagIconColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final moreIconColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

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
                        'Mata Pelajaran',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AddSubjectPage()),
                            );
                          },
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
                stream: service.getSubjects(schoolId),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
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
                            child: Icon(Icons.menu_book_rounded, size: 48, color: emptyIconColor),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Belum ada mata pelajaran',
                            style: TextStyle(
                              fontSize: 16,
                              color: emptyTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Tambah" untuk menambahkan mata pelajaran',
                            style: TextStyle(fontSize: 13, color: emptySubtitleColor),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i].data();
                      final isWajib = data['kategori'] == 'Wajib';

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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['namaMapel'] ?? '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.tag_rounded, size: 13, color: tagIconColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          data['kodeMapel'] ?? '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtitleColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isWajib
                                                ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                                : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isWajib
                                                  ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                                                  : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            data['kategori'] ?? '-',
                                            style: TextStyle(
                                              color: isWajib ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: moreIconColor),
                                color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(context, data, schoolId);
                                  } else if (value == 'delete') {
                                    _showDeleteConfirmation(context, data, schoolId);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 8),
                                        Text('Edit', style: TextStyle(color: titleColor, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                        const SizedBox(width: 8),
                                        const Text('Hapus', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                                      ],
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
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> data, String schoolId) {
    final isDark = AuthBackground.isDarkMode.value;
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final fieldBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final fieldBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final textStyleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final dialogBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;

    final namaController = TextEditingController(text: data['namaMapel']);
    final kodeController = TextEditingController(text: data['kodeMapel']);
    final kkmController = TextEditingController(text: (data['kkm'] ?? 75).toString());
    String selectedKategori = data['kategori'] ?? 'Wajib';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: dialogBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08), 
                  width: 1.5
                ),
              ),
              title: Text(
                'Edit Mata Pelajaran',
                style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(
                    controller: kodeController,
                    label: 'Kode Mapel',
                    icon: Icons.tag_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    controller: namaController,
                    label: 'Nama Mapel',
                    icon: Icons.menu_book_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    controller: kkmController,
                    label: 'Nilai KKM',
                    icon: Icons.speed_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKategori,
                    dropdownColor: dialogBgColor,
                    style: TextStyle(color: textStyleColor),
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      labelStyle: TextStyle(color: labelColor),
                      prefixIcon: Icon(Icons.category_outlined, color: labelColor),
                      filled: true,
                      fillColor: fieldBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: fieldBorderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: fieldBorderColor),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'Wajib', child: Text('Wajib', style: TextStyle(color: textStyleColor))),
                      DropdownMenuItem(value: 'Pilihan', child: Text('Pilihan', style: TextStyle(color: textStyleColor))),
                    ],
                    onChanged: (v) => setDialogState(() => selectedKategori = v!),
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
                        child: Text('Batal', style: TextStyle(color: textStyleColor)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final nama = namaController.text.trim();
                          final kode = kodeController.text.trim();
                          final kkmVal = int.tryParse(kkmController.text.trim()) ?? 75;
                          if (nama.isEmpty || kode.isEmpty) return;

                          await service.updateSubject(
                            schoolId: SessionService.currentUser!.schoolId,
                            subjectId: data['subjectId'],
                            namaMapel: nama,
                            kodeMapel: kode,
                            kategori: selectedKategori,
                            kkm: kkmVal,
                          );

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Mata pelajaran berhasil diperbarui')),
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
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> data, String schoolId) {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textStyleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
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
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Hapus Mata Pelajaran',
                style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin menghapus "${data['namaMapel']}"? Data tidak dapat dikembalikan.',
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
                    child: Text('Batal', style: TextStyle(color: textStyleColor)),
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
                      await service.deleteSubject(
                        schoolId: SessionService.currentUser!.schoolId,
                        subjectId: data['subjectId'],
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mata pelajaran berhasil dihapus')),
                        );
                      }
                    },
                    child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final textStyleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final fieldBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final fieldBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return TextField(
      controller: controller,
      style: TextStyle(color: textStyleColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor),
        prefixIcon: Icon(icon, color: labelColor),
        filled: true,
        fillColor: fieldBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: fieldBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
      ),
    );
  }
}
