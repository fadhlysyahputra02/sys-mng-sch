import 'package:flutter/material.dart';

import '../../../../core/services/session_service.dart';
import '../teachers/teacher_list_page.dart';

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
      appBar: AppBar(title: const Text('Dashboard Sekolah')),

      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
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
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Halo Admin Sekolah 👋',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherListPage(schoolId: 'smaga'),
                      ),
                    );
                  },
                ),
                _menuCard(title: 'Murid', icon: Icons.groups, onTap: () {}),
                _menuCard(title: 'Kelas', icon: Icons.class_, onTap: () {}),
                _menuCard(title: 'Jadwal', icon: Icons.schedule, onTap: () {}),
                _menuCard(
                  title: 'Absensi',
                  icon: Icons.fact_check,
                  onTap: () {},
                ),
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
}
