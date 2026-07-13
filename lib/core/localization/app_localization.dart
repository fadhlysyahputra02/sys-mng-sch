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

  // ─── Dashboard & Sidebar Translations ──────────────────────────────────────
  static String get menuDashboard => isIndonesian ? 'Dashboard' : 'Dashboard';
  static String get menuERapor => isIndonesian ? 'E-Rapor' : 'E-Report Card';
  static String get menuSchedule => isIndonesian ? 'Jadwal' : 'Schedule';
  static String get menuClass => isIndonesian ? 'Kelas' : 'Class';
  static String get menuTeachingReport => isIndonesian ? 'Laporan Mengajar' : 'Teaching Report';
  static String get menuTeacherManagement => isIndonesian ? 'Manajemen Guru' : 'Teacher Management';
  static String get menuStudentManagement => isIndonesian ? 'Manajemen Siswa' : 'Student Management';
  static String get menuSubjects => isIndonesian ? 'Mata Pelajaran' : 'Subjects';
  static String get menuNotifications => isIndonesian ? 'Notifikasi' : 'Notifications';
  static String get menuStudentViolations => isIndonesian ? 'Pelanggaran Murid' : 'Student Violations';
  static String get menuSettings => isIndonesian ? 'Pengaturan' : 'Settings';
  static String get menuApprovals => isIndonesian ? 'Persetujuan' : 'Approvals';
  static String get menuOfficers => isIndonesian ? 'Petugas' : 'Officers';
  static String get menuAttendanceSummary => isIndonesian ? 'Rekap Absensi' : 'Attendance Recap';
  static String get menuGradesSummary => isIndonesian ? 'Rekap Nilai' : 'Grades Summary';
  static String get menuSemesterExam => isIndonesian ? 'Ujian Semester' : 'Semester Exam';
  static String get menuDailyAttendance => isIndonesian ? 'Absensi Harian' : 'Daily Attendance';
  static String get menuStudentAttendance => isIndonesian ? 'Absensi Murid' : 'Student Attendance';
  static String get menuChat => isIndonesian ? 'Chat' : 'Chat';
  static String get menuInputGrades => isIndonesian ? 'Input Nilai' : 'Input Grades';
  static String get menuInputViolation => isIndonesian ? 'Input Pelanggaran' : 'Input Violation';
  static String get menuTeachingSchedule => isIndonesian ? 'Jadwal Mengajar' : 'Teaching Schedule';
  static String get menuReportsAndCards => isIndonesian ? 'Laporan & Rapor' : 'Reports & Report Cards';
  static String get menuTaskManagement => isIndonesian ? 'Manajemen Tugas' : 'Task Management';
  static String get menuProfileSettings => isIndonesian ? 'Pengaturan Profil' : 'Profile Settings';
  static String get menuLibrary => isIndonesian ? 'Perpustakaan' : 'Library';
  static String get menuRealtimeControl => isIndonesian ? 'Kontrol Aktifitas' : 'Realtime Control';
  static String get menuScanDailyAttendance => isIndonesian ? 'Scan Absensi Harian' : 'Scan Daily Attendance';
  static String get menuStudentPermit => isIndonesian ? 'Surat Izin Siswa' : 'Student Permit';
  static String get menuOnlineExam => isIndonesian ? 'Ujian Online' : 'Online Exam';
  static String get menuPayment => isIndonesian ? 'Pembayaran' : 'Payment';

  // ─── Student Dashboard Translations ──────────────────────────────────────
  static String get menuStudentMain => isIndonesian ? 'Menu Utama' : 'Main Menu';
  static String get menuMySchedule => isIndonesian ? 'Jadwal Saya' : 'My Schedule';
  static String get menuMyQRCard => isIndonesian ? 'Kartu QR Saya' : 'My QR Card';
  static String get menuFinanceAndSPP => isIndonesian ? 'Keuangan & SPP' : 'Finance & Tuition';
  static String get menuMyTasks => isIndonesian ? 'Tugas Saya' : 'My Tasks';
  static String get menuGrades => isIndonesian ? 'Nilai' : 'Grades';
  static String get menuAttendance => isIndonesian ? 'Absensi' : 'Attendance';
  static String get menuTeacherChat => isIndonesian ? 'Chat Guru' : 'Teacher Chat';
  static String get menuViolations => isIndonesian ? 'Pelanggaran' : 'Violations';
  static String get menuDigitalPermit => isIndonesian ? 'Surat Izin Digital' : 'Digital Permit';
  static String get menuSemesterExamSchedule => isIndonesian ? 'Jadwal Ujian Semester' : 'Semester Exam Schedule';
  // ─── Parent Dashboard Translations ──────────────────────────────────────
  static String get menuAttendanceList => isIndonesian ? 'Daftar Hadir' : 'Attendance List';
  static String get menuClassSchedule => isIndonesian ? 'Jadwal Kelas' : 'Class Schedule';
  static String get menuChildGrades => isIndonesian ? 'Nilai Anak' : 'Child\'s Grades';
  static String get menuChildTasks => isIndonesian ? 'Tugas Anak' : 'Child\'s Tasks';
  static String get menuChildOnlineExam => isIndonesian ? 'Ujian Online Anak' : 'Child\'s Online Exam';
  static String get menuInformation => isIndonesian ? 'Informasi' : 'Information';
  static String get menuTuitionBills => isIndonesian ? 'Tagihan SPP & Keuangan' : 'Tuition Bills & Finance';
  // ─── Librarian Dashboard Translations ──────────────────────────────────────
  static String get menuLibraryDashboard => isIndonesian ? 'Dashboard Perpustakaan' : 'Library Dashboard';
  static String get menuHome => isIndonesian ? 'Beranda' : 'Home';
  static String get menuBooks => isIndonesian ? 'Buku' : 'Books';
  static String get menuLoans => isIndonesian ? 'Peminjaman' : 'Loans';
  static String get menuGuestBook => isIndonesian ? 'Buku Tamu' : 'Guest Book';
  static String get logoutConfirmLibrarian => isIndonesian ? 'Apakah Anda yakin ingin keluar dari akun perpustakaan?' : 'Are you sure you want to log out of the library account?';
  static String get logoutConfirmTitle => isIndonesian ? 'Konfirmasi Keluar' : 'Confirm Logout';
  static String get logout => isIndonesian ? 'Keluar' : 'Logout';
  static String get officerLabel => isIndonesian ? 'Petugas' : 'Officer';
  // ─── Officer Dashboard Translations ──────────────────────────────────────
  static String get menuQuickMenu => isIndonesian ? 'Menu Cepat' : 'Quick Menu';
  static String get menuScanStudentIn => isIndonesian ? 'Scan Murid\n(Masuk)' : 'Scan Student\n(In)';
  static String get menuScanStudentOut => isIndonesian ? 'Scan Murid\n(Pulang)' : 'Scan Student\n(Out)';
  static String get menuManualStudentIn => isIndonesian ? 'Absen Manual\nMurid (Masuk)' : 'Manual Attend\nStudent (In)';
  static String get menuManualStudentOut => isIndonesian ? 'Absen Manual\nMurid (Pulang)' : 'Manual Attend\nStudent (Out)';
  static String get menuTeacherAttendance => isIndonesian ? 'Absensi Guru' : 'Teacher Attendance';
  static String get menuScanTeacherIn => isIndonesian ? 'Scan Guru\n(Masuk)' : 'Scan Teacher\n(In)';
  static String get menuScanTeacherOut => isIndonesian ? 'Scan Guru\n(Pulang)' : 'Scan Teacher\n(Out)';
  static String get menuManualTeacherIn => isIndonesian ? 'Absen Manual\nGuru (Masuk)' : 'Manual Attend\nTeacher (In)';
  static String get menuManualTeacherOut => isIndonesian ? 'Absen Manual\nGuru (Pulang)' : 'Manual Attend\nTeacher (Out)';
  static String get menuStudentSummary => isIndonesian ? 'Rekap Murid' : 'Student Summary';
  static String get menuTeacherSummary => isIndonesian ? 'Rekap Guru' : 'Teacher Summary';

  // ─── Teacher Dashboard Translations ────────────────────────────────────────
  static String get greetingMorning => isIndonesian ? 'Selamat Pagi' : 'Good Morning';
  static String get greetingAfternoon => isIndonesian ? 'Selamat Siang' : 'Good Afternoon';
  static String get greetingEvening => isIndonesian ? 'Selamat Sore' : 'Good Evening';
  static String get greetingNight => isIndonesian ? 'Selamat Malam' : 'Good Night';

  static String get classesTaught => isIndonesian ? 'Kelas Mengajar' : 'Classes Taught';
  static String get todaySchedule => isIndonesian ? 'Jadwal Hari Ini' : 'Today\'s Schedule';
  static String get mySubjects => isIndonesian ? 'Mata Pelajaran Saya' : 'My Subjects';
  static String get noScheduleToday => isIndonesian ? 'Tidak ada jadwal hari ini' : 'No schedule today';
  static String get noSubjectsYet => isIndonesian ? 'Belum ada mata pelajaran' : 'No subjects yet';
  static String get menuStudentList => isIndonesian ? 'Daftar Siswa' : 'Student List';
  static String get homeroomLabel => isIndonesian ? 'Wali Kelas' : 'Homeroom';
  static String get academicYearLabel => isIndonesian ? 'Tahun Ajaran' : 'Academic Year';

  // ─── Teacher Schedule Page ───────────────────────────────────────────────────
  static String get teachingScheduleTitle => isIndonesian ? 'Jadwal Mengajar' : 'Teaching Schedule';
  static String get noScheduleForDay => isIndonesian ? 'Tidak ada jadwal mengajar pada hari' : 'No teaching schedule on';
  static String get restLabel => isIndonesian ? 'Istirahat' : 'Break';
  static String get restTimeLabel => isIndonesian ? 'Waktunya Istirahat & Santai' : 'Break & Relax Time';
  static String get scheduleErrorLabel => isIndonesian ? 'Terjadi kesalahan memuat jadwal' : 'Error loading schedule';
  static List<String> get dayNames => isIndonesian
      ? ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu']
      : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static List<String> get monthNames => isIndonesian
      ? ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
      : ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  // ─── Teacher Daily Attendance Page ───────────────────────────────────────────
  static String get myDailyAttendanceTitle => isIndonesian ? 'Absensi Harian Anda' : 'Your Daily Attendance';
  static String get attendanceHistoryTitle => isIndonesian ? 'Riwayat Absensi' : 'Attendance History';
  static String get todayPresenceLabel => isIndonesian ? 'Presensi Hari Ini' : 'Today\'s Presence';
  static String get checkInLabel => isIndonesian ? 'Jam Masuk' : 'Check-In';
  static String get checkOutLabel => isIndonesian ? 'Jam Pulang' : 'Check-Out';
  static String get monthlyAttendanceHistory => isIndonesian ? 'Riwayat Kehadiran Bulanan' : 'Monthly Attendance History';
  static String get selectMonthYear => isIndonesian ? 'Pilih Bulan & Tahun' : 'Select Month & Year';
  static String get monthLabel => isIndonesian ? 'Bulan' : 'Month';
  static String get yearLabel => isIndonesian ? 'Tahun' : 'Year';
  static String get notYetCheckedOut => isIndonesian ? 'Belum Pulang' : 'Not Yet Checked Out';
  static String get notYetCheckedIn => isIndonesian ? 'Belum Absen' : 'Not Checked In';
  static String get absentNoRecord => isIndonesian ? 'Tidak Hadir (Tanpa Keterangan)' : 'Absent (No Record)';
  static String get absentDeadlinePassed => isIndonesian ? 'Tidak Hadir (Batas Absen Lewat)' : 'Absent (Deadline Passed)';
  static String get upcomingSchedule => isIndonesian ? 'Jadwal Mengajar Mendatang' : 'Upcoming Schedule';
  static String get upcomingLabel => isIndonesian ? 'Mendatang' : 'Upcoming';
  static String get byAdmin => isIndonesian ? 'Oleh Admin' : 'By Admin';
  static String get noFutureHistory => isIndonesian ? 'Tidak ada riwayat absensi untuk periode mendatang.' : 'No attendance history for future periods.';

  // Attendance Status labels
  static String get statusPresent => isIndonesian ? 'Hadir' : 'Present';
  static String get statusLate => isIndonesian ? 'Terlambat' : 'Late';
  static String get statusSick => isIndonesian ? 'Sakit' : 'Sick';
  static String get statusPermit => isIndonesian ? 'Izin' : 'Permit';
  static String get statusAbsent => isIndonesian ? 'Alfa' : 'Absent';

  // ─── Teacher Attendance Schedule Page (Absensi Murid) ────────────────────────
  static String get studentAttendanceTitle => isIndonesian ? 'Absensi Murid' : 'Student Attendance';
  static String get chooseDate => isIndonesian ? 'Pilih Tanggal' : 'Choose Date';
  static String get allClasses => isIndonesian ? 'Semua Kelas' : 'All Classes';
  static String get classStatusDone => isIndonesian ? 'Selesai' : 'Done';
  static String get classStatusUpcoming => isIndonesian ? 'Mendatang' : 'Upcoming';
  static String get classStatusOngoing => isIndonesian ? 'Berlangsung' : 'Ongoing';
  static String get subjectLabel => isIndonesian ? 'Pelajaran' : 'Subject';
  static String get classLabel => isIndonesian ? 'Kelas' : 'Class';
  static String get activeSubjectNow => isIndonesian ? 'MATA PELAJARAN AKTIF SEKARANG' : 'ACTIVE SUBJECT NOW';
  static String get todayAttendanceRecap => isIndonesian ? 'REKAP ABSENSI HARI INI' : 'TODAY\'S ATTENDANCE RECAP';
  static String get attendanceRecapDate => isIndonesian ? 'REKAP ABSENSI TANGGAL' : 'ATTENDANCE RECAP BY DATE';
  static String get noActiveSubjectNow => isIndonesian ? 'Tidak ada mata pelajaran aktif di jam sekarang.' : 'No active subjects at the current time.';
  static String get openQrAttendance => isIndonesian ? 'BUKA PRESENSI QR & SCAN' : 'OPEN QR ATTENDANCE & SCAN';
  static String get noTeachingScheduleDate => isIndonesian ? 'Tidak ada jadwal mengajar untuk hari/tanggal ini.' : 'No teaching schedule for this day/date.';
  static String get studentsPresent => isIndonesian ? 'Murid Hadir' : 'Students Present';
  static String get serverTimeLabel => isIndonesian ? 'Waktu Server' : 'Server Time';
  static String get noScheduleForRecap => isIndonesian ? 'Tidak ada jadwal mengajar untuk mengunduh rekap.' : 'No teaching schedule to download recap.';
  static String get featureLocked => isIndonesian ? 'Fitur Terkunci' : 'Feature Locked';
  static String get featureLockedDesc => isIndonesian ? 'Sekolah belum berlangganan untuk mengaktifkan fitur ini.' : 'The school has not subscribed to activate this feature.';
  static String get previewRecapTitle => isIndonesian ? 'Preview Rekapan' : 'Recap Preview';
  static String get noAttendanceData => isIndonesian ? 'Tidak ada data absensi untuk ditampilkan.' : 'No attendance data to display.';
  static String get dailyAttendanceDetail => isIndonesian ? 'Detail Kehadiran Harian' : 'Daily Attendance Detail';
  static String get studentNameLabel => isIndonesian ? 'Nama Siswa' : 'Student Name';
  static String get totalPresentLabel => isIndonesian ? 'Total Hadir' : 'Total Present';
  static String get periodLabel => isIndonesian ? 'Periode' : 'Period';
  static String get qrCodeAttendanceTitle => isIndonesian ? 'QR Code Absensi' : 'QR Code Attendance';
  static String get scanQrToAttend => isIndonesian ? 'Scan QR Code di atas untuk absen' : 'Scan the QR Code above to check in';
  static String get attendancePassed => isIndonesian ? 'Presensi Selesai / Terlewat' : 'Attendance Completed / Overdue';
  static String get qrDisabledDesc => isIndonesian ? 'Pembuatan QR Code dinonaktifkan karena jam pelajaran telah selesai atau tanggal pelaksanaan telah berlalu.' : 'QR Code generation is disabled because the class time has ended or the date has passed.';
  static String get studentsPresentRealtime => isIndonesian ? 'Murid Hadir (Real-time)' : 'Students Present (Real-time)';
  static String get studentsPresentHistory => isIndonesian ? 'Murid Hadir (Riwayat)' : 'Students Present (History)';
  static String get editModeActive => isIndonesian ? 'Mode Edit Aktif' : 'Edit Mode Active';
  static String get waitingApproval => isIndonesian ? 'Menunggu Persetujuan' : 'Waiting for Approval';
  static String get editAttendance => isIndonesian ? 'Edit Absensi' : 'Edit Attendance';
  static String get noStudentsInClass => isIndonesian ? 'Belum ada murid di kelas ini' : 'No students in this class yet';
  static String get editRequestNeeded => isIndonesian ? 'Harap ajukan izin "Edit Absensi" dan disetujui Admin/TU terlebih dahulu.' : 'Please request "Edit Attendance" and obtain Admin/TU approval first.';
  static String get editRequestNeededPast => isIndonesian ? 'Harap ajukan izin "Edit Absensi" dan disetujui Admin/TU terlebih dahulu untuk tanggal lampau.' : 'Please request "Edit Attendance" and obtain Admin/TU approval first for past dates.';
  static String get noPresenceRecordedYet => isIndonesian ? 'Belum melakukan presensi (Klik untuk atur)' : 'No attendance recorded yet (Click to set)';
  static String get reportCompleted => isIndonesian ? 'Laporan Selesai Diisi' : 'Report Completed';
  static String get fillReport => isIndonesian ? 'Isi Laporan' : 'Fill Report';
  static String get cannotSaveIncomplete => isIndonesian ? 'Tidak dapat menyimpan: data jadwal atau tanggal tidak lengkap.' : 'Cannot save: schedule data or date is incomplete.';
  static String get setDetail => isIndonesian ? 'Beri Keterangan' : 'Set Details';
  static String get setPresenceFor => isIndonesian ? 'Atur kehadiran untuk' : 'Set attendance for';
  static String get cancel => isIndonesian ? 'Batal' : 'Cancel';
  static String get requestEditTitle => isIndonesian ? 'Ajukan Izin Edit Absensi' : 'Request Attendance Edit Permission';
  static String get editReasonLabel => isIndonesian ? 'Alasan Koreksi / Edit' : 'Correction / Edit Reason';
  static String get reasonNotEmpty => isIndonesian ? 'Alasan tidak boleh kosong' : 'Reason cannot be empty';
  static String get editRequestSuccess => isIndonesian ? 'Pengajuan izin edit berhasil dikirim ke Admin/TU' : 'Edit request successfully sent to Admin/TU';
  static String get submitRequest => isIndonesian ? 'Kirim Pengajuan' : 'Submit Request';
  static String get teachingReportTitle => isIndonesian ? 'Laporan Mengajar' : 'Teaching Report';
  static String get topicTaughtLabel => isIndonesian ? 'Materi yang diajarkan' : 'Topic Taught';
  static String get optionalNotesLabel => isIndonesian ? 'Catatan tambahan (Opsional)' : 'Additional notes (Optional)';
  static String get topicNotEmpty => isIndonesian ? 'Materi tidak boleh kosong' : 'Topic cannot be empty';
  static String get reportSaveSuccess => isIndonesian ? 'Laporan berhasil disimpan' : 'Report saved successfully';
  static String get save => isIndonesian ? 'Simpan' : 'Save';
  static String get downloadRecap => isIndonesian ? 'Unduh Rekap Absen' : 'Download Attendance Recap';
  static String get selectMonthClassForRecap => isIndonesian ? 'Pilih bulan dan kelas untuk rekapitulasi' : 'Select month and class for recap';
  static String get previewRecap => isIndonesian ? 'Lihat Rekapan' : 'Preview Recap';
  static String get download => isIndonesian ? 'Unduh' : 'Download';

  // Grades Section
  static String get gradesBookTitle => isIndonesian ? 'Buku Nilai' : 'Gradebook';
  static String get filterGrades => isIndonesian ? 'Filter Penilaian' : 'Filter Grades';
  static String get noGradesYet => isIndonesian ? 'Belum ada penilaian yang dibuat' : 'No grades created yet';
  static String get tapPlusToInsert => isIndonesian ? 'Tekan tombol "+" di bawah untuk memasukkan nilai baru.' : 'Tap the "+" button below to insert new grades.';
  static String get editGrade => isIndonesian ? 'Edit Nilai' : 'Edit Grade';
  static String get deleteGrade => isIndonesian ? 'Hapus Penilaian' : 'Delete Grade';
  static String get deleteGradeConfirm => isIndonesian ? 'Apakah Anda yakin ingin menghapus penilaian ini beserta seluruh nilai siswa di dalamnya? Tindakan ini tidak dapat dibatalkan.' : 'Are you sure you want to delete this grade along with all student scores in it? This action cannot be undone.';
  static String get gradeDeleted => isIndonesian ? 'Penilaian berhasil dihapus' : 'Grade successfully deleted';
  static String get gradeDeleteFailed => isIndonesian ? 'Gagal menghapus penilaian' : 'Failed to delete grade';
  static String get inputNewGradeTitle => isIndonesian ? 'Input Nilai Baru' : 'Input New Grade';
  static String get editGradeTitle => isIndonesian ? 'Ubah Penilaian' : 'Edit Grade';
  static String get selectCategoryFirst => isIndonesian ? 'Pilih kategori penilaian terlebih dahulu' : 'Please select a grade category first';
  static String get gradeSavedSuccess => isIndonesian ? 'Penilaian berhasil disimpan' : 'Grade successfully saved';
  static String get gradeUpdatedSuccess => isIndonesian ? 'Penilaian berhasil diperbarui' : 'Grade successfully updated';
  static String get gradeSaveFailed => isIndonesian ? 'Gagal menyimpan penilaian' : 'Failed to save grade';
  static String get categoryLabel => isIndonesian ? 'Kategori Penilaian' : 'Grade Category';
  static String get gradeTitlePlaceholder => isIndonesian ? 'Judul Penilaian (contoh: Tugas 1)' : 'Grade Title (e.g. Assignment 1)';
  static String get enterGradeTitle => isIndonesian ? 'Masukkan judul penilaian' : 'Please enter a grade title';
  static String get maxScoreLabel => isIndonesian ? 'Nilai Maksimum' : 'Maximum Score';
  static String get invalidScore => isIndonesian ? 'Nilai tidak valid' : 'Invalid score';
  static String get gradeDateLabel => isIndonesian ? 'Tanggal Penilaian' : 'Grade Date';
  static String get studentGradeListLabel => isIndonesian ? 'Daftar Nilai Siswa' : 'Student Grade List';
  static String get wrongScoreRange => isIndonesian ? 'Salah' : 'Invalid';
  static String get studentNotePlaceholder => isIndonesian ? 'Tulis catatan pencapaian siswa... (opsional)' : 'Write student achievement notes... (optional)';
  static String get saveChanges => isIndonesian ? 'Simpan Perubahan' : 'Save Changes';
  static String get saveGrade => isIndonesian ? 'Simpan Penilaian' : 'Save Grade';
  static String get setWeights => isIndonesian ? 'Atur Bobot' : 'Set Weights';
  static String get reset => isIndonesian ? 'Reset' : 'Reset';


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

  static String get error =>
      isIndonesian ? 'Gagal' : 'Error';

  static String get passwordValidationMinLength =>
      isIndonesian ? 'Minimal 6 karakter' : 'At least 6 characters';

  static String get passwordValidationUppercase =>
      isIndonesian ? 'Memiliki huruf besar (A-Z)' : 'Has uppercase letter (A-Z)';

  static String get passwordValidationLowercase =>
      isIndonesian ? 'Memiliki huruf kecil (a-z)' : 'Has lowercase letter (a-z)';

  static String get passwordValidationNumber =>
      isIndonesian ? 'Memiliki angka (0-9)' : 'Has number (0-9)';

  static String get passwordValidationSpecialChar =>
      isIndonesian ? 'Memiliki karakter khusus (!@#\$%^&* dll)' : 'Has special character (!@#\$%^&* etc)';

  static String get passwordSameAsCurrent =>
      isIndonesian ? 'Password baru tidak boleh sama dengan password saat ini' : 'New password cannot be the same as current password';

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
      isIndonesian ? 'Kolom A: Nama Lengkap (Wajib)' : 'Column A: Full Name (Required)';

  static String get excelGuideTeacherNip =>
      isIndonesian ? 'Kolom B: NIP / Nomor Induk Pegawai (Wajib)' : 'Column B: NIP / Employee ID (Required)';

  static String get excelGuideStudentNis =>
      isIndonesian ? 'Kolom B: NIS / Nomor Induk Siswa (Wajib)' : 'Column B: NIS / Student ID (Required)';

  static String get excelGuideGender =>
      isIndonesian ? 'Kolom C: Jenis Kelamin (Opsional, isi L atau P)' : 'Column C: Gender (Optional, fill L or P)';

  static String get excelGuideAddress =>
      isIndonesian ? 'Kolom D: Alamat (Opsional)' : 'Column D: Address (Optional)';

  static String get excelGuideStudentDob =>
      isIndonesian ? 'Kolom E: Tanggal Lahir (Opsional)' : 'Column E: Date of Birth (Optional)';

  static String get excelGuideStudentBatch =>
      isIndonesian ? 'Kolom F: Tahun Angkatan (Opsional)' : 'Column F: Batch Year (Optional)';

  static String get excelGuideTeacherNipUnique =>
      isIndonesian ? 'Pastikan NIP belum terdaftar di sistem' : 'Ensure NIP is not already registered in the system';

  static String get excelGuideStudentNisUnique =>
      isIndonesian ? 'Pastikan NIS belum terdaftar di sistem' : 'Ensure NIS is not already registered in the system';

  static String get downloadExcelTemplate =>
      isIndonesian ? 'Unduh Template Excel' : 'Download Excel Template';


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
