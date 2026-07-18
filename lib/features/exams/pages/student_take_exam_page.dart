import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../../core/localization/app_localization.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../students/data/student_service.dart';
import '../models/exam_model.dart';
import '../services/exam_service.dart';
import 'package:is_lock_screen2/is_lock_screen2.dart';
import '../services/exam_behavior_service.dart';
import '../services/exam_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StudentTakeExamPage extends StatefulWidget {
  final Exam exam;
  final String? studentDocId;
  final String? sessionId;
  final String? schoolId;
  /// Format "HH:mm" — jam mulai sesi ujian
  final String? sessionStartTime;
  /// Format "HH:mm" — jam selesai sesi ujian
  final String? sessionEndTime;
  final DateTime? sessionDate;
  /// examStatus dari ExamSession (e.g. 'Active', 'Scheduled')
  final String? sessionExamStatus;
  final int? seatNumber;
  final String? roomName;
  /// Tipe ujian dari ExamEvent (e.g. 'UTS', 'UAS')
  final String? examType;

  const StudentTakeExamPage({
    super.key,
    required this.exam,
    this.studentDocId,
    this.sessionId,
    this.schoolId,
    this.sessionStartTime,
    this.sessionEndTime,
    this.sessionDate,
    this.sessionExamStatus,
    this.seatNumber,
    this.roomName,
    this.examType,
  });

  @override
  State<StudentTakeExamPage> createState() => _StudentTakeExamPageState();
}

class _StudentTakeExamPageState extends State<StudentTakeExamPage> with WidgetsBindingObserver {
  final _examService = ExamService();
  final _behaviorService = ExamBehaviorService();
  final _studentService = StudentService();

  bool _hasStarted = false;
  int _currentQuestionIndex = 0;
  final Map<String, int> _selectedAnswers = {}; // Map questionId -> optionIndex
  final Map<String, String> _essayAnswers = {}; // Map questionId -> essayAnswerText
  final ScrollController _pgNavScrollCtrl = ScrollController();
  final ScrollController _essayNavScrollCtrl = ScrollController();
  List<ExamQuestion> _questions = [];

  int _secondsRemaining = 0;
  Timer? _timer;
  bool _isSubmitting = false;

  // Cache untuk behavior_records (kontrol aktifitas guru)
  String? _cachedScheduleId;
  String? _cachedSubjectNameForBehavior;

  String _tahunAjaran = '';
  String _semester = '';

  Future<void> _loadSchoolMetadata() async {
    try {
      if (widget.schoolId != null) {
        final schoolDoc = await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).get();
        if (schoolDoc.exists && schoolDoc.data() != null) {
          final data = schoolDoc.data()!;
          if (mounted) {
            setState(() {
              _tahunAjaran = data['tahunAjaran']?.toString() ?? '';
              _semester = data['semester']?.toString() ?? '';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading school metadata: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    final studentId = widget.studentDocId ?? SessionService.currentUser?.uid ?? 'unknown_student';
    final pgQuestions = widget.exam.questions.where((q) => q.type != 'essay').toList();
    final essayQuestions = widget.exam.questions.where((q) => q.type == 'essay').toList();

    if (widget.exam.shufflePg) {
      pgQuestions.shuffle(Random(studentId.hashCode));
    }
    if (widget.exam.shuffleEssay) {
      essayQuestions.shuffle(Random(studentId.hashCode + 1));
    }

    _questions = [...pgQuestions, ...essayQuestions];
    SessionService.isTakingExam = true;
    _loadSchoolMetadata();
    final defaultSeconds = widget.exam.durationMinutes * 60;
    int calculatedSeconds = defaultSeconds;

    if (widget.sessionEndTime != null && widget.sessionDate != null) {
      try {
        final parts = widget.sessionEndTime!.split(':');
        if (parts.length >= 2) {
          final endHour = int.parse(parts[0]);
          final endMin = int.parse(parts[1]);
          final sessionEnd = DateTime(
            widget.sessionDate!.year,
            widget.sessionDate!.month,
            widget.sessionDate!.day,
            endHour,
            endMin,
          );
          final now = DateTime.now();
          final remainingSec = sessionEnd.difference(now).inSeconds;
          if (remainingSec > 0 && remainingSec < defaultSeconds) {
            calculatedSeconds = remainingSec;
          } else if (remainingSec <= 0) {
            calculatedSeconds = 0; // force immediate submission without time left
          }
        }
      } catch (_) {}
    }
    _secondsRemaining = calculatedSeconds;
    WidgetsBinding.instance.addObserver(this);
    _loadDraftAnswers();
  }

  Future<void> _loadDraftAnswers() async {
    try {
      final user = SessionService.currentUser;
      if (user == null) return;
      final studentId = widget.studentDocId ?? user.uid;
      final prefs = await SharedPreferences.getInstance();

      final mcKey = 'exam_draft_mc_${studentId}_${widget.exam.id}';
      final essayKey = 'exam_draft_essay_${studentId}_${widget.exam.id}';
      final startedKey = 'exam_draft_started_${studentId}_${widget.exam.id}';

      final mcRaw = prefs.getString(mcKey);
      final essayRaw = prefs.getString(essayKey);
      final draftStarted = prefs.getBool(startedKey) ?? false;

      if (mcRaw != null && mcRaw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(mcRaw);
        decoded.forEach((key, val) {
          if (val is int) {
            _selectedAnswers[key] = val;
          }
        });
      }
      if (essayRaw != null && essayRaw.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(essayRaw);
        decoded.forEach((key, val) {
          if (val is String) {
            _essayAnswers[key] = val;
          }
        });
      }

      if (draftStarted) {
        _hasStarted = true;
        if (_secondsRemaining <= 0) {
          _autoSubmit();
        } else {
          _startTimer();
        }
      }

      if (mounted) {
        setState(() {});
      }
      debugPrint('Draft answers loaded: MC: ${_selectedAnswers.length}, Essay: ${_essayAnswers.length}, Started: $draftStarted');
    } catch (e) {
      debugPrint('Failed to load draft answers: $e');
    }
  }

  Future<void> _saveDraftAnswers() async {
    try {
      final user = SessionService.currentUser;
      if (user == null) return;
      final studentId = widget.studentDocId ?? user.uid;
      final prefs = await SharedPreferences.getInstance();

      final mcKey = 'exam_draft_mc_${studentId}_${widget.exam.id}';
      final essayKey = 'exam_draft_essay_${studentId}_${widget.exam.id}';
      final startedKey = 'exam_draft_started_${studentId}_${widget.exam.id}';

      await prefs.setString(mcKey, jsonEncode(_selectedAnswers));
      await prefs.setString(essayKey, jsonEncode(_essayAnswers));
      await prefs.setBool(startedKey, _hasStarted);
      debugPrint('Draft answers auto-saved.');
    } catch (e) {
      debugPrint('Failed to auto-save draft answers: $e');
    }
  }

  Future<void> _clearDraftAnswers() async {
    try {
      final user = SessionService.currentUser;
      if (user == null) return;
      final studentId = widget.studentDocId ?? user.uid;
      final prefs = await SharedPreferences.getInstance();

      final mcKey = 'exam_draft_mc_${studentId}_${widget.exam.id}';
      final essayKey = 'exam_draft_essay_${studentId}_${widget.exam.id}';
      final startedKey = 'exam_draft_started_${studentId}_${widget.exam.id}';

      await prefs.remove(mcKey);
      await prefs.remove(essayKey);
      await prefs.remove(startedKey);
      debugPrint('Draft answers cleared.');
    } catch (e) {
      debugPrint('Failed to clear draft answers: $e');
    }
  }

  String? _lastReportedType;

  /// Resolusi scheduleId aktif dari class_schedules agar bisa dipakai untuk menulis
  /// ke behavior_records (halaman Kontrol Aktifitas guru) saat murid sedang ujian.
  Future<void> _loadScheduleInfoForBehavior() async {
    try {
      if (widget.schoolId == null) return;
      final user = SessionService.currentUser;
      if (user == null) return;
      final studentId = widget.studentDocId ?? user.uid;

      // Cari dokumen behavior_records yang sudah ada milik murid ini
      // agar kita memperbarui dokumen yang SAMA yang sedang ditonton oleh guru.
      // Urutkan client-side untuk menghindari kebutuhan composite index.
      final behaviorSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId!)
          .collection('behavior_records')
          .where('studentId', isEqualTo: studentId)
          .limit(10)
          .get();

      if (behaviorSnap.docs.isNotEmpty) {
        // Ambil dokumen dengan timestamp paling baru (client-side sort)
        final sorted = behaviorSnap.docs.toList()
          ..sort((a, b) {
            final aTs = (a.data()['timestamp'] as Timestamp?)?.seconds ?? 0;
            final bTs = (b.data()['timestamp'] as Timestamp?)?.seconds ?? 0;
            return bTs.compareTo(aTs);
          });
        final data = sorted.first.data();
        _cachedScheduleId = data['scheduleId'] as String?;
        _cachedSubjectNameForBehavior = data['subjectName'] as String?;
        debugPrint('_loadScheduleInfoForBehavior: found scheduleId=$_cachedScheduleId subjectName=$_cachedSubjectNameForBehavior');
      }

      // Fallback jika tidak ada behavior_records sebelumnya (murid belum absen)
      _cachedScheduleId ??= 'exam_${widget.exam.id}';
      _cachedSubjectNameForBehavior ??= widget.exam.subjectName;
    } catch (e) {
      debugPrint('_loadScheduleInfoForBehavior error: $e');
      _cachedScheduleId = 'exam_${widget.exam.id}';
      _cachedSubjectNameForBehavior = widget.exam.subjectName;
    }
  }

  /// Menulis status ke behavior_records agar tampil di halaman Kontrol Aktifitas guru.
  /// Dipanggil paralel dengan _reportStatus (exam_behavior_records).
  Future<void> _reportDashboardBehavior(String type, String description) async {
    try {
      if (widget.schoolId == null) return;
      final user = SessionService.currentUser;
      if (user == null) return;
      final studentId = widget.studentDocId ?? user.uid;
      final scheduleId = _cachedScheduleId ?? 'exam_${widget.exam.id}';
      final subjectName = _cachedSubjectNameForBehavior ?? widget.exam.subjectName;

      await _studentService.reportBehaviorViolation(
        schoolId: widget.schoolId!,
        studentId: studentId,
        studentName: user.nama,
        className: widget.exam.className,
        scheduleId: scheduleId,
        subjectName: subjectName,
        type: type,
        description: description,
        tahunAjaran: _tahunAjaran,
        semester: _semester,
      );
    } catch (e) {
      debugPrint('_reportDashboardBehavior error: $e');
    }
  }

  Future<void> _reportStatus(String type, String description) async {
    if (widget.sessionId == null || widget.schoolId == null) return;
    if (_lastReportedType == type) return;
    _lastReportedType = type;

    final user = SessionService.currentUser;
    if (user == null) return;
    final studentId = widget.studentDocId ?? user.uid;
    final studentName = user.nama;
    final className = widget.exam.className;
    final subjectName = widget.exam.subjectName;
    final roomName = widget.roomName ?? 'Ruang Ujian';
    final seatNumber = widget.seatNumber ?? 0;

    // Gunakan metadata yang sudah di-cache saat initState (tidak fetch ulang ke Firestore)
    // agar bisa selesai sebelum OS menghentikan proses async saat app di-background.
    await _behaviorService.reportExamBehavior(
      schoolId: widget.schoolId!,
      studentId: studentId,
      studentName: studentName,
      className: className,
      sessionId: widget.sessionId!,
      subjectName: subjectName,
      roomName: roomName,
      seatNumber: seatNumber,
      type: type,
      description: description,
      tahunAjaran: _tahunAjaran,
      semester: _semester,
    );
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (!_hasStarted || _isSubmitting) return;

    if (state == AppLifecycleState.resumed) {
      // Murid kembali ke aplikasi — update kedua koleksi
      _reportStatus('Standby', 'Murid kembali mengerjakan ujian');
      _reportDashboardBehavior('Standby', 'Murid kembali mengerjakan ujian (Ujian Online)');
    } else if (state == AppLifecycleState.paused) {
      // Android: murid keluar dari aplikasi — langsung tulis ke kedua koleksi
      _reportStatus('Keluar', 'Murid keluar dari aplikasi ujian (Home/Recent)');
      _reportDashboardBehavior(
        'Meninggalkan Layar Absensi',
        'Murid terdeteksi meninggalkan aplikasi saat mengerjakan ujian online ${widget.exam.subjectName}.',
      );
    } else if (state == AppLifecycleState.inactive) {
      // Bisa lock-screen, notif panel, atau perpindahan app
      await Future.delayed(const Duration(milliseconds: 300));
      bool isLocked = false;
      try {
        final locked = await isLockScreen();
        if (locked == true) isLocked = true;
      } catch (_) {}

      if (isLocked) {
        _reportStatus('Screen Off', 'Layar murid terkunci atau mati');
        _reportDashboardBehavior(
          'Layar Mati / Device Terkunci',
          'Device murid mati atau layar terkunci saat mengerjakan ujian online ${widget.exam.subjectName}.',
        );
      }
      // Jika tidak terkunci, tunggu state paused yang pasti datang berikutnya
    }
  }

  Future<void> _startExam() async {
    setState(() {
      _hasStarted = true;
    });
    // Tunggu sampai scheduleId di-cache sebelum menulis ke behavior_records
    await _loadScheduleInfoForBehavior();
    _reportStatus('Standby', 'Murid mulai mengerjakan ujian');
    _reportDashboardBehavior('Standby', 'Murid mulai mengerjakan ujian online ${widget.exam.subjectName}');

    // Mark as started in exam session participations collection
    try {
      final user = SessionService.currentUser;
      if (user != null && widget.schoolId != null && widget.sessionId != null) {
        final studentId = widget.studentDocId ?? user.uid;
        await ExamSessionService().markStudentStarted(
          schoolId: widget.schoolId!,
          sessionId: widget.sessionId!,
          studentId: studentId,
        );
      }
    } catch (e) {
      debugPrint('Error marking student started in firestore: $e');
    }

    if (_secondsRemaining <= 0) {
      _autoSubmit();
    } else {
      _startTimer();
    }
    _saveDraftAnswers();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _autoSubmit();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String hoursStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');

    return '$hoursStr$minutesStr:$secondsStr';
  }

  Future<void> _autoSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    _timer?.cancel();

    final user = SessionService.currentUser!;
    final schoolId = widget.schoolId ?? user.schoolId;
    final studentId = widget.studentDocId ?? user.uid;
    try {
      await _examService.submitExam(
        schoolId: schoolId,
        exam: widget.exam,
        studentId: studentId,
        studentName: user.nama,
        answers: _selectedAnswers,
        essayAnswers: _essayAnswers,
      );

      // Update submittedAt di participations (denah tempat duduk)
      if (widget.sessionId != null) {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('exam_sessions')
            .doc(widget.sessionId)
            .collection('participations')
            .doc(studentId)
            .set({'submittedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }

      await _clearDraftAnswers();

      Get.back();
      Get.snackbar(
        'Waktu Habis',
        'Waktu ujian telah berakhir. Jawaban Anda berhasil dikumpulkan secara otomatis.',
        backgroundColor: Colors.amber,
        colorText: Colors.black,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'Gagal menyerahkan ujian otomatis: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> _submitExamManual() async {
    int answeredCount = 0;
    for (final q in _questions) {
      if (q.type == 'essay') {
        if (_essayAnswers[q.id]?.trim().isNotEmpty == true) {
          answeredCount++;
        }
      } else {
        if (_selectedAnswers.containsKey(q.id)) {
          answeredCount++;
        }
      }
    }
    final unansweredCount = _questions.length - answeredCount;
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          title: Text('Kumpulkan Ujian', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          content: Text(
            unansweredCount > 0
                ? 'Anda masih memiliki $unansweredCount soal yang belum dijawab. Apakah Anda yakin ingin mengumpulkan ujian sekarang?'
                : 'Apakah Anda yakin ingin menyerahkan jawaban Anda sekarang?',
            style: TextStyle(color: titleColor.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Kumpulkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isSubmitting = true;
      });
      _timer?.cancel();

      final user = SessionService.currentUser!;
      final schoolId = user.schoolId;
      final studentId = widget.studentDocId ?? user.uid;
      try {
        await _examService.submitExam(
          schoolId: schoolId,
          exam: widget.exam,
          studentId: studentId,
          studentName: user.nama,
          answers: _selectedAnswers,
          essayAnswers: _essayAnswers,
        );

        // Update submittedAt di participations (denah tempat duduk)
        if (widget.sessionId != null) {
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('exam_sessions')
              .doc(widget.sessionId)
              .collection('participations')
              .doc(studentId)
              .set({'submittedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }

        await _clearDraftAnswers();

        Get.back();
        Get.snackbar(
          'Sukses',
          'Ujian berhasil diserahkan. Nilai Anda telah dihitung.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        Get.snackbar('Gagal', 'Gagal menyerahkan ujian: $e',
            backgroundColor: Colors.redAccent, colorText: Colors.white);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasStarted) return true;
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final contentColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8);

    final bool? exit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          title: Text('Keluar Ujian', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          content: Text(
            'Anda sedang berada di tengah ujian. Jika Anda keluar sekarang, jawaban Anda saat ini akan langsung diserahkan otomatis.',
            style: TextStyle(height: 1.4, color: contentColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Lanjutkan Ujian',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Keluar & Serahkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (exit == true) {
      await _autoSubmit();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    SessionService.isTakingExam = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pgNavScrollCtrl.dispose();
    _essayNavScrollCtrl.dispose();
    super.dispose();
  }

  Widget _buildNavItem(int idx, Color titleColor, Color cardBgColor, Color cardBorderColor) {
    final q = _questions[idx];
    final isAnswered = q.type == 'essay'
        ? (_essayAnswers[q.id]?.trim().isNotEmpty == true)
        : _selectedAnswers.containsKey(q.id);
    final isCurrent = idx == _currentQuestionIndex;

    return GestureDetector(
      onTap: () {
        setState(() => _currentQuestionIndex = idx);
        _scrollNavToIndex(idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF8B5CF6)
              : isAnswered
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : cardBgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF8B5CF6)
                : isAnswered
                    ? const Color(0xFF10B981)
                    : cardBorderColor,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            '${idx + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isCurrent
                  ? Colors.white
                  : isAnswered
                      ? const Color(0xFF10B981)
                      : titleColor,
            ),
          ),
        ),
      ),
    );
  }

  void _scrollNavToIndex(int index) {
    if (_questions.isEmpty || index < 0 || index >= _questions.length) return;
    
    final pgIndices = <int>[];
    final essayIndices = <int>[];
    for (int i = 0; i < _questions.length; i++) {
      if (_questions[i].type != 'essay') {
        pgIndices.add(i);
      } else {
        essayIndices.add(i);
      }
    }

    if (_questions[index].type != 'essay') {
      final pgIdx = pgIndices.indexOf(index);
      if (pgIdx != -1 && _pgNavScrollCtrl.hasClients) {
        final offset = (pgIdx * 42.0) - 80;
        _pgNavScrollCtrl.animateTo(
          offset.clamp(0.0, _pgNavScrollCtrl.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      final essayIdx = essayIndices.indexOf(index);
      if (essayIdx != -1 && _essayNavScrollCtrl.hasClients) {
        final offset = (essayIdx * 42.0) - 80;
        _essayNavScrollCtrl.animateTo(
          offset.clamp(0.0, _essayNavScrollCtrl.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasStarted,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
          final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
          final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

          if (!_hasStarted) {
            return _buildInstructionScreen(isDark, titleColor, subTextColor, cardBgColor, cardBorderColor);
          }

          if (_secondsRemaining <= 0 || _isSubmitting) {
            return Scaffold(
              body: AuthBackground(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                      const SizedBox(height: 24),
                      Text(
                        AppLocalization.isIndonesian ? 'Waktu Ujian Telah Selesai' : 'Exam Session Has Ended',
                        style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalization.isIndonesian
                            ? 'Mengumpulkan jawaban secara otomatis...'
                            : 'Auto-submitting your answers...',
                        style: TextStyle(color: subTextColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final totalQuestions = _questions.length;
          final currentQuestion = _questions[_currentQuestionIndex];
          final selectedOption = _selectedAnswers[currentQuestion.id];
          final progress = (_questions.isEmpty)
              ? 0.0
              : (_currentQuestionIndex + 1) / totalQuestions;

          final pgIndices = <int>[];
          final essayIndices = <int>[];
          for (int i = 0; i < totalQuestions; i++) {
            if (_questions[i].type != 'essay') {
              pgIndices.add(i);
            } else {
              essayIndices.add(i);
            }
          }

          return Scaffold(
            body: AuthBackground(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Timer & Question Index
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Soal ${_currentQuestionIndex + 1} dari $totalQuestions',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (currentQuestion.type == 'essay'
                                                ? const Color(0xFFEC4899)
                                                : const Color(0xFF8B5CF6))
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: (currentQuestion.type == 'essay'
                                                  ? const Color(0xFFEC4899)
                                                  : const Color(0xFF8B5CF6))
                                              .withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        currentQuestion.type == 'essay' ? 'ESSAY' : 'PILIHAN GANDA',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: currentQuestion.type == 'essay'
                                              ? const Color(0xFFEC4899)
                                              : const Color(0xFF8B5CF6),
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_secondsRemaining < 120 ? Colors.redAccent : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: _secondsRemaining < 120 ? Colors.redAccent : const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTime(_secondsRemaining),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _secondsRemaining < 120 ? Colors.redAccent : const Color(0xFF8B5CF6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
 
                      // Linear Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: cardBorderColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 12),

                       // Question Number Navigation Grid
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           if (pgIndices.isNotEmpty) ...[
                             Row(
                               children: [
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                     borderRadius: BorderRadius.circular(6),
                                   ),
                                   child: Text(
                                     'PILIHAN GANDA',
                                     style: TextStyle(
                                       fontSize: 9,
                                       fontWeight: FontWeight.bold,
                                       color: const Color(0xFF8B5CF6),
                                       letterSpacing: 0.5,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 6),
                             SizedBox(
                               height: 38,
                               child: ListView.builder(
                                 controller: _pgNavScrollCtrl,
                                 scrollDirection: Axis.horizontal,
                                 itemCount: pgIndices.length,
                                 itemBuilder: (ctx, subIdx) {
                                   final idx = pgIndices[subIdx];
                                   return _buildNavItem(idx, titleColor, cardBgColor, cardBorderColor);
                                 },
                               ),
                             ),
                           ],
                           if (pgIndices.isNotEmpty && essayIndices.isNotEmpty) const SizedBox(height: 12),
                           if (essayIndices.isNotEmpty) ...[
                             Row(
                               children: [
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                                     borderRadius: BorderRadius.circular(6),
                                   ),
                                   child: Text(
                                     'ESSAY',
                                     style: TextStyle(
                                       fontSize: 9,
                                       fontWeight: FontWeight.bold,
                                       color: const Color(0xFFEC4899),
                                       letterSpacing: 0.5,
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 6),
                             SizedBox(
                               height: 38,
                               child: ListView.builder(
                                 controller: _essayNavScrollCtrl,
                                 scrollDirection: Axis.horizontal,
                                 itemCount: essayIndices.length,
                                 itemBuilder: (ctx, subIdx) {
                                   final idx = essayIndices[subIdx];
                                   return _buildNavItem(idx, titleColor, cardBgColor, cardBorderColor);
                                 },
                               ),
                             ),
                           ],
                         ],
                       ),
                       const SizedBox(height: 20),
 
                      // Question Body
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorderColor),
                                ),
                                child: Text(
                                  currentQuestion.questionText,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, height: 1.5),
                                ),
                              ),
                              const SizedBox(height: 24),
 
                              if (currentQuestion.type == 'essay') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: cardBgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: cardBorderColor),
                                  ),
                                  child: TextFormField(
                                    key: ValueKey(currentQuestion.id),
                                    initialValue: _essayAnswers[currentQuestion.id] ?? '',
                                    maxLines: 8,
                                    style: TextStyle(color: titleColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Tulis jawaban essay Anda di sini...',
                                      hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (val) {
                                      _essayAnswers[currentQuestion.id] = val;
                                      _saveDraftAnswers();
                                    },
                                  ),
                                ),
                              ] else ...[
                                // Option Cards
                                ...List.generate(currentQuestion.options.length, (optIdx) {
                                  final isSelected = selectedOption == optIdx;
                                  final optionChar = String.fromCharCode(65 + optIdx); // A, B, C, D
 
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          setState(() {
                                            _selectedAnswers[currentQuestion.id] = optIdx;
                                          });
                                          _saveDraftAnswers();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                                : cardBgColor,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF8B5CF6) : cardBorderColor,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isSelected ? const Color(0xFF8B5CF6) : cardBorderColor,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    optionChar,
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.white : titleColor,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Text(
                                                  currentQuestion.options[optIdx],
                                                  style: TextStyle(
                                                    color: titleColor,
                                                    fontSize: 14,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Navigation Control Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentQuestionIndex > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  final newIdx = _currentQuestionIndex - 1;
                                  setState(() => _currentQuestionIndex = newIdx);
                                  _scrollNavToIndex(newIdx);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cardBorderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text('Sebelumnya', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_currentQuestionIndex < totalQuestions - 1) {
                                  final newIdx = _currentQuestionIndex + 1;
                                  setState(() => _currentQuestionIndex = newIdx);
                                  _scrollNavToIndex(newIdx);
                                } else {
                                  _submitExamManual();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                _currentQuestionIndex < totalQuestions - 1 ? 'Berikutnya' : 'Kumpulkan',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionScreen(
      bool isDark, Color titleColor, Color subTextColor, Color cardBgColor, Color cardBorderColor) {
    final totalQuestions = _questions.length;
    final pgCount = _questions.where((q) => q.type == 'multiple_choice' || q.type == '').length;
    final essayCount = _questions.where((q) => q.type == 'essay').length;

    String questionComposition = '';
    if (pgCount > 0 && essayCount > 0) {
      questionComposition = 'Terdiri dari $totalQuestions soal ($pgCount Pilihan Ganda & $essayCount Essay).';
    } else if (essayCount > 0) {
      questionComposition = 'Terdiri dari $essayCount soal Essay.';
    } else {
      questionComposition = 'Terdiri dari $pgCount soal Pilihan Ganda.';
    }

    // ── Validasi waktu (layer kedua — mencegah akses langsung) ──────────────
    // Waktu SELALU dicek. examStatus tidak bisa bypass gate waktu.
    bool isExamTimeReachedHere = true; // default allow jika tidak ada info waktu
    if (widget.sessionStartTime != null) {
      try {
        final parts = widget.sessionStartTime!.split(':');
        final now = DateTime.now();
        final sessionStart = DateTime(
            now.year, now.month, now.day,
            int.parse(parts[0]), int.parse(parts[1]));
        isExamTimeReachedHere = !now.isBefore(sessionStart);
      } catch (_) {
        isExamTimeReachedHere = true; // jika parse gagal, izinkan (data tidak reliable)
      }
    }


    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.quiz_rounded, color: Color(0xFF8B5CF6), size: 48),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.examType != null && widget.examType!.isNotEmpty
                          ? '${widget.examType} - ${widget.exam.subjectName}'
                          : widget.exam.subjectName,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text('Aturan & Instruksi Ujian:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                    const SizedBox(height: 10),
                    _buildRuleItem(Icons.timer_rounded, 'Durasi pengerjaan adalah ${widget.exam.durationMinutes} menit.', titleColor),
                    _buildRuleItem(Icons.list_alt_rounded, questionComposition, titleColor),
                    _buildRuleItem(Icons.warning_amber_rounded, 'Meninggalkan aplikasi saat ujian berjalan akan memicu penyerahan jawaban otomatis.', titleColor),
                    _buildRuleItem(Icons.verified_user_rounded, 'Pastikan koneksi internet stabil sebelum menekan tombol Mulai.', titleColor),
                    const SizedBox(height: 24),
                    // ── Tombol mulai dengan validasi waktu ──
                    if (!isExamTimeReachedHere) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time_rounded, color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Ujian dimulai pukul ${widget.sessionStartTime}',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                    ElevatedButton(
                      onPressed: _startExam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Mulai Ujian Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cardBorderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Kembali', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, String text, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: titleColor.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: titleColor.withValues(alpha: 0.8), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
