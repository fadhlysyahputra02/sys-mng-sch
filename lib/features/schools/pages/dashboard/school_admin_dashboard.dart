import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/services/app_auth_service.dart';
import '../../../../core/services/session_service.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

final schoolId = SessionService.currentUser!.schoolId;
final role = SessionService.currentUser!.role;
final nama = SessionService.currentUser!.nama;

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Halo Admin $schoolId 👋')),

      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYS MNG SCH',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Paket : FREE'),
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.person),
              title: Text(nama),
              subtitle: Text(role),
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _menuCard(
                  title: 'Guru',
                  icon: Icons.school,
                  onTap: () {
                    Get.toNamed(AppRoutes.teacherlist);
                  },
                ),

                _menuCard(
                  title: 'Murid',
                  icon: Icons.groups,
                  onTap: () {
                    Get.toNamed(AppRoutes.studentList);
                  },
                ),
                _menuCard(
                  title: 'Mata Pelajaran',
                  icon: Icons.menu_book,
                  onTap: () {
                    Get.toNamed(AppRoutes.subjectList);
                  },
                ),

                _menuCard(title: 'Kelas', icon: Icons.class_, onTap: () {}),

                _menuCard(title: 'Jadwal', icon: Icons.schedule, onTap: () {}),

                _menuCard(
                  title: 'Absensi',
                  icon: Icons.fact_check,
                  onTap: () {},
                ),

                _menuCard(title: 'Nilai', icon: Icons.grade, onTap: () {}),

                _menuCard(
                  title: 'Langganan',
                  icon: Icons.workspace_premium,
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Fitur Premium',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _premiumTile('Wali Murid', 'PRO'),

            _premiumTile('E-Rapor', 'PRO'),

            _premiumTile('WhatsApp Gateway', 'PRO'),

            _premiumTile('Keuangan', 'PRO'),

            _premiumTile('Jurusan', 'BASIC'),

            _premiumTile('Mata Pelajaran', 'BASIC'),
          ],
        ),
      ),
    );
  }

  Widget _menuCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _premiumTile(String title, String paket) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Chip(label: Text(paket)),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await AppAuthService.logout();
      } catch (e) {
        Get.snackbar('Error', 'Gagal logout: $e');
      }
    }
  }
}
