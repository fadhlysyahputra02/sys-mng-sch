import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/app_auth_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../widgets/dashboard_home_tab.dart';
import '../widgets/book_list_tab.dart';
import '../widgets/loan_list_tab.dart';
import '../widgets/visitor_log_tab.dart';

class LibrarianDashboardPage extends StatefulWidget {
  const LibrarianDashboardPage({super.key});

  @override
  State<LibrarianDashboardPage> createState() => _LibrarianDashboardPageState();
}

class _LibrarianDashboardPageState extends State<LibrarianDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmLogout(BuildContext context) async {
    final bool isDark = AuthBackground.isDarkMode.value;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
          ),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              AppLocalization.logoutConfirmTitle,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalization.logoutConfirmLibrarian,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalization.cancel,
              style: TextStyle(
                color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1E1B4B).withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(AppLocalization.logout, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppAuthService.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final canGoBack = Navigator.of(context).canPop();
    final isTeacherLibrarian = user?.role == 'teacher';

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.7);
            final tabIndicatorColor = const Color(0xFF6366F1);

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0F0C20) : const Color(0xFFF8FAFC),
              body: Column(
                children: [
                  AuthBackground(
                    fullScreen: false,
                    child: Column(
                      children: [
                        // Dashboard Header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                          child: Row(
                            children: [
                              if (canGoBack) ...[
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalization.menuLibraryDashboard,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Halo, ${user?.nama ?? AppLocalization.officerLabel}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Only show logout button if they are not a teacher-librarian accessing via sub-widget
                              if (!isTeacherLibrarian)
                                IconButton(
                                  onPressed: () => _confirmLogout(context),
                                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                                  tooltip: AppLocalization.logout,
                                ),
                            ],
                          ),
                        ),

                        // Navigation Tabs
                        TabBar(
                          controller: _tabController,
                          isScrollable: MediaQuery.of(context).size.width < 500,
                          indicatorColor: tabIndicatorColor,
                          labelColor: tabIndicatorColor,
                          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: [
                            Tab(text: AppLocalization.menuHome, icon: const Icon(Icons.dashboard_rounded, size: 20)),
                            Tab(text: AppLocalization.menuBooks, icon: const Icon(Icons.menu_book_rounded, size: 20)),
                            Tab(text: AppLocalization.menuLoans, icon: const Icon(Icons.swap_horiz_rounded, size: 20)),
                            Tab(text: AppLocalization.menuGuestBook, icon: const Icon(Icons.people_rounded, size: 20)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tab Contents
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        DashboardHomeTab(
                          isDark: isDark,
                          onTabChange: (index) {
                            _tabController.animateTo(index);
                          },
                        ),
                        BookListTab(isDark: isDark),
                        LoanListTab(isDark: isDark),
                        VisitorLogTab(isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
