import 'package:get/get.dart';
import '../../core/services/session_service.dart';
import '../../features/authentication/pages/login_page.dart';
import '../../features/authentication/pages/register_page.dart';
import '../../features/schools/pages/students/pages/student_list_page.dart';
import '../../features/schools/pages/subjects/pages/subject_list_page.dart';
import '../../features/schools/pages/teachers/pages/teacher_list_page.dart';
import '../../features/splash/pages/splash_page.dart';
import '../../features/schools/pages/dashboard/school_admin_dashboard.dart';
import '../../features/teachers/pages/teacher_dashboard.dart';
import '../../features/students/pages/student_dashboard.dart';

import 'app_routes.dart';

class AppPages {
  static final routes = [
    GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.register, page: () => const RegisterPage()),

    GetPage(
      name: AppRoutes.schoolAdmin,
      page: () => const SchoolAdminDashboard(),
    ),

    GetPage(name: AppRoutes.teacher, page: () => const TeacherDashboard()),

    GetPage(name: AppRoutes.student, page: () => const StudentDashboard()),
    GetPage(
      name: AppRoutes.teacherlist,
      page: () =>
          TeacherListPage(schoolId: SessionService.currentUser!.schoolId),
    ),
    GetPage(name: AppRoutes.subjectList, page: () => SubjectListPage()),
    GetPage(
      name: AppRoutes.studentList,
      page: () =>
          StudentListPage(schoolId: SessionService.currentUser!.schoolId),
    ),
  ];
}
