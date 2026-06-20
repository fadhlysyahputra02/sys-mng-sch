import 'package:flutter/material.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/student_admin_service.dart';

class AddStudentPage extends StatefulWidget {
  final String schoolId;

  const AddStudentPage({super.key, required this.schoolId});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();

  final namaController = TextEditingController();
  final nisController = TextEditingController();
  final addressController = TextEditingController();
  String? _selectedGender;

  bool isLoading = false;

  Future<void> saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        isLoading = true;
      });

      await StudentService().createStudent(
        schoolId: widget.schoolId,
        nis: nisController.text.trim(),
        nama: namaController.text.trim(),
        gender: _selectedGender ?? '',
        alamat: addressController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Murid berhasil ditambahkan')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());

      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
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
    nisController.dispose();
    addressController.dispose();
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
                            'Tambah Murid',
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
                                      colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Registrasi Murid Baru',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Murid terdaftar dapat login menggunakan NIS ini.',
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
                            controller: nisController,
                            label: 'NIS (Nomor Induk Siswa)',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            validator: (v) => (v == null || v.isEmpty) ? 'NIS wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Jenis Kelamin',
                                labelStyle: TextStyle(color: subTextColor, fontSize: 14),
                                prefixIcon: const Icon(Icons.wc_rounded, color: Color(0xFF0EA5E9), size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                              style: TextStyle(color: textColor, fontSize: 15),
                              items: ['Laki-laki', 'Perempuan'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedGender = newValue;
                                });
                              },
                              validator: (v) => (v == null || v.isEmpty) ? 'Pilih jenis kelamin' : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildField(
                            controller: addressController,
                            label: 'Alamat',
                            icon: Icons.home_outlined,
                            isDark: isDark,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            maxLines: 3,
                          ),

                          const SizedBox(height: 32),

                          // Submit button
                          Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
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
                              onPressed: isLoading ? null : saveStudent,
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
    TextInputType? keyboardType,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardBgColor,
    required Color borderColor,
    int maxLines = 1,
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
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        style: TextStyle(color: textColor, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 12 : 16),
        ),
      ),
    );
  }
}
