import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../authentication/widgets/auth_background.dart';

class AddTeacherPage extends StatefulWidget {
  final String schoolId;

  const AddTeacherPage({super.key, required this.schoolId});

  @override
  State<AddTeacherPage> createState() => _AddTeacherPageState();
}

class _AddTeacherPageState extends State<AddTeacherPage> {
  final _formKey = GlobalKey<FormState>();

  final namaController = TextEditingController();
  final nipController = TextEditingController();

  bool isLoading = false;

  Future<void> saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        isLoading = true;
      });

      final nip = nipController.text.trim();

      final existingTeacher = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .where('nip', isEqualTo: nip)
          .get();

      if (existingTeacher.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menambah guru: NIP sudah terdaftar!')),
          );
        }
        return;
      }

      final doc = FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('teachers')
          .doc();

      await doc.set({
        'teacherId': doc.id,
        'schoolId': widget.schoolId,
        'uid': '',
        'email': '',
        'nip': nip,
        'nama': namaController.text.trim(),
        'aktif': true,
        'sudahRegister': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    namaController.dispose();
    nipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.65);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);
        final borderColor = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Tambah Guru',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),

                          // Header card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Registrasi Guru Baru',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Guru terdaftar dapat login menggunakan NIP ini.',
                                        style: TextStyle(fontSize: 12, color: subTextColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Form fields
                          _buildField(
                            controller: namaController,
                            label: 'Nama Lengkap',
                            icon: Icons.person_outline_rounded,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'Nama wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: nipController,
                            label: 'NIP (Nomor Induk Pegawai)',
                            icon: Icons.badge_outlined,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'NIP wajib diisi' : null,
                          ),

                          const SizedBox(height: 32),

                          // Submit button
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: isLoading ? null : saveTeacher,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text(
                                      'Simpan Data',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
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
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardBgColor,
    required Color borderColor,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
