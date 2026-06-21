import 'package:flutter/material.dart';
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
import '../../features/parent/pages/parent_chat_list_page.dart';
import '../../features/authentication/pages/parent_register_page.dart';
import '../../features/schools/pages/notifications/notifications_page.dart';
import '../../features/schools/pages/dashboard/premium_features_page.dart';
import '../../features/officer/pages/officer_dashboard_page.dart';
import '../../features/officer/pages/qr_scan_page.dart';
import '../../features/officer/pages/manual_attendance_page.dart';
import '../../features/officer/pages/daily_recap_page.dart';
import '../../features/officer/pages/monthly_recap_page.dart';
import '../../features/tu/pages/tu_dashboard_page.dart';
import '../../features/shared/coming_soon_page.dart';

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
      name: AppRoutes.parentChat,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        return ParentChatListPage(
          schoolId: args['schoolId'] ?? '',
          parentDocId: args['parentDocId'] ?? '',
          parentName: args['parentName'] ?? '',
          studentName: args['studentName'] ?? '',
          className: args['className'] ?? '',
        );
      },
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

    // Route untuk TU
    GetPage(name: AppRoutes.tuDashboard, page: () => const TuDashboardPage()),

    // ─── Route Coming Soon (Placeholder) ─────────────────────────────────────
    // BASIC: Bank Soal & Quiz Online
    GetPage(
      name: AppRoutes.comingSoonBankSoalGuru,
      page: () => const ComingSoonPage(
        featureName: 'Bank Soal & Quiz Online',
        description:
            'Buat dan kelola kumpulan soal serta kuis online untuk siswa.',
        icon: Icons.quiz_rounded,
        iconColor: Color(0xFF14B8A6),
        packageBadge: 'BASIC',
      ),
    ),
    GetPage(
      name: AppRoutes.comingSoonBankSoalMurid,
      page: () => const ComingSoonPage(
        featureName: 'Bank Soal & Quiz Online',
        description:
            'Kerjakan kuis dan latihan soal yang diberikan oleh guru.',
        icon: Icons.quiz_rounded,
        iconColor: Color(0xFF14B8A6),
        packageBadge: 'BASIC',
      ),
    ),
    // BASIC: Statistik Akademik
    GetPage(
      name: AppRoutes.comingSoonStatistikGuru,
      page: () => const ComingSoonPage(
        featureName: 'Statistik Akademik',
        description:
            'Grafik perkembangan nilai dan performa akademik siswa secara visual.',
        icon: Icons.bar_chart_rounded,
        iconColor: Color(0xFF6366F1),
        packageBadge: 'BASIC',
      ),
    ),
    GetPage(
      name: AppRoutes.comingSoonStatistikAdmin,
      page: () => const ComingSoonPage(
        featureName: 'Statistik Akademik',
        description:
            'Grafik perkembangan nilai dan performa akademik siswa secara visual.',
        icon: Icons.bar_chart_rounded,
        iconColor: Color(0xFF6366F1),
        packageBadge: 'BASIC',
      ),
    ),
    // BASIC: Export Laporan
    GetPage(
      name: AppRoutes.comingSoonExportAdmin,
      page: () => const ComingSoonPage(
        featureName: 'Export Laporan',
        description:
            'Unduh laporan absensi, nilai, dan statistik dalam format PDF atau Excel.',
        icon: Icons.file_download_rounded,
        iconColor: Color(0xFF10B981),
        packageBadge: 'BASIC',
      ),
    ),
    GetPage(
      name: AppRoutes.comingSoonExportTu,
      page: () => const ComingSoonPage(
        featureName: 'Export Laporan',
        description:
            'Unduh laporan absensi, nilai, dan statistik dalam format PDF atau Excel.',
        icon: Icons.file_download_rounded,
        iconColor: Color(0xFF10B981),
        packageBadge: 'BASIC',
      ),
    ),
    // PRO: Surat Izin Digital
    GetPage(
      name: AppRoutes.comingSoonSuratIzinOrtu,
      page: () => const ComingSoonPage(
        featureName: 'Surat Izin Digital',
        description:
            'Kirim surat izin atau surat sakit anak secara digital langsung dari aplikasi.',
        icon: Icons.mark_email_read_rounded,
        iconColor: Color(0xFF8B5CF6),
        packageBadge: 'PRO',
      ),
    ),
    GetPage(
      name: AppRoutes.comingSoonSuratIzinMurid,
      page: () => const ComingSoonPage(
        featureName: 'Surat Izin Digital',
        description:
            'Lihat status surat izin yang telah dikirimkan oleh orang tua.',
        icon: Icons.mark_email_read_rounded,
        iconColor: Color(0xFF8B5CF6),
        packageBadge: 'PRO',
      ),
    ),
    // PRO: News Feed Sekolah
    GetPage(
      name: AppRoutes.comingSoonNewsFeedAdmin,
      page: () => const ComingSoonPage(
        featureName: 'News Feed Sekolah',
        description:
            'Media informasi sekolah untuk berbagi berita, pengumuman, prestasi, dan kegiatan sekolah.',
        icon: Icons.newspaper_rounded,
        iconColor: Color(0xFF0EA5E9),
        packageBadge: 'PRO',
      ),
    ),
    GetPage(
      name: AppRoutes.comingSoonNewsFeedGuru,
      page: () => const ComingSoonPage(
        featureName: 'News Feed Sekolah',
        description:
            'Media informasi sekolah untuk berbagi berita, pengumuman, prestasi, dan kegiatan sekolah.',
        icon: Icons.newspaper_rounded,
        iconColor: Color(0xFF0EA5E9),
        packageBadge: 'PRO',
      ),
    ),
    GetPage(
      name: AppRoutes.comingSoonNewsFeedMurid,
      page: () => const ComingSoonPage(
        featureName: 'News Feed Sekolah',
        description:
            'Media informasi sekolah untuk berbagi berita, pengumuman, prestasi, dan kegiatan sekolah.',
        icon: Icons.newspaper_rounded,
        iconColor: Color(0xFF0EA5E9),
        packageBadge: 'PRO',
      ),
    ),
    GetPage(
      name: AppRoutes.comingSoonNewsFeedOrtu,
      page: () => const ComingSoonPage(
        featureName: 'News Feed Sekolah',
        description:
            'Media informasi sekolah untuk berbagi berita, pengumuman, prestasi, dan kegiatan sekolah.',
        icon: Icons.newspaper_rounded,
        iconColor: Color(0xFF0EA5E9),
        packageBadge: 'PRO',
      ),
    ),
    // PRO: Analitik Sekolah
    GetPage(
      name: AppRoutes.comingSoonAnalitikAdmin,
      page: () => const ComingSoonPage(
        featureName: 'Analitik Sekolah',
        description:
            'Dashboard analitik lengkap untuk memantau perkembangan akademik dan kehadiran seluruh siswa.',
        icon: Icons.analytics_rounded,
        iconColor: Color(0xFFEC4899),
        packageBadge: 'PRO',
      ),
    ),
  ];
}

