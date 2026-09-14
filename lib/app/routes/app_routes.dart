class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  // Route untuk alur admin utama.
  static const superAdmin = '/super-admin';
  static const schoolAdmin = '/school-admin';
  static const schoolAdminDashboard = '/school-admin/dashboard';
  static const schoolAdminTeacherManagement = '/school-admin/manajemen-guru';
  static const schoolAdminTeacherDetail = '/school-admin/manajemen-guru/detail';
  static const schoolAdminTeacherEdit = '/school-admin/manajemen-guru/edit';
  static const schoolAdminStudentManagement = '/school-admin/manajemen-siswa';
  static const schoolAdminSubjects = '/school-admin/mata-pelajaran';
  static const schoolAdminClasses = '/school-admin/kelas';
  static const schoolAdminSchedule = '/school-admin/jadwal';
  static const schoolAdminAttendanceRecap = '/school-admin/rekap-absensi';
  static const schoolAdminNotifications = '/school-admin/notifikasi';
  static const schoolAdminSettings = '/school-admin/pengaturan';
  static const schoolAdminStaff = '/school-admin/petugas';
  static const schoolAdminGrades = '/school-admin/rekap-nilai';
  static const schoolAdminERapor = '/school-admin/e-rapor';
  static const schoolAdminViolations = '/school-admin/pelanggaran-murid';
  static const schoolAdminApprovals = '/school-admin/persetujuan';
  static const schoolAdminTeachingReports = '/school-admin/laporan-mengajar';
  static const schoolAdminSemesterExam = '/school-admin/ujian-semester';

  // Route untuk dashboard tiap peran pengguna.
  static const teacher = '/teacher';
  static const teacherlist = '/teacher-list';
  static const subjectList = '/subject-list';

  static const student = '/student';
  static const studentList = '/student-list';
  static const parent = '/parent';
  static const parentRegister = '/parent-register';
  static const parentAttendance = '/parent-attendance';
  static const parentGrades = '/parent-grades';
  static const parentViolations = '/parent-violations';
  static const parentChat = '/parent-chat';
  static const parentPermit = '/parent-permit';
  static const parentSchedule = '/parent-schedule';
  static const teacherPermits = '/teacher-permits';

  // Route untuk officer
  static const officerDashboard = '/officer/dashboard';
  static const officerScan = '/officer/scan';
  static const officerManual = '/officer/manual';
  static const officerRecap = '/officer/recap';
  static const officerMonthlyRecap = '/officer/monthly-recap';

  // Route untuk TU (Tata Usaha)
  static const tuDashboard = '/tu/dashboard';

  // Route untuk dashboard persetujuan (Admin & TU)
  static const approvalDashboard = '/approval-dashboard';

  // Route untuk Librarian (Perpustakaan)
  static const librarianDashboard = '/librarian/dashboard';

  // Route untuk fitur lainnya.
  static const classList = '/class-list';
  static const schedule = '/schedule';
  static const notifications = '/notifications';
  static const premiumFeatures = '/premium-features';

  // Route untuk fitur Coming Soon (placeholder)
  static const comingSoonBankSoalGuru = '/coming-soon/bank-soal-guru';
  static const comingSoonBankSoalMurid = '/coming-soon/bank-soal-murid';
  static const comingSoonStatistikGuru = '/coming-soon/statistik-guru';
  static const comingSoonStatistikAdmin = '/coming-soon/statistik-admin';
  static const comingSoonSuratIzinOrtu = '/coming-soon/surat-izin-ortu';
  static const comingSoonSuratIzinMurid = '/coming-soon/surat-izin-murid';
  static const comingSoonNewsFeedAdmin = '/coming-soon/news-feed-admin';
  static const comingSoonNewsFeedGuru = '/coming-soon/news-feed-guru';
  static const comingSoonNewsFeedMurid = '/coming-soon/news-feed-murid';
  static const comingSoonNewsFeedOrtu = '/coming-soon/news-feed-ortu';
  static const comingSoonAnalitikAdmin = '/coming-soon/analitik-admin';
}

