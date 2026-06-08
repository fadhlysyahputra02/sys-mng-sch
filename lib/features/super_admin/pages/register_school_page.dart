import 'package:flutter/material.dart';
import '../../authentication/pages/login_page.dart';
import '../../schools/data/school_service.dart';

class RegisterSchoolPage extends StatefulWidget {
  const RegisterSchoolPage({super.key});

  @override
  State<RegisterSchoolPage> createState() => _RegisterSchoolPageState();
}

class _RegisterSchoolPageState extends State<RegisterSchoolPage> {
  final namaSekolahController = TextEditingController();
  final schoolIdController = TextEditingController();
  final domainController = TextEditingController();

  final schoolService = SchoolService();

  String? generatedAdminCode;

  @override
  void dispose() {
    namaSekolahController.dispose();
    schoolIdController.dispose();
    domainController.dispose();
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
      final domain = domainController.text.trim().toLowerCase();

      if (namaSekolah.isEmpty || schoolId.isEmpty || domain.isEmpty) {
        throw Exception('Semua field wajib diisi');
      }

      final adminCode = generateAdminCode();

      await schoolService.createSchool(
        schoolId: schoolId,
        namaSekolah: namaSekolah,
        domain: domain,
        kodeAdmin: adminCode,
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

            TextField(
              controller: domainController,
              decoration: const InputDecoration(
                labelText: 'Domain',
                hintText: 'smansa',
                border: OutlineInputBorder(),
              ),
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
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
                child: const Text('KEMBALI KE LOGIN'),
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
}
