class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  // Route untuk alur admin utama.
  static const superAdmin = '/super-admin';
  static const schoolAdmin = '/school-admin';

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

  // Route untuk officer
  static const officerDashboard = '/officer/dashboard';
  static const officerScan = '/officer/scan';
  static const officerManual = '/officer/manual';
  static const officerRecap = '/officer/recap';
  static const officerMonthlyRecap = '/officer/monthly-recap';

  // Route untuk TU (Tata Usaha)
  static const tuDashboard = '/tu/dashboard';

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
  static const comingSoonExportAdmin = '/coming-soon/export-admin';
  static const comingSoonExportTu = '/coming-soon/export-tu';
  static const comingSoonSuratIzinOrtu = '/coming-soon/surat-izin-ortu';
  static const comingSoonSuratIzinMurid = '/coming-soon/surat-izin-murid';
  static const comingSoonNewsFeedAdmin = '/coming-soon/news-feed-admin';
  static const comingSoonNewsFeedGuru = '/coming-soon/news-feed-guru';
  static const comingSoonNewsFeedMurid = '/coming-soon/news-feed-murid';
  static const comingSoonNewsFeedOrtu = '/coming-soon/news-feed-ortu';
  static const comingSoonAnalitikAdmin = '/coming-soon/analitik-admin';
}

