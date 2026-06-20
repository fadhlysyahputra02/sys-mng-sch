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

  // Route untuk officer
  static const officerDashboard = '/officer/dashboard';
  static const officerScan = '/officer/scan';
  static const officerManual = '/officer/manual';
  static const officerRecap = '/officer/recap';

  // Route untuk fitur lainnya.
  static const classList = '/class-list';
  static const schedule = '/schedule';
  static const notifications = '/notifications';
  static const premiumFeatures = '/premium-features';
}

