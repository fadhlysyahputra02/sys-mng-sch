import 'package:get/get.dart';
import '../../core/services/session_service.dart';
import '../../features/authentication/pages/login_page.dart';
import '../../features/authentication/pages/register_page.dart';
import '../../features/schools/pages/classes/pages/class_list_page.dart';
import '../../features/schools/pages/schedule/Page/class_schedule_overview_page.dart';
import '../../features/super_admin/pages/register_school_page.dart';
import '../../features/schools/pages/students/pages/student_admin_list_page.dart';
import '../../features/schools/pages/subjects/pages/subject_list_page.dart';
import '../../features/schools/pages/teachers/pages/teacher_list_admin_page.dart';
import '../../features/splash/pages/splash_page.dart';
import '../../features/schools/pages/dashboard/school_admin_dashboard.dart';
import '../../features/teachers/pages/teacher_dashboard.dart';
import '../../features/students/pages/student_dashboard.dart';
import '../../features/parent/pages/parent_dashboard_page.dart';
import '../../features/parent/pages/parent_attendance_page.dart';
import '../../features/parent/pages/parent_grades_page.dart';
import '../../features/parent/pages/parent_violation_page.dart';
import '../../features/authentication/pages/parent_register_page.dart';
import '../../features/schools/pages/notifications/notifications_page.dart';
import '../../features/schools/pages/dashboard/premium_features_page.dart';
import '../../features/officer/pages/officer_dashboard_page.dart';
import '../../features/officer/pages/qr_scan_page.dart';
import '../../features/officer/pages/manual_attendance_page.dart';
import '../../features/officer/pages/daily_recap_page.dart';
import '../../features/officer/pages/monthly_recap_page.dart';

import 'app_routes.dart';

class AppPages {
  static final routes = [
    // Route untuk splash, login, dan register.
    GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.register, page: () => const RegisterPage()),
    GetPage(name: AppRoutes.superAdmin, page: () => const RegisterSchoolPage()),

    // Route untuk dashboard admin sekolah.
    GetPage(
      name: AppRoutes.schoolAdmin,
      page: () => const SchoolAdminDashboard(),
    ),

    // Route untuk guru.
    GetPage(name: AppRoutes.teacher, page: () => const TeacherDashboard()),
    GetPage(
      name: AppRoutes.teacherlist,
      page: () =>
          TeacherListPage(schoolId: SessionService.currentUser!.schoolId),
    ),

    // Route untuk siswa.
    GetPage(name: AppRoutes.student, page: () => const StudentDashboard()),
    GetPage(name: AppRoutes.parent, page: () => const ParentDashboardPage()),
    GetPage(
      name: AppRoutes.parentAttendance,
      page: () => const ParentAttendancePage(),
    ),
    GetPage(
      name: AppRoutes.parentGrades,
      page: () => const ParentGradesPage(),
    ),
    GetPage(
      name: AppRoutes.parentViolations,
      page: () => const ParentViolationPage(),
    ),
    GetPage(
      name: AppRoutes.parentRegister,
      page: () => const ParentRegisterPage(),
    ),
    GetPage(
      name: AppRoutes.studentList,
      page: () =>
          StudentListPage(schoolId: SessionService.currentUser!.schoolId),
    ),

    // Route untuk mata pelajaran.
    GetPage(name: AppRoutes.subjectList, page: () => SubjectListPage()),
    GetPage(name: AppRoutes.classList, page: () => ClassListPage()),
    // Route untuk jadwal.
    GetPage(
      name: AppRoutes.schedule,
      page: () => ClassScheduleOverviewPage(),
    ),
    // Route untuk notifikasi dan premium.
    GetPage(
      name: AppRoutes.notifications,
      page: () => const NotificationsPage(),
    ),
    GetPage(
      name: AppRoutes.premiumFeatures,
      page: () => const PremiumFeaturesPage(),
    ),

    // Route untuk officer
    GetPage(name: AppRoutes.officerDashboard, page: () => const OfficerDashboardPage()),
    GetPage(name: AppRoutes.officerScan, page: () => const QrScanPage()),
    GetPage(name: AppRoutes.officerManual, page: () => const ManualAttendancePage()),
    GetPage(name: AppRoutes.officerRecap, page: () => const DailyRecapPage()),
    GetPage(name: AppRoutes.officerMonthlyRecap, page: () => const MonthlyRecapPage()),
  ];
}

