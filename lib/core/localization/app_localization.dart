import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kelas untuk mengelola bahasa aplikasi (Indonesia / English)
class AppLocalization {
  static const String _prefKey = 'app_language';
  static const String langId = 'id';
  static const String langEn = 'en';

  /// ValueNotifier untuk reaktif — default bahasa Indonesia
  static final ValueNotifier<String> currentLocale =
      ValueNotifier<String>(langId);

  /// Inisialisasi dari SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        currentLocale.value = saved;
      }
    } catch (e) {
      debugPrint('AppLocalization init error: $e');
    }

    // Simpan setiap kali berubah
    currentLocale.addListener(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKey, currentLocale.value);
      } catch (e) {
        debugPrint('AppLocalization save error: $e');
      }
    });
  }

  /// Toggle antara ID dan EN
  static void toggle() {
    currentLocale.value =
        currentLocale.value == langId ? langEn : langId;
  }

  static bool get isIndonesian => currentLocale.value == langId;

  // ─── Terjemahan Login Page ───────────────────────────────────────────────

  static String get loginTitle =>
      isIndonesian ? 'MASUK KE AKUN' : 'SIGN IN';

  static String get loginSubtitle =>
      isIndonesian ? 'Sistem Manajemen Sekolah Modern' : 'Modern School Management System';

  static String get loginButton =>
      isIndonesian ? 'MASUK' : 'SIGN IN';

  static String get emailLabel => isIndonesian ? 'Email' : 'Email';

  static String get passwordLabel =>
      isIndonesian ? 'Password' : 'Password';

  static String get forgotPassword =>
      isIndonesian ? 'Lupa Password?' : 'Forgot Password?';

  static String get noAccount =>
      isIndonesian ? 'Belum punya akun? ' : 'Don\'t have an account? ';

  static String get registerNow =>
      isIndonesian ? 'Daftar Sekarang' : 'Register Now';

  static String get isParent =>
      isIndonesian ? 'Orang tua? ' : 'Are you a parent? ';

  static String get registerAsParent =>
      isIndonesian ? 'Daftar sebagai Orang Tua' : 'Register as Parent';

  // ─── Terjemahan Forgot Password Dialog ──────────────────────────────────

  static String get resetPassword =>
      isIndonesian ? 'Reset Password' : 'Reset Password';

  static String get resetPasswordSubtitle => isIndonesian
      ? 'Masukkan email terdaftar Anda untuk menerima tautan reset password.'
      : 'Enter your registered email to receive a password reset link.';

  static String get cancelButton =>
      isIndonesian ? 'Batal' : 'Cancel';

  static String get sendButton =>
      isIndonesian ? 'Kirim' : 'Send';

  // ─── Terjemahan Login Notification ──────────────────────────────────────

  static String get loginIncomplete =>
      isIndonesian ? 'Formulir Tidak Lengkap' : 'Incomplete Form';

  static String get loginIncompleteMsg =>
      isIndonesian ? 'Silakan isi kolom email dan password.' : 'Please fill in the email and password fields.';

  static String get loginSuccess =>
      isIndonesian ? 'Login Berhasil' : 'Login Successful';

  static String get loginSuccessMsg =>
      isIndonesian ? 'Selamat datang kembali di aplikasi!' : 'Welcome back to the application!';

  static String get loginFailed =>
      isIndonesian ? 'Login Gagal' : 'Login Failed';

  static String get loginDefaultError =>
      isIndonesian ? 'Email atau password salah.' : 'Incorrect email or password.';

  static String get accountNotFound =>
      isIndonesian ? 'Akun tidak ditemukan.' : 'Account not found.';

  static String get wrongPassword =>
      isIndonesian ? 'Password salah.' : 'Incorrect password.';

  static String get invalidEmail =>
      isIndonesian ? 'Format email tidak valid.' : 'Invalid email format.';

  static String get accountDisabled => isIndonesian
      ? 'Akun Anda sedang dinonaktifkan. Harap hubungi admin untuk informasi lebih lanjut.'
      : 'Your account has been deactivated. Please contact the admin for more information.';

  static String get passwordResetByAdmin => isIndonesian
      ? 'Password Anda telah direset oleh admin. Silakan gunakan password baru yang diberikan admin untuk login.'
      : 'Your password has been reset by the admin. Please use the new password provided by the admin to log in.';

  static String get emailSent =>
      isIndonesian ? 'Email Terkirim' : 'Email Sent';

  static String emailSentMsg(String email) => isIndonesian
      ? 'Tautan reset password telah dikirim ke $email'
      : 'Password reset link has been sent to $email';

  static String get sendFailed =>
      isIndonesian ? 'Gagal' : 'Failed';

  // ─── Terjemahan Register Page ────────────────────────────────────────────

  static String get registerTitle =>
      isIndonesian ? 'BUAT AKUN BARU' : 'CREATE NEW ACCOUNT';

  static String get registerSubtitle =>
      isIndonesian ? 'Sistem Manajemen Sekolah Modern' : 'Modern School Management System';

  static String get registerButton =>
      isIndonesian ? 'DAFTAR' : 'REGISTER';

  static String get alreadyHaveAccount =>
      isIndonesian ? 'Sudah punya akun? ' : 'Already have an account? ';

  static String get signIn => isIndonesian ? 'Masuk' : 'Sign In';

  static String get selectRole =>
      isIndonesian ? 'Pilih Peran' : 'Select Role';

  static String get schoolAdmin =>
      isIndonesian ? 'Admin Sekolah' : 'School Admin';

  static String get teacher => isIndonesian ? 'Guru' : 'Teacher';

  static String get student => isIndonesian ? 'Murid' : 'Student';

  static String get officer => isIndonesian ? 'Petugas' : 'Officer';

  static String get tu => isIndonesian ? 'TU' : 'TU';

  static String get librarian => isIndonesian ? 'Pustakawan' : 'Librarian';

  static String get schoolCode =>
      isIndonesian ? 'Kode Sekolah' : 'School Code';

  static String get fullName => isIndonesian ? 'Nama Lengkap' : 'Full Name';

  static String get selectSchool =>
      isIndonesian ? 'Pilih Sekolah' : 'Select School';

  static String get chooseSchool =>
      isIndonesian ? 'Pilih Sekolah' : 'Choose School';

  static String get searchSchool =>
      isIndonesian ? 'Cari sekolah...' : 'Search school...';

  static String get schoolNotFound =>
      isIndonesian ? 'Sekolah tidak ditemukan' : 'School not found';

  static String get confirmPassword =>
      isIndonesian ? 'Konfirmasi Password' : 'Confirm Password';

  static String get registrationFailed =>
      isIndonesian ? 'Registrasi Gagal' : 'Registration Failed';

  static String get registrationSuccess =>
      isIndonesian ? 'Registrasi Berhasil' : 'Registration Successful';

  static String get registrationSuccessMsg => isIndonesian
      ? 'Akun berhasil dibuat! Silakan login.'
      : 'Account created successfully! Please log in.';

  // ─── Terjemahan Parent Register Page ─────────────────────────────────────

  static String get parentRegisterTitle =>
      isIndonesian ? 'DAFTAR SEBAGAI ORANG TUA' : 'REGISTER AS PARENT';

  static String get parentName =>
      isIndonesian ? 'Nama Orang Tua' : 'Parent Name';

  static String get scanQR =>
      isIndonesian ? 'Scan QR Code Siswa' : 'Scan Student QR Code';

  // ─── Terjemahan School Settings Page ─────────────────────────────────────

  static String get tabAccountProfile =>
      isIndonesian ? 'Profil Akun' : 'Account Profile';

  static String get tabSchoolSettings =>
      isIndonesian ? 'Pengaturan Sekolah' : 'School Settings';

  static String get sectionSchoolLogo =>
      isIndonesian ? 'Logo Sekolah' : 'School Logo';

  static String get tapToChangeLogo =>
      isIndonesian ? 'Ketuk untuk mengganti logo sekolah' : 'Tap to change school logo';

  static String get sectionSchoolName =>
      isIndonesian ? 'Nama Sekolah' : 'School Name';

  static String get enterSchoolName =>
      isIndonesian ? 'Masukkan nama sekolah' : 'Enter school name';

  static String get sectionAccountSecurity =>
      isIndonesian ? 'Keamanan Akun' : 'Account Security';

  static String get changePassword =>
      isIndonesian ? 'Ubah Password' : 'Change Password';

  static String get leaveBlankPassword =>
      isIndonesian ? 'Biarkan kosong jika tidak ingin mengubah password.' : 'Leave blank if you do not want to change your password.';

  static String get currentPassword =>
      isIndonesian ? 'Password Saat Ini' : 'Current Password';

  static String get newPassword =>
      isIndonesian ? 'Password Baru' : 'New Password';

  static String get saveAccountProfile =>
      isIndonesian ? 'Simpan Profil Akun' : 'Save Account Profile';

  static String get sectionGradeThreshold =>
      isIndonesian ? 'Batas Nilai Rapor' : 'Report Card Grade Threshold';

  static String get minPredicateThreshold =>
      isIndonesian ? 'Atur Batas Minimum Nilai Predikat' : 'Set Minimum Grade Predicate Limit';

  static String get gradePredicateSubtitle =>
      isIndonesian ? 'Nilai minimum untuk setiap predikat yang akan ditampilkan di E-Rapor.' : 'Minimum score for each predicate to be displayed in E-Report.';

  static String get gradeA => isIndonesian ? 'Predikat A' : 'Predicate A';
  static String get gradeB => isIndonesian ? 'Predikat B' : 'Predicate B';
  static String get gradeC => isIndonesian ? 'Predikat C' : 'Predicate C';

  static String get infoMinScore =>
      isIndonesian ? 'Nilai yang dimasukkan adalah nilai minimum untuk mendapatkan predikat tersebut.' : 'The value entered is the minimum value to obtain the predicate.';

  static String get sectionAcademicCalendar =>
      isIndonesian ? 'Tahun Ajaran & Semester Aktif' : 'Academic Year & Active Semester';

  static String get calendarConfigTitle =>
      isIndonesian ? 'Konfigurasi Kalender Akademik' : 'Academic Calendar Configuration';

  static String get calendarConfigSubtitle =>
      isIndonesian ? 'Tahun ajaran dan semester aktif yang menjadi rujukan penilaian, absensi, dan cetak rapor.' : 'Active academic year and semester referred for grading, attendance, and report print.';

  static String get academicYear =>
      isIndonesian ? 'Tahun Ajaran' : 'Academic Year';

  static String get activeSemester =>
      isIndonesian ? 'Semester Aktif' : 'Active Semester';

  static String get schoolHours =>
      isIndonesian ? 'Jam Masuk Sekolah (Toleransi)' : 'School Entry Time (Tolerance)';

  static String get semesterStartDate =>
      isIndonesian ? 'Tanggal Mulai Semester' : 'Semester Start Date';

  static String get semesterStartDateSubtitle =>
      isIndonesian ? 'Sebelum tanggal ini semua input absensi & nilai akan ditolak (masa liburan). Kosongkan jika tidak ada pembatasan.' : 'Before this date, all attendance & grade input will be rejected (holiday period). Leave blank if there is no restriction.';

  static String get selectStartDate =>
      isIndonesian ? 'Pilih tanggal mulai semester...' : 'Select semester start date...';

  static String get deleteStartDate =>
      isIndonesian ? 'Hapus tanggal mulai' : 'Delete start date';

  static String get saveSchoolSettings =>
      isIndonesian ? 'Simpan Pengaturan Sekolah' : 'Save School Settings';

  static String get sectionEndSemester =>
      isIndonesian ? 'Akhiri Semester' : 'End Semester';

  static String get resetAcademicConfig =>
      isIndonesian ? 'Reset Konfigurasi Akademik' : 'Reset Academic Configuration';

  static String get resetAcademicSubtitle =>
      isIndonesian ? 'Mereset jadwal kelas, alokasi jam pelajaran, penugasan wali kelas & murid, bobot nilai, surat izin, dan data realtime control. Data nilai, absensi, dan pembayaran tetap dipertahankan.' : 'Resets class schedules, class hour allocations, homeroom & student assignments, grade weights, permit letters, and realtime control data. Grade, attendance, and payment data are preserved.';

  static String get sending => isIndonesian ? 'Mengirim...' : 'Sending...';
  static String get resetting => isIndonesian ? 'Mereset...' : 'Resetting...';

  static String get proposeEndSemester =>
      isIndonesian ? 'Ajukan Akhiri Semester' : 'Propose Ending Semester';

  static String get endSemesterNow =>
      isIndonesian ? 'Akhiri Semester Ini' : 'End This Semester';

  static String get submissionSent =>
      isIndonesian ? 'Pengajuan Terkirim' : 'Submission Sent';

  static String get waitingAdminApproval =>
      isIndonesian ? 'Menunggu persetujuan Admin Sekolah.' : 'Waiting for School Admin approval.';

  static String get incomingSubmission =>
      isIndonesian ? 'Pengajuan Masuk' : 'Incoming Submission';

  static String proposeEndSemesterMsg(String requester, String semester, String year) =>
      isIndonesian ? '$requester mengajukan untuk mengakhiri $semester $year.' : '$requester proposed to end $semester $year.';

  static String get reject => isIndonesian ? 'Tolak' : 'Reject';

  static String get approveEndSemester =>
      isIndonesian ? 'Setujui & Akhiri Semester' : 'Approve & End Semester';

  static String get settingsSaved =>
      isIndonesian ? 'Pengaturan sekolah berhasil disimpan' : 'School settings successfully saved';

  static String get profileSaved =>
      isIndonesian ? 'Profil akun berhasil disimpan' : 'Account profile successfully saved';

  static String get saveFailed =>
      isIndonesian ? 'Gagal menyimpan pengaturan' : 'Failed to save settings';

  static String get passwordIncorrect =>
      isIndonesian ? 'Password saat ini salah' : 'Current password incorrect';

  static String get passwordNotMatch =>
      isIndonesian ? 'Konfirmasi password tidak cocok' : 'Password confirmation does not match';

  static String get passwordRequired =>
      isIndonesian ? 'Password saat ini wajib diisi untuk mengubah password' : 'Current password is required to change password';

  static String get passwordMinLength =>
      isIndonesian ? 'Password baru minimal 6 karakter' : 'New password must be at least 6 characters';

  static String get schoolNameRequired =>
      isIndonesian ? 'Nama sekolah tidak boleh kosong' : 'School name cannot be empty';

  static String get proposalSent =>
      isIndonesian ? 'Pengajuan berhasil dikirim. Menunggu persetujuan Admin Sekolah.' : 'Request sent successfully. Waiting for School Admin approval.';

  static String get proposalRejected =>
      isIndonesian ? 'Pengajuan berhasil ditolak.' : 'Request successfully rejected.';

  static String get proposalRejectFailed =>
      isIndonesian ? 'Gagal menolak pengajuan' : 'Failed to reject request';

  static String get semesterEnded =>
      isIndonesian ? 'Semester berhasil diakhiri. Data kelas, jadwal, dan perizinan telah direset.' : 'Semester successfully ended. Class data, schedules, and permits have been reset.';

  static String get semesterEndFailed =>
      isIndonesian ? 'Gagal mereset semester' : 'Failed to reset semester';

  // ─── Halaman Data Guru (Teacher List Page) ──────────────────────────────────
  static String get teacherDataTitle =>
      isIndonesian ? 'Data Guru' : 'Teacher Data';

  static String get teacherSearchHint =>
      isIndonesian ? 'Cari nama guru atau NIP...' : 'Search teacher name or NIP...';

  static String get teacherAddButton =>
      isIndonesian ? 'Tambah' : 'Add';

  static String get importExcel =>
      isIndonesian ? 'Import Excel' : 'Import Excel';

  static String get errorOccurred =>
      isIndonesian ? 'Terjadi kesalahan' : 'An error occurred';

  static String get noTeacherData =>
      isIndonesian ? 'Belum ada data guru' : 'No teacher data yet';

  static String get addTeacherGuide =>
      isIndonesian ? 'Tap "Tambah" untuk mendaftarkan guru baru' : 'Tap "Add" to register a new teacher';

  static String get nipLabel =>
      isIndonesian ? 'NIP: ' : 'NIP: ';

  static String get registeredStatus =>
      isIndonesian ? 'Terdaftar' : 'Registered';

  static String get notRegisteredStatus =>
      isIndonesian ? 'Belum Registrasi' : 'Not Registered';

  // ─── Halaman Data Murid (Student List Page) ──────────────────────────────────
  static String get studentDataTitle =>
      isIndonesian ? 'Data Murid' : 'Student Data';

  static String get studentSearchHint =>
      isIndonesian ? 'Cari nama murid atau NIS...' : 'Search student name or NIS...';

  static String get noStudentData =>
      isIndonesian ? 'Belum ada data murid' : 'No student data yet';

  static String get addStudentGuide =>
      isIndonesian ? 'Tap "Tambah" untuk mendaftarkan murid baru' : 'Tap "Add" to register a new student';

  static String get nisLabel =>
      isIndonesian ? 'NIS: ' : 'NIS: ';

  static String get alumniStatus =>
      isIndonesian ? 'Alumni / Lulus' : 'Alumni / Graduated';

  // ─── Dialog Import Excel & Premium ──────────────────────────────────────────
  static String get featureLockedTitle =>
      isIndonesian ? 'Fitur Terkunci' : 'Feature Locked';

  static String get importDisabledBySuperAdmin => isIndonesian
      ? 'Fitur Import Excel dinonaktifkan oleh Super Admin. Silakan hubungi Super Admin untuk mengaktifkan akses.'
      : 'The Excel Import feature has been disabled by the Super Admin. Please contact the Super Admin to enable access.';

  static String get excelGuideTitle =>
      isIndonesian ? 'Panduan Import Excel' : 'Excel Import Guide';

  static String get excelGuideSubtitle =>
      isIndonesian ? 'Pastikan file Excel Anda memenuhi syarat berikut:' : 'Ensure your Excel file meets the following requirements:';

  static String get excelGuideFormat =>
      isIndonesian ? 'Format file harus berupa .xlsx atau .xls' : 'File format must be .xlsx or .xls';

  static String get excelGuideHeader =>
      isIndonesian ? 'Baris pertama (index 0) adalah header kolom (akan diabaikan)' : 'The first row (index 0) is the column header (will be ignored)';

  static String get excelGuideColName =>
      isIndonesian ? 'Kolom A: Nama Lengkap' : 'Column A: Full Name';

  static String get excelGuideTeacherNip =>
      isIndonesian ? 'Kolom B: NIP (Nomor Induk Pegawai)' : 'Column B: NIP (Employee ID Number)';

  static String get excelGuideStudentNis =>
      isIndonesian ? 'Kolom B: NIS (Nomor Induk Siswa)' : 'Column B: NIS (Student ID Number)';

  static String get excelGuideTeacherNipUnique =>
      isIndonesian ? 'Pastikan NIP belum terdaftar di sistem' : 'Ensure NIP is not already registered in the system';

  static String get excelGuideStudentNisUnique =>
      isIndonesian ? 'Pastikan NIS belum terdaftar di sistem' : 'Ensure NIS is not already registered in the system';

  static String get downloadExcelTemplate =>
      isIndonesian ? 'Unduh Template Excel' : 'Download Excel Template';

  static String get cancel =>
      isIndonesian ? 'Batal' : 'Cancel';

  static String get chooseFile =>
      isIndonesian ? 'Pilih File' : 'Select File';

  static String get excelTemplateSaved =>
      isIndonesian ? 'Template Excel berhasil disimpan!' : 'Excel template successfully saved!';

  static String get excelTemplateSaveFailed =>
      isIndonesian ? 'Gagal menyimpan template Excel.' : 'Failed to save Excel template.';

  static String get premiumFeatureTitle =>
      isIndonesian ? 'Fitur Premium 🌟' : 'Premium Feature 🌟';

  static String get importTeacherPremiumMsg => isIndonesian
      ? 'Fitur import data guru dari Excel hanya tersedia untuk sekolah dengan Paket BASIC atau PRO.'
      : 'The feature to import teacher data from Excel is only available for schools with BASIC or PRO packages.';

  static String get importStudentPremiumMsg => isIndonesian
      ? 'Fitur import data murid dari Excel hanya tersedia untuk sekolah dengan Paket BASIC atau PRO.'
      : 'The feature to import student data from Excel is only available for schools with BASIC or PRO packages.';

  static String get upgradePackageMsg => isIndonesian
      ? 'Silakan hubungi administrator/sales untuk melakukan upgrade paket sekolah Anda.'
      : 'Please contact the administrator/sales to upgrade your school package.';

  static String get close =>
      isIndonesian ? 'Tutup' : 'Close';

  static String get importResultTitle =>
      isIndonesian ? 'Hasil Import Excel' : 'Excel Import Result';

  static String importSuccessCount(int count) => isIndonesian
      ? 'Berhasil diimport: $count data'
      : 'Successfully imported: $count data';

  static String importFailedCount(int count) => isIndonesian
      ? 'Gagal diimport: $count data'
      : 'Failed to import: $count data';

  static String get errorDetailTitle =>
      isIndonesian ? 'Detail Error/Peringatan:' : 'Error/Warning Details:';

  static String get readingExcelData =>
      isIndonesian ? 'Membaca data dari Excel...' : 'Reading data from Excel...';

  static String importProgressMsg(int current, int total) => isIndonesian
      ? 'Mengimport $current dari $total data...'
      : 'Importing $current of $total data...';

  static String get failedProcessFile =>
      isIndonesian ? 'Gagal memproses file' : 'Failed to process file';
}
