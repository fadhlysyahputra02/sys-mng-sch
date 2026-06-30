import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../officers/pages/officer_management_page.dart';
import '../tu/pages/tu_management_page.dart';
import '../librarian/librarian_management_page.dart';

class StaffManagementTabbedPage extends StatelessWidget {
  const StaffManagementTabbedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final unselectedColor = isDark ? Colors.white54 : Colors.black54;
        final indicatorColor = const Color(0xFF6366F1);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            body: AuthBackground(
              child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Manajemen Petugas',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TabBar(
                    labelColor: indicatorColor,
                    unselectedLabelColor: unselectedColor,
                    indicatorColor: indicatorColor,
                    tabs: const [
                      Tab(text: 'Petugas Absensi'),
                      Tab(text: 'Tata Usaha'),
                      Tab(text: 'Perpustakaan'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: const [
                        OfficerManagementPage(hideBackButton: true),
                        TuManagementPage(hideBackButton: true),
                        LibrarianManagementPage(hideBackButton: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
