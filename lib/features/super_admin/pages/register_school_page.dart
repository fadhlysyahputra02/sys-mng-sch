import 'package:flutter/material.dart';
import '../../../core/services/app_auth_service.dart';
import '../../schools/services/school_service.dart';

class RegisterSchoolPage extends StatefulWidget {
  const RegisterSchoolPage({super.key});

  @override
  State<RegisterSchoolPage> createState() => _RegisterSchoolPageState();
}

class _RegisterSchoolPageState extends State<RegisterSchoolPage> {
  final namaSekolahController = TextEditingController();
  final schoolIdController = TextEditingController();

  final schoolService = SchoolService();

  String selectedPlan = 'free';
  String? generatedAdminCode;

  @override
  void dispose() {
    namaSekolahController.dispose();
    schoolIdController.dispose();
    super.dispose();
  }

  String generateAdminCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'ADM-${timestamp.toString().substring(7)}';
  }

  Future<void> simpanSekolah() async {
    try {
      final namaSekolah = namaSekolahController.text.trim();
      final schoolId = schoolIdController.text.trim().toLowerCase();
      final domain = schoolId; // domain otomatis sama dengan schoolId

      if (namaSekolah.isEmpty || schoolId.isEmpty) {
        throw Exception('Semua field wajib diisi');
      }

      final adminCode = generateAdminCode();

      await schoolService.createSchool(
        schoolId: schoolId,
        namaSekolah: namaSekolah,
        domain: domain,
        kodeAdmin: adminCode,
        plan: selectedPlan,
      );

      setState(() {
        generatedAdminCode = adminCode;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sekolah berhasil dibuat')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('===== REGISTER SCHOOL ERROR =====');
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());
      debugPrint('================================');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Sekolah')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: namaSekolahController,
              decoration: const InputDecoration(
                labelText: 'Nama Sekolah',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: schoolIdController,
              decoration: const InputDecoration(
                labelText: 'School ID',
                hintText: 'smansa',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Paket Langganan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _planCard('free', 'Free', Icons.star_outline, Colors.grey),
                const SizedBox(width: 8),
                _planCard('basic', 'Basic', Icons.star_half, Colors.blue),
                const SizedBox(width: 8),
                _planCard('pro', 'Pro', Icons.star, Colors.amber),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: simpanSekolah,
                child: const Text('SIMPAN SEKOLAH'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () async {
                  await AppAuthService.logout();
                },
                child: const Text('KELUAR'),
              ),
            ),

            if (generatedAdminCode != null) ...[
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Kode Registrasi Admin',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 12),

                      SelectableText(
                        generatedAdminCode!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Simpan kode ini untuk registrasi Admin Sekolah',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planCard(String plan, String label, IconData icon, Color color) {
    final isSelected = selectedPlan == plan;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedPlan = plan),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
