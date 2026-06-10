import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // HEADER PROFILE
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      child: Icon(Icons.person, size: 40),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.nama,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(user.email),

                          const SizedBox(height: 4),

                          Text(
                            user.schoolId,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // STATISTIK
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    title: 'Kelas',
                    value: '3',
                    icon: Icons.class_,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    title: 'Murid',
                    value: '96',
                    icon: Icons.groups,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _statCard(
                    title: 'Absensi',
                    value: 'Hari Ini',
                    icon: Icons.fact_check,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    title: 'Nilai',
                    value: 'Input',
                    icon: Icons.grade,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Menu Utama',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            const SizedBox(height: 12),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _menuCard(
                  icon: Icons.class_,
                  title: 'Kelas Saya',
                  onTap: () {},
                ),

                _menuCard(
                  icon: Icons.groups,
                  title: 'Daftar Murid',
                  onTap: () {},
                ),

                _menuCard(
                  icon: Icons.fact_check,
                  title: 'Absensi',
                  onTap: () {},
                ),

                _menuCard(
                  icon: Icons.grade,
                  title: 'Input Nilai',
                  onTap: () {},
                ),

                _menuCard(icon: Icons.assignment, title: 'Rapor', onTap: () {}),

                _menuCard(icon: Icons.person, title: 'Profil', onTap: () {}),
              ],
            ),

            const SizedBox(height: 24),

            Card(
              child: ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Informasi Akun'),
                subtitle: Text('Role : ${user.role}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
