import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
import '../services/exam_scheduler_service.dart';
import 'admin_exam_schedule_view_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ─────────────────────────────────────────────────────────────
//  AdminExamGeneratorPage — Form multi-step konfigurasi UTS/UAS
//  Step 1: Info dasar (nama, tipe, rentang tanggal)
//  Step 2: Konfigurasi slot waktu harian
//  Step 3: Pilih mapel + kelas + author soal
//  Step 4: Preview & Generate jadwal
// ─────────────────────────────────────────────────────────────
class AdminExamGeneratorPage extends StatefulWidget {
  final bool restoreFromFirestore;
  /// Jika diisi, halaman masuk ke mode EDIT (pre-populate semua data dari event ini)
  final ExamEvent? editEvent;
  const AdminExamGeneratorPage({
    super.key,
    this.restoreFromFirestore = false,
    this.editEvent,
  });

  @override
  State<AdminExamGeneratorPage> createState() => _AdminExamGeneratorPageState();
}

class _AdminExamGeneratorPageState extends State<AdminExamGeneratorPage> {
  final _sessionService = ExamSessionService();
  final _pageController = PageController();

  int _currentStep = 0;

  // ── Step 1 State ────────────────────────────────────────────
  final _titleController = TextEditingController();
  String _examType = 'UTS';
  DateTime? _startDate;
  DateTime? _endDate;

  // ── Step 2 State ────────────────────────────────────────────
  final List<ExamSlot> _slots = [
    const ExamSlot(name: 'Sesi 1', startTime: '07:30', endTime: '09:30'),
  ];

  // ── Step 3 State ────────────────────────────────────────────
  List<Map<String, dynamic>> _allSubjects = [];
  List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _allTeachers = [];
  final List<ExamSubjectConfig> _subjectConfigs = [];
  bool _isLoadingData = true;
  final Map<String, List<Map<String, dynamic>>> _studentsByClass = {};

  // ── Step 4 State (Ruangan) ──────────────────────────────────
  final List<ExamRoom> _rooms = [
    const ExamRoom(name: 'Ruang 01', capacity: 40),
    const ExamRoom(name: 'Ruang 02', capacity: 40),
  ];
  final _roomNameController = TextEditingController();
  final _roomCapacityController = TextEditingController(text: '40');

  // ── Step 5 State (Preview) ──────────────────────────────────
  bool _isGenerating = false;
  Set<String>? _expandedRooms;
  final Map<String, String> _scheduledSubjects = {};
  bool _isLoadingDraftFromFirestore = false;
  String? _editingEventId;
  bool _isZigzag = true;
  bool _isRandom = false;
  int _maxAngkatanPerRoom = 2;
  int _maxKelasPerRoom = 2;

  // ── Hari aktif KBM (dari class_schedules) ───────────────────
  Set<String> _activeStudyDays = {}; // e.g. {'senin','selasa','rabu','kamis','jumat'}

  void _onTitleChanged() {
    _saveDraft();
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('exam_draft_step', _currentStep);
      await prefs.setString('exam_draft_title', _titleController.text);
      await prefs.setString('exam_draft_type', _examType);
      await prefs.setString('exam_draft_start_date', _startDate?.toIso8601String() ?? '');
      await prefs.setString('exam_draft_end_date', _endDate?.toIso8601String() ?? '');
      
      final slotsJson = jsonEncode(_slots.map((s) => s.toMap()).toList());
      await prefs.setString('exam_draft_slots', slotsJson);
      
      final configsJson = jsonEncode(_subjectConfigs.map((c) => c.toMap()).toList());
      await prefs.setString('exam_draft_subject_configs', configsJson);
      
      final roomsJson = jsonEncode(_rooms.map((r) => r.toMap()).toList());
      await prefs.setString('exam_draft_rooms', roomsJson);

      final scheduleJson = jsonEncode(_scheduledSubjects);
      await prefs.setString('exam_draft_schedule', scheduleJson);
      await prefs.setString('exam_draft_event_id', _editingEventId ?? '');
      
      await prefs.setBool('exam_draft_exists', true);

      // Firestore sync
      final schoolId = SessionService.currentUser?.schoolId;
      if (schoolId != null) {
        final db = FirebaseFirestore.instance;
        await db.collection('schools').doc(schoolId).collection('exam_drafts').doc('current').set({
          'eventId': _editingEventId,
          'step': _currentStep,
          'title': _titleController.text,
          'examType': _examType,
          'startDate': _startDate != null ? Timestamp.fromDate(_startDate!) : null,
          'endDate': _endDate != null ? Timestamp.fromDate(_endDate!) : null,
          'slots': _slots.map((s) => s.toMap()).toList(),
          'subjectConfigs': _subjectConfigs.map((c) => c.toMap()).toList(),
          'rooms': _rooms.map((r) => r.toMap()).toList(),
          'scheduledSubjects': _scheduledSubjects,
          'draftSessions': _draftSessions.map((s) => {
            'date': s['date'] != null ? Timestamp.fromDate(s['date'] as DateTime) : null,
            'slotName': s['slotName'],
            'startTime': s['startTime'],
            'endTime': s['endTime'],
            'roomName': s['roomName'],
            'subjectId': s['subjectId'],
            'subjectName': s['subjectName'],
            'classes': s['classes'],
            'proctorId': s['proctorId'],
            'proctorName': s['proctorName'],
          }).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': SessionService.currentUser?.nama ?? '',
        });
      }
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('exam_draft_step');
      await prefs.remove('exam_draft_title');
      await prefs.remove('exam_draft_type');
      await prefs.remove('exam_draft_start_date');
      await prefs.remove('exam_draft_end_date');
      await prefs.remove('exam_draft_slots');
      await prefs.remove('exam_draft_subject_configs');
      await prefs.remove('exam_draft_rooms');
      await prefs.remove('exam_draft_schedule');
      await prefs.remove('exam_draft_event_id');
      await prefs.remove('exam_draft_exists');

      // Clear from Firestore
      final schoolId = SessionService.currentUser?.schoolId;
      if (schoolId != null) {
        final db = FirebaseFirestore.instance;
        await db.collection('schools').doc(schoolId).collection('exam_drafts').doc('current').delete();
      }
    } catch (_) {}
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final step = prefs.getInt('exam_draft_step') ?? 0;
      final title = prefs.getString('exam_draft_title') ?? '';
      final type = prefs.getString('exam_draft_type') ?? 'UTS';
      final startDateStr = prefs.getString('exam_draft_start_date') ?? '';
      final endDateStr = prefs.getString('exam_draft_end_date') ?? '';
      final slotsJson = prefs.getString('exam_draft_slots') ?? '';
      final configsJson = prefs.getString('exam_draft_subject_configs') ?? '';
      final roomsJson = prefs.getString('exam_draft_rooms') ?? '';
      final eventId = prefs.getString('exam_draft_event_id') ?? '';

      setState(() {
        _editingEventId = eventId.isEmpty ? null : eventId;
        _currentStep = step;
        _titleController.text = title;
        _examType = type;
        if (startDateStr.isNotEmpty) {
          _startDate = DateTime.tryParse(startDateStr);
        }
        if (endDateStr.isNotEmpty) {
          _endDate = DateTime.tryParse(endDateStr);
        }

        if (slotsJson.isNotEmpty) {
          try {
            final List decoded = jsonDecode(slotsJson);
            _slots.clear();
            _slots.addAll(decoded.map((s) => ExamSlot.fromMap(Map<String, dynamic>.from(s))));
          } catch (_) {}
        }

        if (configsJson.isNotEmpty) {
          try {
            final List decoded = jsonDecode(configsJson);
            _subjectConfigs.clear();
            _subjectConfigs.addAll(decoded.map((c) => ExamSubjectConfig.fromMap(Map<String, dynamic>.from(c))));
          } catch (_) {}
        }

        if (roomsJson.isNotEmpty) {
          try {
            final List decoded = jsonDecode(roomsJson);
            _rooms.clear();
            _rooms.addAll(decoded.map((r) => ExamRoom.fromMap(Map<String, dynamic>.from(r))));
          } catch (_) {}
        }

        final scheduleJson = prefs.getString('exam_draft_schedule') ?? '';
        if (scheduleJson.isNotEmpty) {
          try {
            final Map decoded = jsonDecode(scheduleJson);
            _scheduledSubjects.clear();
            decoded.forEach((k, v) {
              _scheduledSubjects[k.toString()] = v.toString();
            });
          } catch (_) {}
        }
      });

      // Robust page jump — retry until PageController is attached
      void jumpToStep() {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(step);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => jumpToStep());
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => jumpToStep());
    } catch (_) {}
  }

  Future<void> _checkAndLoadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final hasDraft = prefs.getBool('exam_draft_exists') ?? false;
    if (hasDraft && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final dialogBg = isDark ? const Color(0xFF1A1730) : Colors.white;
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(AppLocalization.isIndonesian ? 'Draf Ditemukan' : 'Draft Found', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
              content: Text(
                AppLocalization.isIndonesian
                    ? 'Ada draf pembuatan ujian yang belum selesai. Apakah Anda ingin melanjutkan draf tersebut?'
                    : 'There is an unfinished exam creation draft. Do you want to continue from where you left off?',
                style: TextStyle(color: titleColor.withValues(alpha: 0.7)),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _clearDraft();
                  },
                  child: Text(AppLocalization.isIndonesian ? 'Mulai Baru' : 'Start Fresh', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _restoreDraft();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(AppLocalization.isIndonesian ? 'Lanjutkan' : 'Continue'),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  Future<void> _restoreDraftFromFirestore() async {
    final schoolId = SessionService.currentUser?.schoolId;
    if (schoolId == null) return;
    setState(() => _isLoadingDraftFromFirestore = true);

    try {
      final db = FirebaseFirestore.instance;
      final doc = await db.collection('schools').doc(schoolId).collection('exam_drafts').doc('current').get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _editingEventId = data['eventId'] as String?;
          _currentStep = data['step'] ?? 0;
          _titleController.text = data['title'] ?? '';
          _examType = data['examType'] ?? 'UTS';
          if (data['startDate'] != null) {
            _startDate = (data['startDate'] as Timestamp).toDate();
          }
          if (data['endDate'] != null) {
            _endDate = (data['endDate'] as Timestamp).toDate();
          }
          if (data['slots'] != null) {
            _slots.clear();
            _slots.addAll((data['slots'] as List).map((s) => ExamSlot.fromMap(Map<String, dynamic>.from(s))));
          }
          if (data['subjectConfigs'] != null) {
            _subjectConfigs.clear();
            _subjectConfigs.addAll((data['subjectConfigs'] as List).map((c) => ExamSubjectConfig.fromMap(Map<String, dynamic>.from(c))));
          }
          if (data['rooms'] != null) {
            _rooms.clear();
            _rooms.addAll((data['rooms'] as List).map((r) => ExamRoom.fromMap(Map<String, dynamic>.from(r))));
          }
          if (data['scheduledSubjects'] != null) {
            _scheduledSubjects.clear();
            (data['scheduledSubjects'] as Map).forEach((k, v) {
              _scheduledSubjects[k.toString()] = v.toString();
            });
          }
          if (data['draftSessions'] != null) {
            _draftSessions = (data['draftSessions'] as List).map((raw) {
              final s = Map<String, dynamic>.from(raw as Map);
              return {
                'date': s['date'] != null ? (s['date'] as Timestamp).toDate() : DateTime.now(),
                'slotName': s['slotName'] ?? '',
                'startTime': s['startTime'] ?? '',
                'endTime': s['endTime'] ?? '',
                'roomName': s['roomName'] ?? '',
                'subjectId': s['subjectId'] ?? '',
                'subjectName': s['subjectName'] ?? '',
                'classes': (s['classes'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
                'proctorId': s['proctorId'] ?? '',
                'proctorName': s['proctorName'] ?? 'Belum ditugaskan',
              };
            }).toList();
          }
        });

        // Auto compile draft sessions if restored at step 5 or 6 and sessions are missing
        if (_currentStep >= 5 && _draftSessions.isEmpty && _scheduledSubjects.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _compileDraftSessions());
        }

        // Robust page jump
        void jumpToStep() {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(_currentStep);
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) => jumpToStep());
          }
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => jumpToStep());
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _isLoadingDraftFromFirestore = false);
      }
    }
  }

  /// Load semua field dari ExamEvent yang sudah ada (mode Edit)
  void _loadFromEvent(ExamEvent ev) {
    _editingEventId = ev.id;
    _titleController.text = ev.title;
    _examType = ev.examType;
    _startDate = ev.startDate;
    _endDate = ev.endDate;

    if (ev.dailySlots.isNotEmpty) {
      _slots.clear();
      _slots.addAll(ev.dailySlots);
    }

    if (ev.subjectConfigs.isNotEmpty) {
      _subjectConfigs.clear();
      _subjectConfigs.addAll(ev.subjectConfigs);
    }

    if (ev.rooms.isNotEmpty) {
      _rooms.clear();
      _rooms.addAll(ev.rooms);
    }

    // Try restore scheduled subjects and sessions from Firestore
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreEditDraftSessions(ev.id);
    });
  }

  /// Restore scheduledSubjects + draftSessions dari Firestore exam_sessions
  Future<void> _restoreEditDraftSessions(String eventId) async {
    final schoolId = SessionService.currentUser?.schoolId;
    if (schoolId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('exam_sessions')
          .where('eventId', isEqualTo: eventId)
          .get();

      if (!mounted) return;

      // Parse sessions — normalise date to midnight (dateOnly) for consistent comparison
      final List<Map<String, dynamic>> sessions = snap.docs.map((doc) {
        final d = doc.data();
        final rawDate = (d['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        // Strip time component — _compileDraftSessions and _buildStep5Schedule both
        // use DateTime(y,m,d) without time, so comparison needs to match exactly.
        final dateOnly = DateTime(rawDate.year, rawDate.month, rawDate.day);

        // className is the display string e.g. "X IPA 1, X IPS 1"
        final className = d['className'] as String? ?? '';
        // classNames is the list of individual class names used as schedule keys
        final classNames = className.split(', ').where((s) => s.isNotEmpty).toList();

        return {
          'date':        dateOnly,
          'slotName':    d['slotName'] ?? '',
          'startTime':   d['startTime'] ?? '',
          'endTime':     d['endTime'] ?? '',
          'roomName':    d['roomName'] ?? '',
          'subjectId':   d['subjectId'] ?? '',
          'subjectName': d['subjectName'] ?? '',
          'className':   className,
          // 'classes' is the per-class list, same as what _compileDraftSessions produces
          'classes':     classNames,
          'proctorId':   d['proctorId'] ?? '',
          'proctorName': d['proctorName'] ?? 'Belum ditugaskan',
          // Empty students list — re-populated if user navigates through Step 5
          'students':    <Map<String, dynamic>>[],
        };
      }).toList();

      // Rebuild _scheduledSubjects map from sessions.
      // Key format: "yyyy-MM-dd_SlotName_RoomName_ClassName" (per individual class name)
      final Map<String, String> scheduled = {};
      for (final s in sessions) {
        final date   = s['date'] as DateTime;
        final dayStr = DateFormat('yyyy-MM-dd').format(date);
        for (final cls in (s['classes'] as List<dynamic>).cast<String>()) {
          final key = '${dayStr}_${s['slotName']}_${s['roomName']}_$cls';
          scheduled[key] = s['subjectId'] as String;
        }
      }

      setState(() {
        _draftSessions = sessions;
        _scheduledSubjects
          ..clear()
          ..addAll(scheduled);
      });
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadSchoolData();
    _titleController.addListener(_onTitleChanged);
    if (widget.editEvent != null) {
      // Edit mode: pre-populate dari event yang ada, skip draft
      _loadFromEvent(widget.editEvent!);
    } else if (widget.restoreFromFirestore) {
      _restoreDraftFromFirestore();
    } else {
      _checkAndLoadDraft();
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _pageController.dispose();
    _roomNameController.dispose();
    _roomCapacityController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolData() async {
    final schoolId = SessionService.currentUser!.schoolId;
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('schools').doc(schoolId).collection('subjects').get(),
      db.collection('schools').doc(schoolId).collection('classes').get(),
      db
          .collection('schools')
          .doc(schoolId)
          .collection('teachers')
          .where('aktif', isEqualTo: true)
          .get(),
      db.collection('schools').doc(schoolId).collection('students').get(),
    ]);

    // Load hari aktif KBM
    final activeDays = await ExamSchedulerService().getActiveStudyDays(schoolId);

    if (mounted) {
      setState(() {
        _allSubjects = (results[0] as QuerySnapshot<Map<String, dynamic>>)
            .docs
            .map((d) => {'id': d.id, 'name': d.data()['namaMapel'] ?? d.data()['nama'] ?? d.data()['name'] ?? ''})
            .toList();
        _allSubjects.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

        _allClasses = (results[1] as QuerySnapshot<Map<String, dynamic>>)
            .docs
            .map((d) => {'id': d.id, 'name': d.data()['namaKelas'] ?? d.data()['nama'] ?? d.data()['name'] ?? ''})
            .toList();
        _allClasses.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

        _allTeachers = (results[2] as QuerySnapshot<Map<String, dynamic>>)
            .docs
            .map((d) => {'id': d.id, 'nama': d.data()['nama'] ?? ''})
            .toList();
        _allTeachers.sort((a, b) => (a['nama'] as String).toLowerCase().compareTo((b['nama'] as String).toLowerCase()));

        final studentsDocs = (results[3] as QuerySnapshot<Map<String, dynamic>>).docs;
        _studentsByClass.clear();
        for (final doc in studentsDocs) {
          final data = doc.data();
          final cid = data['classId'] as String? ?? '';
          final isLulus = data['lulus'] == true;
          final isAktif = data['aktif'] ?? true;
          if (cid.isNotEmpty && !isLulus && isAktif) {
            _studentsByClass.putIfAbsent(cid, () => []).add({
              'id': doc.id,
              'nama': data['nama'] ?? '',
              'nis': data['nis'] ?? '',
              'angkatan': (data['angkatan'] ?? '').toString().trim(),
            });
          }
        }

        _isLoadingData = false;
        if (activeDays.isNotEmpty) {
          _activeStudyDays = activeDays;
        }
      });
    }
  }

  Future<void> _pullFromDailySchedules() async {
    final schoolId = SessionService.currentUser?.schoolId;
    if (schoolId == null) return;

    setState(() => _isLoadingData = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('class_schedules')
          .where('aktif', isEqualTo: true)
          .where('jenisJadwal', isEqualTo: 'pelajaran')
          .get();

      if (snap.docs.isEmpty) {
        Get.snackbar(
          AppLocalization.isIndonesian ? 'Peringatan' : 'Warning',
          AppLocalization.isIndonesian
              ? 'Tidak ditemukan jadwal harian aktif untuk ditarik.'
              : 'No active daily schedule found to pull from.',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
        );
        setState(() => _isLoadingData = false);
        return;
      }

      // Group schedules by subjectId
      final Map<String, Map<String, dynamic>> grouped = {};

      for (final doc in snap.docs) {
        final data = doc.data();
        final subjectId = data['subjectId'] as String? ?? '';
        final subjectName = data['subjectName'] as String? ?? '';
        final classId = data['classId'] as String? ?? '';
        final teacherId = data['teacherId'] as String? ?? '';
        final teacherName = data['teacherName'] as String? ?? '';

        if (subjectId.isEmpty || subjectName.isEmpty) continue;

        grouped.putIfAbsent(subjectId, () => {
          'subjectId': subjectId,
          'subjectName': subjectName,
          'classIds': <String>{},
          'teacherIds': <String>{},
          'teacherNames': <String>{},
        });

        if (classId.isNotEmpty) {
          (grouped[subjectId]!['classIds'] as Set<String>).add(classId);
        }
        if (teacherId.isNotEmpty && teacherId != '-') {
          (grouped[subjectId]!['teacherIds'] as Set<String>).add(teacherId);
          if (teacherName.isNotEmpty && teacherName != '-') {
            (grouped[subjectId]!['teacherNames'] as Set<String>).add(teacherName);
          }
        }
      }

      final List<ExamSubjectConfig> configs = [];
      grouped.forEach((subId, val) {
        configs.add(ExamSubjectConfig(
          subjectId: subId,
          subjectName: val['subjectName'] as String,
          classIds: (val['classIds'] as Set<String>).toList(),
          authorTeacherIds: (val['teacherIds'] as Set<String>).toList(),
          authorTeacherNames: (val['teacherNames'] as Set<String>).toList(),
        ));
      });

      setState(() {
        _subjectConfigs.clear();
        _subjectConfigs.addAll(configs);
        _isLoadingData = false;
      });

      _saveDraft();

      Get.snackbar(
        AppLocalization.isIndonesian ? 'Sukses' : 'Success',
        AppLocalization.isIndonesian
            ? 'Berhasil menarik ${_subjectConfigs.length} mata pelajaran dari jadwal harian.'
            : 'Successfully pulled ${_subjectConfigs.length} subjects from daily schedule.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    } catch (e) {
      setState(() => _isLoadingData = false);
      _showError(AppLocalization.isIndonesian
          ? 'Gagal menarik jadwal harian: $e'
          : 'Failed to pull daily schedules: $e');
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 7) {
      if (_currentStep == 5) {
        _compileDraftSessions();
      }
      setState(() => _currentStep++);
      _saveDraft();
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _saveDraft();
      _pageController.previousPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_titleController.text.trim().isEmpty) {
          _showError(AppLocalization.isIndonesian
              ? 'Nama event ujian tidak boleh kosong'
              : 'Exam event name cannot be empty');
          return false;
        }
        if (_startDate == null || _endDate == null) {
          _showError(AppLocalization.isIndonesian
              ? 'Pilih rentang tanggal ujian'
              : 'Select exam date range');
          return false;
        }
        if (_endDate!.isBefore(_startDate!)) {
          _showError(AppLocalization.isIndonesian
              ? 'Tanggal akhir harus setelah tanggal mulai'
              : 'End date must be after start date');
          return false;
        }
        return true;
      case 1:
        if (_slots.isEmpty) {
          _showError(AppLocalization.isIndonesian
              ? 'Tambahkan minimal satu slot waktu'
              : 'Add at least one time slot');
          return false;
        }
        return true;
      case 2:
        if (_subjectConfigs.isEmpty) {
          _showError(AppLocalization.isIndonesian
              ? 'Tambahkan minimal satu mata pelajaran'
              : 'Add at least one subject');
          return false;
        }
        for (final config in _subjectConfigs) {
          if (config.authorTeacherIds.isEmpty) {
            _showError(AppLocalization.isIndonesian
                ? 'Pilih pembuat soal untuk "${config.subjectName}"'
                : 'Select question author for "${config.subjectName}"');
            return false;
          }
          if (config.classIds.isEmpty) {
            _showError(AppLocalization.isIndonesian
                ? 'Pilih kelas untuk "${config.subjectName}"'
                : 'Select class for "${config.subjectName}"');
            return false;
          }
        }
        return true;
      case 3:
        if (_rooms.isEmpty) {
          _showError(AppLocalization.isIndonesian
              ? 'Tambahkan minimal satu ruangan ujian'
              : 'Add at least one exam room');
          return false;
        }
        for (final room in _rooms) {
          if (room.name.trim().isEmpty) {
            _showError(AppLocalization.isIndonesian
                ? 'Nama ruangan tidak boleh kosong'
                : 'Room name cannot be empty');
            return false;
          }
          if (room.capacity <= 0) {
            _showError(AppLocalization.isIndonesian
                ? 'Kapasitas ruangan "${room.name}" harus lebih dari 0'
                : 'Room capacity for "${room.name}" must be greater than 0');
            return false;
          }
        }
        return true;
      case 4:
        // Step 5 (Room Seating / Pembagian Kursi)
        // No hard validation requirements, but warning is shown dynamically.
        return true;
      case 5:
        // Step 6 (Exam Schedule / Jadwal Ujian)
        final scheduledSubjectIds = _scheduledSubjects.values.toSet();
        final unscheduledSubjects = _subjectConfigs.where((s) => !scheduledSubjectIds.contains(s.subjectId)).toList();
        if (unscheduledSubjects.isNotEmpty) {
          _showError(AppLocalization.isIndonesian
              ? 'Terdapat ${unscheduledSubjects.length} mata pelajaran yang belum dijadwalkan: '
                  '${unscheduledSubjects.map((s) => s.subjectName).join(', ')}'
              : 'There are ${unscheduledSubjects.length} unscheduled subjects: '
                  '${unscheduledSubjects.map((s) => s.subjectName).join(', ')}');
          return false;
        }
        return true;
      case 6:
        // Step 7 (Proctors / Pengawas)
        final unassignedCount = _draftSessions.where((s) => (s['proctorId'] as String).isEmpty).length;
        if (unassignedCount > 0) {
          _showError(AppLocalization.isIndonesian
              ? 'Terdapat $unassignedCount sesi ujian yang belum memiliki pengawas.'
              : 'There are $unassignedCount exam sessions that do not have a proctor.');
          return false;
        }
        for (final s in _draftSessions) {
          if (hasConflict(s)) {
            _showError(AppLocalization.isIndonesian
                ? 'Terdapat bentrokan sesi pengawas (satu guru mengawas beberapa kelas di sesi yang sama).'
                : 'There is a proctor conflict (one teacher proctored multiple classes in the same session).');
            return false;
          }
          if (exceedsDailyLimit(s)) {
            _showError(AppLocalization.isIndonesian
                ? 'Terdapat guru yang ditugaskan mengawas melebihi batas 2 sesi dalam sehari.'
                : 'There is a teacher assigned to proctor exceeding the limit of 2 sessions in a day.');
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    Get.snackbar(AppLocalization.isIndonesian ? 'Perhatian' : 'Attention', msg,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final cardColor =
                isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white;
            final cardBorder = isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08);

            return Scaffold(
              body: AuthBackground(
                child: _isLoadingDraftFromFirestore
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8B5CF6),
                        ),
                      )
                    : Column(
                        children: [
                    // AppBar
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(8, 8, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_rounded,
                                  color: titleColor),
                              onPressed: () => Get.back(),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AppLocalization.isIndonesian
                                    ? (widget.editEvent != null ? 'Edit Jadwal Ujian' : 'Buat Jadwal Ujian Semester')
                                    : (widget.editEvent != null ? 'Edit Exam Schedule' : 'Create Semester Exam Schedule'),
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                // Step Indicator
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: _buildStepIndicator(isDark),
                ),

                // Page Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(isDark, cardColor, cardBorder, titleColor),
                      _buildStep2(isDark, cardColor, cardBorder, titleColor),
                      _buildStep3(isDark, cardColor, cardBorder, titleColor),
                      _buildStep4(isDark, cardColor, cardBorder, titleColor),
                      _buildStep5(isDark, cardColor, cardBorder, titleColor),
                      _buildStep5Schedule(isDark, cardColor, cardBorder, titleColor),
                      _buildStep6(isDark, cardColor, cardBorder, titleColor),
                      _buildStep7(isDark, cardColor, cardBorder, titleColor),
                    ],
                  ),
                ),

                // Bottom Navigation
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _prevStep,
                              icon: Icon(Icons.arrow_back_rounded,
                                  color: titleColor, size: 18),
                              label: Text(AppLocalization.isIndonesian ? 'Kembali' : 'Back',
                                  style: TextStyle(color: titleColor)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: cardBorder),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _currentStep < 7
                              ? ElevatedButton.icon(
                                  onPressed: _nextStep,
                                  icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18),
                                  label: Text(AppLocalization.isIndonesian ? 'Lanjut' : 'Next'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: _isGenerating
                                      ? null
                                      : ((widget.editEvent != null || _editingEventId != null)
                                          ? _saveAndUpdateEvent
                                          : _saveAndCreateEvent),
                                  icon: _isGenerating
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(
                                          Icons.save_rounded,
                                          size: 18),
                                  label: Text(_isGenerating
                                      ? (AppLocalization.isIndonesian ? 'Menyimpan...' : 'Saving...')
                                      : (widget.editEvent != null || _editingEventId != null)
                                          ? (AppLocalization.isIndonesian ? 'Simpan Perubahan' : 'Save Changes')
                                          : (AppLocalization.isIndonesian ? 'Simpan & Buat Jadwal' : 'Save & Generate')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
  }

  // ── Step Indicator ───────────────────────────────────────────
  Widget _buildStepIndicator(bool isDark) {
    final steps = AppLocalization.isIndonesian
        ? ['Info Dasar', 'Slot Waktu', 'Mata Pelajaran', 'Ruang Ujian', 'Pembagian Kursi', 'Jadwal Ujian', 'Pengawas', 'Jadwal Final']
        : ['Basic Info', 'Time Slots', 'Subjects', 'Exam Rooms', 'Room Seating', 'Exam Schedule', 'Proctors', 'Final Schedule'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        final lineColor = isDone
            ? const Color(0xFF8B5CF6)
            : isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1);

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? const Color(0xFF8B5CF6)
                            : isActive
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                        border: Border.all(
                          color: isActive || isDone
                              ? const Color(0xFF8B5CF6)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? const Color(0xFF8B5CF6)
                                      : isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                       steps[i],
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive
                            ? const Color(0xFF8B5CF6)
                            : isDark
                                ? Colors.white38
                                : Colors.black38,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Container(
                  height: 1.5,
                  width: 10,
                  color: lineColor,
                  margin: const EdgeInsets.only(bottom: 22),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step 1: Info Dasar ───────────────────────────────────────
  Widget _buildStep1(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalization.isIndonesian ? 'Informasi Dasar Event' : 'Basic Event Information',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(AppLocalization.isIndonesian ? 'Isi detail event ujian semester ini' : 'Fill in the details for this semester exam event',
              style: TextStyle(color: subtitleColor, fontSize: 13)),
          const SizedBox(height: 20),

          // Nama Event
          _buildLabel(AppLocalization.isIndonesian ? 'Nama Event Ujian' : 'Exam Event Name', isDark),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            style: TextStyle(color: titleColor),
            decoration: _inputDecoration(
              AppLocalization.isIndonesian ? 'Contoh: UAS Semester 1 2025/2026' : 'e.g., UAS Semester 1 2025/2026',
              isDark,
              inputBg,
              cardBorder,
            ),
          ),
          const SizedBox(height: 16),

          // Tipe Ujian
          _buildLabel(AppLocalization.isIndonesian ? 'Tipe Ujian' : 'Exam Type', isDark),
          const SizedBox(height: 8),
          Row(
            children: ['UTS', 'UAS'].map((type) {
              final isSelected = _examType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _examType = type);
                    _saveDraft();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: type == 'UTS' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                          : inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF8B5CF6)
                              : subtitleColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Rentang Tanggal
          _buildLabel(AppLocalization.isIndonesian ? 'Rentang Tanggal Ujian' : 'Exam Date Range', isDark),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePickerButton(
                  label: _startDate != null
                      ? DateFormat('dd MMM yyyy', AppLocalization.isIndonesian ? 'id' : 'en').format(_startDate!)
                      : (AppLocalization.isIndonesian ? 'Mulai' : 'Start'),
                  icon: Icons.calendar_today_rounded,
                  isDark: isDark,
                  inputBg: inputBg,
                  cardBorder: cardBorder,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _startDate = picked);
                      _saveDraft();
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    color: subtitleColor, size: 18),
              ),
              Expanded(
                child: _buildDatePickerButton(
                  label: _endDate != null
                      ? DateFormat('dd MMM yyyy', AppLocalization.isIndonesian ? 'id' : 'en').format(_endDate!)
                      : (AppLocalization.isIndonesian ? 'Selesai' : 'End'),
                  icon: Icons.event_rounded,
                  isDark: isDark,
                  inputBg: inputBg,
                  cardBorder: cardBorder,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
                      firstDate: _startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _endDate = picked);
                      _saveDraft();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Step 2: Slot Waktu ───────────────────────────────────────
  Widget _buildStep2(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalization.isIndonesian ? 'Slot Waktu Harian' : 'Daily Time Slots',
            style: TextStyle(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalization.isIndonesian
                ? 'Tentukan sesi-sesi ujian per hari'
                : 'Define exam sessions per day',
            style: TextStyle(color: subtitleColor, fontSize: 13),
          ),
          const SizedBox(height: 20),

          ..._slots.asMap().entries.map((entry) {
            final i = entry.key;
            final slot = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          slot.name.replaceAll('Sesi', AppLocalization.isIndonesian ? 'Sesi' : 'Session'),
                          style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      if (_slots.length > 1)
                        IconButton(
                          icon: const Icon(Icons.delete_rounded,
                              color: Color(0xFFEF4444), size: 18),
                          onPressed: () {
                            setState(() => _slots.removeAt(i));
                            _saveDraft();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerButton(
                          label: AppLocalization.isIndonesian
                              ? 'Mulai: ${slot.startTime}'
                              : 'Start: ${slot.startTime}',
                          icon: Icons.access_time_rounded,
                          isDark: isDark,
                          inputBg: inputBg,
                          cardBorder: cardBorder,
                          titleColor: titleColor,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.tryParse(
                                        slot.startTime.split(':')[0]) ??
                                    7,
                                minute: int.tryParse(
                                        slot.startTime.split(':')[1]) ??
                                    30,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _slots[i] = ExamSlot(
                                  name: slot.name,
                                  startTime:
                                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                                  endTime: slot.endTime,
                                );
                              });
                              _saveDraft();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimePickerButton(
                          label: AppLocalization.isIndonesian
                              ? 'Selesai: ${slot.endTime}'
                              : 'End: ${slot.endTime}',
                          icon: Icons.timer_off_rounded,
                          isDark: isDark,
                          inputBg: inputBg,
                          cardBorder: cardBorder,
                          titleColor: titleColor,
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: int.tryParse(
                                        slot.endTime.split(':')[0]) ??
                                    9,
                                minute: int.tryParse(
                                        slot.endTime.split(':')[1]) ??
                                    30,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _slots[i] = ExamSlot(
                                  name: slot.name,
                                  startTime: slot.startTime,
                                  endTime:
                                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                                  );
                              });
                              _saveDraft();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Tombol tambah slot
          TextButton.icon(
            onPressed: () {
              final nextNum = _slots.length + 1;
              setState(() {
                _slots.add(ExamSlot(
                  name: '${AppLocalization.isIndonesian ? 'Sesi' : 'Session'} $nextNum',
                  startTime: '10:00',
                  endTime: '12:00',
                ));
              });
              _saveDraft();
            },
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Color(0xFF8B5CF6)),
            label: Text(
              AppLocalization.isIndonesian ? 'Tambah Sesi' : 'Add Session',
              style: const TextStyle(color: Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Step 3: Mata Pelajaran ───────────────────────────────────
  Widget _buildStep3(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    if (_isLoadingData) {
      return Center(
          child: CircularProgressIndicator(
              color: isDark ? Colors.white : const Color(0xFF8B5CF6)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalization.isIndonesian ? 'Mata Pelajaran & Kelas' : 'Subjects & Classes',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(AppLocalization.isIndonesian ? 'Pilih mapel, kelas peserta, dan pembuat soal' : 'Select subjects, participant classes, and exam authors',
              style: TextStyle(color: subtitleColor, fontSize: 13)),
          const SizedBox(height: 20),

          ..._subjectConfigs.asMap().entries.map((entry) {
            final i = entry.key;
            final config = entry.value;
            return _buildSubjectConfigCard(
                i, config, isDark, cardColor, cardBorder, titleColor, subtitleColor);
          }),

          // Tombol tambah mapel & tarik jadwal
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddSubjectDialog(
                      isDark, cardColor, cardBorder, titleColor, subtitleColor),
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF8B5CF6)),
                  label: Text(AppLocalization.isIndonesian ? 'Tambah Mapel Manual' : 'Add Subject Manually',
                      style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pullFromDailySchedules,
                  icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 16),
                  label: Text(AppLocalization.isIndonesian ? 'Tarik Jadwal Harian' : 'Pull Daily Schedule',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSubjectConfigCard(
    int index,
    ExamSubjectConfig config,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    final authorNames = config.authorTeacherNames.isNotEmpty
        ? config.authorTeacherNames.join(', ')
        : (AppLocalization.isIndonesian ? 'Belum dipilih' : 'Not selected');
    final classNamesList = config.classIds
        .map((id) => _allClasses
            .firstWhere((c) => c['id'] == id,
                orElse: () => {'name': id})['name'] as String)
        .toList();
    classNamesList.sort((a, b) {
      final indexA = _allClasses.indexWhere((c) => c['name'] == a);
      final indexB = _allClasses.indexWhere((c) => c['name'] == b);
      return indexA.compareTo(indexB);
    });
    final classNames = classNamesList.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(config.subjectName,
                    style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded,
                    color: Color(0xFFEF4444), size: 18),
                onPressed: () {
                  setState(() => _subjectConfigs.removeAt(index));
                  _saveDraft();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.person_rounded,
              '${AppLocalization.isIndonesian ? 'Pembuat Soal' : 'Exam Author'}: $authorNames',
              subtitleColor),
          const SizedBox(height: 4),
          _buildInfoRow(
              Icons.class_rounded,
              config.classIds.isEmpty
                  ? '${AppLocalization.isIndonesian ? 'Kelas' : 'Class'}: ${AppLocalization.isIndonesian ? 'Belum dipilih' : 'Not selected'}'
                  : '${AppLocalization.isIndonesian ? 'Kelas' : 'Class'}: $classNames',
              subtitleColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(color: color, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  void _showAddSubjectDialog(
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    String? selectedSubjectId;
    String? selectedSubjectName;
    final List<String> selectedAuthorIds = [];
    final List<String> selectedAuthorNames = [];
    final List<String> selectedClassIds = [];
    List<Map<String, dynamic>> filteredTeachers = [];
    bool isLoadingTeachers = false;

    Future<void> fetchTeachersForSubject(String subjectId, void Function(void Function()) setModalState) async {
      setModalState(() {
        isLoadingTeachers = true;
        filteredTeachers = [];
        selectedAuthorIds.clear();
        selectedAuthorNames.clear();
      });
      final schoolId = SessionService.currentUser!.schoolId;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('teacher_subjects')
            .where('subjectId', isEqualTo: subjectId)
            .get();

        final teachersSnap = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('teachers')
            .where('aktif', isEqualTo: true)
            .get();

        final activeTeacherIds = teachersSnap.docs.map((d) => d.id).toSet();

        final List<Map<String, dynamic>> list = snap.docs.map((d) {
          final data = d.data();
          final tId = data['teacherId']?.toString() ?? '';
          final matchDoc = teachersSnap.docs.where((doc) => doc.id == tId);
          final currentName = matchDoc.isNotEmpty
              ? matchDoc.first.data()['nama']?.toString() ?? ''
              : (data['teacherName']?.toString() ?? '');

          return {
            'id': tId,
            'nama': currentName,
          };
        }).where((t) {
          final tId = t['id'] as String;
          final tName = t['nama'] as String;
          return tId.isNotEmpty && tName.isNotEmpty && activeTeacherIds.contains(tId);
        }).toList();

        setModalState(() {
          filteredTeachers = list;
          isLoadingTeachers = false;
        });

      } catch (_) {
        setModalState(() {
          isLoadingTeachers = false;
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1730) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalization.isIndonesian ? 'Tambah Mata Pelajaran' : 'Add Subject',
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Pilih Mapel
                  Text(
                    AppLocalization.isIndonesian ? 'Mata Pelajaran' : 'Subject',
                    style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedSubjectId,
                    dropdownColor:
                        isDark ? const Color(0xFF1A1730) : Colors.white,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cardBorder)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cardBorder)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    hint: Text(
                      AppLocalization.isIndonesian ? 'Pilih Mata Pelajaran' : 'Select Subject',
                      style: TextStyle(color: subtitleColor),
                    ),
                    items: _allSubjects.map((s) {
                      return DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['name'] as String,
                              style: TextStyle(color: titleColor)));
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        selectedSubjectId = val;
                        selectedSubjectName = _allSubjects
                            .firstWhere((s) => s['id'] == val)['name'] as String;
                      });
                      if (val != null) {
                        fetchTeachersForSubject(val, setModalState);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Pilih Author
                  Text(
                    AppLocalization.isIndonesian
                        ? 'Guru Penguji / Pembuat Soal (Bisa Pilih > 1)'
                        : 'Examiner / Question Author (Can select > 1)',
                    style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (selectedSubjectId == null)
                    Text(
                      AppLocalization.isIndonesian
                          ? 'Pilih mata pelajaran terlebih dahulu'
                          : 'Select subject first',
                      style: TextStyle(color: subtitleColor.withValues(alpha: 0.5), fontSize: 13),
                    )
                  else if (isLoadingTeachers)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    )
                  else () {
                    final displayTeachers = filteredTeachers.isNotEmpty ? filteredTeachers : _allTeachers;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: displayTeachers.map((t) {
                        final isSelected = selectedAuthorIds.contains(t['id']);
                        // Chip custom agar warna tidak di-override oleh Material 3 theme
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedAuthorIds.remove(t['id']);
                                selectedAuthorNames.remove(t['nama']);
                              } else {
                                selectedAuthorIds.add(t['id'] as String);
                                selectedAuthorNames.add(t['nama'] as String);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.18)
                                  : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF8B5CF6)
                                    : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...const [
                                  Icon(Icons.check_rounded, size: 14, color: Color(0xFF8B5CF6)),
                                  SizedBox(width: 4),
                                ],
                                Text(
                                  t['nama'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF8B5CF6)
                                        : (isDark ? Colors.white : const Color(0xFF1E1B4B)),
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }(),
                  const SizedBox(height: 16),

                  // Pilih Kelas
                  Text('Kelas Peserta (multi-pilih)',
                      style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pilih Semua Kelas',
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    value: selectedClassIds.length == _allClasses.length && _allClasses.isNotEmpty,
                    activeColor: const Color(0xFF8B5CF6),
                    checkColor: Colors.white,
                    onChanged: (val) {
                      setModalState(() {
                        if (val == true) {
                          selectedClassIds.clear();
                          selectedClassIds.addAll(
                              _allClasses.map((c) => c['id'] as String));
                        } else {
                          selectedClassIds.clear();
                        }
                      });
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _allClasses.length,
                      itemBuilder: (_, idx) {
                        final cls = _allClasses[idx];
                        final classId = cls['id'] as String;
                        final isChecked = selectedClassIds.contains(classId);
                        return CheckboxListTile(
                          dense: true,
                          value: isChecked,
                          title: Text(cls['name'] as String,
                              style: TextStyle(color: titleColor, fontSize: 14)),
                          activeColor: const Color(0xFF8B5CF6),
                          checkColor: Colors.white,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedClassIds.add(classId);
                              } else {
                                selectedClassIds.remove(classId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (selectedSubjectId == null) {
                        _showError(AppLocalization.isIndonesian ? 'Pilih mata pelajaran' : 'Select subject');
                        return;
                      }
                      if (selectedAuthorIds.isEmpty) {
                        _showError(AppLocalization.isIndonesian ? 'Pilih minimal satu guru pengoreksi' : 'Select at least one question author');
                        return;
                      }
                      if (selectedClassIds.isEmpty) {
                        _showError(AppLocalization.isIndonesian ? 'Pilih minimal satu kelas' : 'Select at least one class');
                        return;
                      }
                      setState(() {
                        _subjectConfigs.add(ExamSubjectConfig(
                          subjectId: selectedSubjectId!,
                          subjectName: selectedSubjectName!,
                          authorTeacherIds: List.from(selectedAuthorIds),
                          authorTeacherNames: List.from(selectedAuthorNames),
                          classIds: List.from(selectedClassIds),
                        ));
                      });
                      _saveDraft();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ── Step 4: Konfigurasi Ruang Ujian ──────────────────────────
  Widget _buildStep4(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.03);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalization.isIndonesian ? 'Konfigurasi Ruang Ujian' : 'Exam Room Configuration',
            style: TextStyle(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalization.isIndonesian
                ? 'Daftarkan ruangan yang akan digunakan beserta kapasitas kursinya'
                : 'Register exam rooms and their seating capacity',
            style: TextStyle(color: subtitleColor, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Form Tambah Ruangan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalization.isIndonesian ? 'Tambah Ruang Ujian' : 'Add Exam Room',
                  style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _roomNameController,
                        decoration: InputDecoration(
                          hintText: AppLocalization.isIndonesian
                              ? 'Nama Ruang (e.g. Ruang 03)'
                              : 'Room Name (e.g. Room 03)',
                          hintStyle: TextStyle(
                              color: titleColor.withValues(alpha: 0.4),
                              fontSize: 13),
                          fillColor: inputBg,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        style: TextStyle(color: titleColor, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _roomCapacityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: AppLocalization.isIndonesian ? 'Kapasitas' : 'Capacity',
                          hintStyle: TextStyle(
                              color: titleColor.withValues(alpha: 0.4),
                              fontSize: 13),
                          fillColor: inputBg,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        style: TextStyle(color: titleColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final name = _roomNameController.text.trim();
                    final capacityStr = _roomCapacityController.text.trim();
                    final capacity = int.tryParse(capacityStr) ?? 0;

                    if (name.isEmpty) {
                      _showError(AppLocalization.isIndonesian
                          ? 'Nama ruangan tidak boleh kosong'
                          : 'Room name cannot be empty');
                      return;
                    }
                    if (capacity <= 0) {
                      _showError(AppLocalization.isIndonesian
                          ? 'Kapasitas ruangan harus lebih dari 0'
                          : 'Room capacity must be greater than 0');
                      return;
                    }

                    setState(() {
                      _rooms.add(ExamRoom(name: name, capacity: capacity));
                      _roomNameController.clear();
                      _roomCapacityController.text = '40';
                    });
                    _saveDraft();
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(AppLocalization.isIndonesian ? 'Tambah ke Daftar' : 'Add to List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // List Ruangan
          Text(
            AppLocalization.isIndonesian
                ? 'Daftar Ruangan Terdaftar (${_rooms.length})'
                : 'Registered Room List (${_rooms.length})',
            style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (_rooms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  AppLocalization.isIndonesian ? 'Belum ada ruangan terdaftar.' : 'No registered rooms yet.',
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rooms.length,
              itemBuilder: (context, i) {
                final room = _rooms[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.meeting_room_rounded,
                            color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.name,
                              style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalization.isIndonesian
                                  ? 'Kapasitas: ${room.capacity} Kursi'
                                  : 'Capacity: ${room.capacity} Seats',
                              style: TextStyle(
                                  color: subtitleColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444), size: 20),
                        onPressed: () {
                          setState(() {
                            _rooms.removeAt(i);
                          });
                          _saveDraft();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── Step 5: Finalisasi & Simpan ──────────────────────────────────
  Widget _buildStep5(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalization.isIndonesian ? 'Alokasi Ruang Ujian & Kursi' : 'Exam Room & Seating Allocation',
            style: TextStyle(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalization.isIndonesian
                ? 'Masukkan murid ke ruangan secara manual atau otomatis dan atur pembagian kursi.'
                : 'Assign students to rooms manually or automatically and manage seating distribution.',
            style: TextStyle(color: subtitleColor, fontSize: 13),
          ),
          const SizedBox(height: 24),
          
          if (_rooms.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final assignments = _calculateRoomAssignments();
                final remainingCounts = _getClassUnassignedCounts(assignments);
                final activeClassIds = _subjectConfigs.expand((c) => c.classIds).toSet();
                final filteredClasses = _allClasses.where((c) => activeClassIds.contains(c['id'] ?? '')).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Murid Belum Dialokasikan (Summary Badges)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_rounded, color: Color(0xFF6366F1), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalization.isIndonesian ? 'Status Murid Belum Dialokasikan' : 'Unallocated Students Status',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: filteredClasses.map((cls) {
                              final className = cls['name'] ?? '';
                              final classId = cls['id'] ?? '';
                              final totalInClass = _studentsByClass[classId]?.length ?? 0;
                              final remaining = remainingCounts[className] ?? 0;

                              Color badgeColor;
                              if (remaining == 0) {
                                badgeColor = Colors.green.withValues(alpha: 0.15);
                              } else if (remaining < totalInClass) {
                                badgeColor = Colors.amber.withValues(alpha: 0.15);
                              } else {
                                badgeColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03);
                              }

                              Color textColor = remaining == 0
                                  ? Colors.green
                                  : (remaining < totalInClass ? Colors.orange : titleColor);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: remaining == 0
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : (remaining < totalInClass
                                            ? Colors.orange.withValues(alpha: 0.3)
                                            : cardBorder),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$className: ',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor),
                                    ),
                                    Text(
                                      '$remaining / $totalInClass',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Seating Allocation Settings Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalization.isIndonesian ? 'Pengaturan Alokasi Otomatis' : 'Automatic Allocation Settings',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.help_outline_rounded, color: subtitleColor, size: 16),
                                onPressed: () {
                                  Get.dialog(
                                    AlertDialog(
                                      backgroundColor: isDark ? const Color(0xFF1A1730) : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1)),
                                          const SizedBox(width: 8),
                                          Text(AppLocalization.isIndonesian ? 'Info Parameter Alokasi' : 'Allocation Parameter Info', style: TextStyle(color: titleColor)),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalization.isIndonesian ? '1. Maksimal Angkatan per Ruangan' : '1. Max Cohorts per Room',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppLocalization.isIndonesian
                                                ? 'Membatasi jumlah angkatan/tahun masuk berbeda yang boleh dicampur di dalam satu ruangan ujian (untuk meminimalkan kecurangan antar angkatan).'
                                                : 'Limits the number of different cohorts/entry years that can be mixed in a single exam room.',
                                            style: TextStyle(fontSize: 12, color: subtitleColor),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            AppLocalization.isIndonesian ? '2. Maksimal Kelas per Ruangan' : '2. Max Classes per Room',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AppLocalization.isIndonesian
                                                ? 'Membatasi jumlah rombel/kelas berbeda yang boleh dimasukkan ke dalam satu ruangan ujian (agar satu ruangan tidak terlalu banyak gabungan kelas).'
                                                : 'Limits the number of different classes/sections that can be assigned to a single exam room.',
                                            style: TextStyle(fontSize: 12, color: subtitleColor),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Get.back(),
                                          child: Text(AppLocalization.isIndonesian ? 'Mengerti' : 'Understood', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final bool isMobile = constraints.maxWidth < 600;
                              final children = [
                                // Dropdown Angkatan
                                Expanded(
                                  flex: isMobile ? 0 : 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Maksimal Angkatan / Ruang' : 'Max Cohorts / Room',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.02),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: cardBorder),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _maxAngkatanPerRoom,
                                            dropdownColor: isDark ? const Color(0xFF1E1C38) : Colors.white,
                                            style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold),
                                            isExpanded: true,
                                            items: [1, 2, 3].map((val) {
                                              return DropdownMenuItem<int>(
                                                value: val,
                                                child: Text(
                                                  AppLocalization.isIndonesian
                                                      ? '$val Angkatan'
                                                      : '$val Cohort${val > 1 ? 's' : ''}',
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() => _maxAngkatanPerRoom = val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 12 : 0),
                                // Dropdown Kelas
                                Expanded(
                                  flex: isMobile ? 0 : 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        AppLocalization.isIndonesian ? 'Maksimal Kelas / Ruang' : 'Max Classes / Room',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.02),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: cardBorder),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: _maxKelasPerRoom,
                                            dropdownColor: isDark ? const Color(0xFF1E1C38) : Colors.white,
                                            style: TextStyle(color: titleColor, fontSize: 12, fontWeight: FontWeight.bold),
                                            isExpanded: true,
                                            items: [1, 2, 3, 4, 5].map((val) {
                                              return DropdownMenuItem<int>(
                                                value: val,
                                                child: Text(
                                                  AppLocalization.isIndonesian
                                                      ? '$val Kelas'
                                                      : '$val Class${val > 1 ? 'es' : ''}',
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() => _maxKelasPerRoom = val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: isMobile ? 0 : 12, height: isMobile ? 16 : 0),
                                // Action Button
                                SizedBox(
                                  width: isMobile ? double.infinity : null,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: isMobile ? double.infinity : null,
                                        height: 38,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _autoAssignClassesToRooms(_maxAngkatanPerRoom, _maxKelasPerRoom),
                                          icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                                          label: Text(
                                            AppLocalization.isIndonesian ? 'Atur Otomatis' : 'Auto Assign',
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isDark ? const Color(0xFF8B5CF6) : const Color(0xFF6366F1),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            elevation: 2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];

                              if (isMobile) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: children.map((c) => c is Expanded ? c.child : c).toList(),
                                );
                              } else {
                                return Row(
                                  children: children,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalization.isIndonesian
                              ? 'Daftar Ruang Ujian (${_rooms.length})'
                              : 'Exam Room List (${_rooms.length})',
                          style: TextStyle(
                              color: titleColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        OutlinedButton.icon(
                          onPressed: _clearAllRoomAllocations,
                          icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 14),
                          label: Text(
                            AppLocalization.isIndonesian ? 'Kosongkan Ruangan' : 'Clear Rooms',
                            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildToggleChip(
                          label: AppLocalization.isIndonesian ? 'Susunan Zigzag' : 'Zigzag Layout',
                          icon: Icons.alt_route_rounded,
                          isActive: _isZigzag,
                          onTap: () => setState(() => _isZigzag = !_isZigzag),
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _buildToggleChip(
                          label: AppLocalization.isIndonesian ? 'Acak Urutan' : 'Randomize Seating',
                          icon: Icons.shuffle_rounded,
                          isActive: _isRandom,
                          onTap: () => setState(() => _isRandom = !_isRandom),
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF13112A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _rooms.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          final expandedSet = _expandedRooms ??= {};
                          final isExpanded = expandedSet.contains(room.name);

                          // Calculate sum of allocated students in this room
                          int roomAllocatedTotal = 0;
                          for (final rawCls in room.classes) {
                            final parts = rawCls.split(':');
                            if (parts.length > 1) {
                              roomAllocatedTotal += int.tryParse(parts[1]) ?? 0;
                            }
                          }
                          final bool isOverCapacity = roomAllocatedTotal > room.capacity;

                          final isEven = index % 2 == 0;
                          final itemBgColor = isEven
                              ? (isDark ? const Color(0xFF1E1C38) : const Color(0xFFF5F3FF))
                              : (isDark ? const Color(0xFF1B1A30) : const Color(0xFFEEF2FF));
                          
                          // Red border if over capacity
                          final itemBorderColor = isOverCapacity
                              ? Colors.red.withValues(alpha: 0.6)
                              : (isEven
                                  ? (isDark ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : const Color(0xFF8B5CF6).withValues(alpha: 0.15))
                                  : (isDark ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.15)));

                          return Ink(
                            decoration: BoxDecoration(
                              color: itemBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: itemBorderColor, width: isOverCapacity ? 1.5 : 1.0),
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    expandedSet.remove(room.name);
                                  } else {
                                    expandedSet.add(room.name);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isOverCapacity
                                                ? Colors.red.withValues(alpha: 0.1)
                                                : const Color(0xFF6366F1).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(Icons.meeting_room_rounded,
                                              color: isOverCapacity ? Colors.red : const Color(0xFF6366F1), size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                room.name,
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (isOverCapacity) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  AppLocalization.isIndonesian
                                                      ? '⚠️ Melebihi Kapasitas! ($roomAllocatedTotal / ${room.capacity} Kursi)'
                                                      : '⚠️ Over Capacity! ($roomAllocatedTotal / ${room.capacity} Seats)',
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            AppLocalization.isIndonesian
                                                ? 'Kapasitas: ${room.capacity} Kursi'
                                                : 'Capacity: ${room.capacity} Seats',
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : Colors.black87,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: subtitleColor,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                    if (isExpanded) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    // Meja layout preview
                                    Row(
                                      children: [
                                        Icon(Icons.table_restaurant_rounded, size: 13, color: isOverCapacity ? Colors.red : const Color(0xFF6366F1)),
                                        const SizedBox(width: 6),
                                        Text(
                                           () {
                                             if (_isZigzag && _isRandom) {
                                               return 'Susunan Kursi Zig-Zag & Acak Preview';
                                             } else if (_isZigzag) {
                                               return 'Susunan Kursi Zig-Zag Preview';
                                             } else if (_isRandom) {
                                               return 'Susunan Kursi Acak Preview';
                                             } else {
                                               return 'Susunan Kursi Berurutan Preview';
                                             }
                                           }(),
                                           style: TextStyle(
                                             color: titleColor.withValues(alpha: 0.8),
                                             fontSize: 11,
                                             fontWeight: FontWeight.bold,
                                           ),
                                         ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    () {
                                      final roomStudents = assignments[index] ?? [];
                                      return Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: List.generate(room.capacity, (idx) {
                                          final num = idx + 1;
                                          final studentIndex = roomStudents.indexWhere((s) => (s['seatNumber'] ?? 0) == num);

                                          if (studentIndex != -1) {
                                            final student = roomStudents[studentIndex];
                                            final name = student['nama'] ?? '';
                                            final angkatan = student['angkatan'] ?? '';
                                            final clsName = student['className'] ?? '';

                                            return Container(
                                              width: 105,
                                              height: 58,
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                                    : const Color(0xFF6366F1).withValues(alpha: 0.05),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                                                      : const Color(0xFF6366F1).withValues(alpha: 0.18),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        'M-$num',
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white54 : Colors.black54,
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          angkatan.isNotEmpty ? 'A-$angkatan' : clsName,
                                                          style: const TextStyle(
                                                            color: Color(0xFF8B5CF6),
                                                            fontSize: 7,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    name,
                                                    style: TextStyle(
                                                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    clsName,
                                                    style: TextStyle(
                                                      color: isDark ? Colors.white38 : Colors.black38,
                                                      fontSize: 7,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            );
                                          } else {
                                            // Placeholder empty seat
                                            return Container(
                                              width: 105,
                                              height: 58,
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white.withValues(alpha: 0.02)
                                                    : Colors.black.withValues(alpha: 0.01),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isDark ? Colors.white10 : Colors.black12,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'M-$num',
                                                    style: TextStyle(
                                                      color: isDark ? Colors.white24 : Colors.black26,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const Center(
                                                     child: Text(
                                                       'KOSONG',
                                                       style: TextStyle(
                                                         color: Colors.grey,
                                                         fontSize: 8,
                                                         fontWeight: FontWeight.w600,
                                                         letterSpacing: 0.5,
                                                       ),
                                                     ),
                                                   ),
                                                   const SizedBox(height: 8),
                                                 ],
                                               ),
                                             );
                                           }
                                         }),
                                      );
                                    }(),
                                    const SizedBox(height: 16),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    Text(
                                      AppLocalization.isIndonesian
                                          ? 'Alokasi Jumlah Murid Per Kelas'
                                          : 'Student Allocation Per Class',
                                      style: TextStyle(
                                        color: titleColor.withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (filteredClasses.isEmpty)
                                      Text(
                                        AppLocalization.isIndonesian
                                            ? 'Tidak ada kelas terpilih dari mata pelajaran.'
                                            : 'No classes selected from subjects.',
                                        style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic),
                                      )
                                    else
                                      Column(
                                        children: filteredClasses.map((cls) {
                                          final className = cls['name'] ?? '';
                                          final classId = cls['id'] ?? '';
                                          final totalInClass = _studentsByClass[classId]?.length ?? 0;
                                          final remaining = remainingCounts[className] ?? 0;

                                          // Get current count allocated in this room
                                          int currentAllocated = 0;
                                          final match = room.classes.firstWhere((c) => c.startsWith('$className:'), orElse: () => '');
                                          if (match.isNotEmpty) {
                                            currentAllocated = int.tryParse(match.split(':')[1]) ?? 0;
                                          }

                                          final maxAllowed = remaining + currentAllocated;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: cardBorder),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      className,
                                                      style: TextStyle(
                                                        color: titleColor,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      AppLocalization.isIndonesian
                                                          ? 'Tersisa: $remaining / $totalInClass siswa'
                                                          : 'Remaining: $remaining / $totalInClass students',
                                                      style: TextStyle(
                                                        color: remaining == 0 ? Colors.green : subtitleColor,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    // Minus button
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                                      color: currentAllocated > 0 ? const Color(0xFF6366F1) : subtitleColor.withValues(alpha: 0.5),
                                                      onPressed: currentAllocated > 0
                                                          ? () {
                                                              final updated = List<String>.from(room.classes);
                                                              updated.removeWhere((c) => c.startsWith('$className:'));
                                                              final newVal = currentAllocated - 1;
                                                              if (newVal > 0) {
                                                                updated.add('$className:$newVal');
                                                              }
                                                              updated.sort();
                                                              setState(() {
                                                                _rooms[index] = room.copyWith(classes: updated);
                                                              });
                                                              _saveDraft();
                                                            }
                                                          : null,
                                                    ),
                                                    // Count text field
                                                    SizedBox(
                                                      width: 54,
                                                      height: 36,
                                                      child: TextFormField(
                                                        key: ValueKey('${room.name}_${className}_$currentAllocated'),
                                                        initialValue: currentAllocated.toString(),
                                                        keyboardType: TextInputType.number,
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                          color: titleColor,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        decoration: InputDecoration(
                                                          contentPadding: EdgeInsets.zero,
                                                          border: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                            borderSide: BorderSide(color: cardBorder),
                                                          ),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                            borderSide: BorderSide(color: cardBorder),
                                                          ),
                                                          focusedBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(8),
                                                            borderSide: const BorderSide(color: Color(0xFF6366F1)),
                                                          ),
                                                        ),
                                                        onChanged: (val) {
                                                          final valInt = int.tryParse(val) ?? 0;
                                                          if (valInt == currentAllocated) return;
                                                          int target = valInt;
                                                          if (target < 0) target = 0;
                                                          if (target > maxAllowed) target = maxAllowed;

                                                          final updated = List<String>.from(room.classes);
                                                          updated.removeWhere((c) => c.startsWith('$className:'));
                                                          if (target > 0) {
                                                            updated.add('$className:$target');
                                                          }
                                                          updated.sort();
                                                          setState(() {
                                                            _rooms[index] = room.copyWith(classes: updated);
                                                          });
                                                          _saveDraft();
                                                        },
                                                      ),
                                                    ),
                                                    // Plus button
                                                    IconButton(
                                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                                      color: remaining > 0 ? const Color(0xFF6366F1) : subtitleColor.withValues(alpha: 0.5),
                                                      onPressed: remaining > 0
                                                          ? () {
                                                              final updated = List<String>.from(room.classes);
                                                              updated.removeWhere((c) => c.startsWith('$className:'));
                                                              final newVal = currentAllocated + 1;
                                                              updated.add('$className:$newVal');
                                                              updated.sort();
                                                              setState(() {
                                                                _rooms[index] = room.copyWith(classes: updated);
                                                              });
                                                              _saveDraft();
                                                            }
                                                          : null,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep5Schedule(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.isIndonesian ? 'Jadwal Ujian & Mata Pelajaran' : 'Exam Schedule & Subjects',
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalization.isIndonesian
                          ? 'Tentukan jadwal mata pelajaran untuk setiap sesi ujian.'
                          : 'Assign subject schedules for each exam session.',
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _clearSchedule,
                    icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 16),
                    label: Text(
                      AppLocalization.isIndonesian ? 'Kosongkan' : 'Clear',
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _autoGenerateSchedule,
                    icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    label: Text(
                      AppLocalization.isIndonesian ? 'Generate Otomatis' : 'Auto Generate',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildScheduleSection(isDark, cardColor, cardBorder, titleColor, subtitleColor),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _clearSchedule() {
    setState(() {
      _scheduledSubjects.clear();
    });
    _saveDraft();
    _compileDraftSessions();
    Get.snackbar(
      AppLocalization.isIndonesian ? 'Sukses' : 'Success',
      AppLocalization.isIndonesian
          ? 'Jadwal ujian berhasil dikosongkan.'
          : 'Exam schedule successfully cleared.',
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
    );
  }

  void _autoGenerateSchedule() {
    final days = _getEventDays();
    if (days.isEmpty || _slots.isEmpty) {
      _showError(AppLocalization.isIndonesian
          ? 'Tentukan rentang tanggal di Step 1 dan slot waktu terlebih dahulu.'
          : 'Please set the date range in Step 1 and time slots first.');
      return;
    }

    setState(() {
      _scheduledSubjects.clear();
    });

    // 1. Partition subjects into General (Umum) and Specialization (Penjurusan) groups, shuffle them, and combine
    final int maxClasses = _subjectConfigs.isEmpty 
        ? 0 
        : _subjectConfigs.map((s) => s.classIds.length).fold(0, (maxVal, countVal) => countVal > maxVal ? countVal : maxVal);
    
    // A subject is general if it targets at least 70% of the maximum class participation count
    final threshold = maxClasses <= 1 ? 1 : (maxClasses * 0.7).ceil();
    final List<ExamSubjectConfig> generalSubjects = [];
    final List<ExamSubjectConfig> specializationSubjects = [];

    for (final config in _subjectConfigs) {
      if (config.classIds.length >= threshold) {
        generalSubjects.add(config);
      } else {
        specializationSubjects.add(config);
      }
    }

    // Shuffle both lists independently for random ordering within categories
    generalSubjects.shuffle();
    specializationSubjects.shuffle();

    final List<ExamSubjectConfig> sortedConfigs = [...generalSubjects, ...specializationSubjects];

    // Map class name to class id
    final Map<String, String> classNameToId = {};
    for (final cls in _allClasses) {
      classNameToId[cls['name'] as String] = cls['id'] as String;
    }

    // 2. Track busy classes per slot
    final Map<String, Set<String>> busyClassesInSlot = {};

    // 3. Chronological time slots
    final List<Map<String, dynamic>> timeSlots = [];
    for (final day in days) {
      final dayStr = DateFormat('yyyy-MM-dd').format(day);
      for (final slot in _slots) {
        timeSlots.add({
          'dayStr': dayStr,
          'slot': slot,
        });
      }
    }

    // 4. Schedule each subject config
    for (final config in sortedConfigs) {
      final configClassIds = config.classIds.toSet();
      bool scheduled = false;

      // Find the earliest slot where no classes for this subject are busy
      for (final timeSlot in timeSlots) {
        final dayStr = timeSlot['dayStr'] as String;
        final slotName = (timeSlot['slot'] as ExamSlot).name;
        final slotKey = '${dayStr}_$slotName';

        final busy = busyClassesInSlot[slotKey] ?? {};
        if (busy.intersection(configClassIds).isEmpty) {
          // No conflict, schedule here!
          setState(() {
            // Assign subject for each class in each room that has this class
            for (final room in _rooms) {
              final List<String> roomClassNames = room.classes.map((c) => c.split(':')[0]).toList();
              for (final clsName in roomClassNames) {
                final cid = classNameToId[clsName] ?? '';
                if (config.classIds.contains(cid)) {
                  final targetKey = '${dayStr}_${slotName}_${room.name}_$clsName';
                  _scheduledSubjects[targetKey] = config.subjectId;
                }
              }
            }
            // Mark classes as busy in this slot
            busyClassesInSlot.putIfAbsent(slotKey, () => {}).addAll(configClassIds);
          });
          scheduled = true;
          break;
        }
      }

      if (!scheduled) {
        // If we ran out of time slots, display a warning
        _showError(AppLocalization.isIndonesian
            ? 'Gagal menjadwalkan "${config.subjectName}" karena slot waktu penuh.'
            : 'Failed to schedule "${config.subjectName}" because time slots are full.');
        return;
      }
    }

    _saveDraft();
    _compileDraftSessions();

    Get.snackbar(
      AppLocalization.isIndonesian ? 'Sukses' : 'Success',
      AppLocalization.isIndonesian
          ? 'Berhasil menyusun ${_subjectConfigs.length} mata pelajaran secara otomatis.'
          : 'Successfully scheduled ${_subjectConfigs.length} subjects automatically.',
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
    );
  }

  void _clearAllRoomAllocations() {
    setState(() {
      for (int i = 0; i < _rooms.length; i++) {
        _rooms[i] = _rooms[i].copyWith(classes: []);
      }
    });
    _saveDraft();
    Get.snackbar(
      AppLocalization.isIndonesian ? 'Sukses' : 'Success',
      AppLocalization.isIndonesian 
          ? 'Semua alokasi ruang ujian berhasil dikosongkan.' 
          : 'All room allocations cleared successfully.',
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
    );
  }

  void _autoAssignClassesToRooms(int maxAngkatan, int maxKelas) {
    if (_allClasses.isEmpty) return;

    final activeClassIds = _subjectConfigs.expand((c) => c.classIds).toSet();
    final participatingClasses = _allClasses.where((cls) => activeClassIds.contains(cls['id'])).toList();

    // 1. Map classId to cohort and student count
    final Map<String, String> classToCohort = {};
    final Map<String, int> classStudentCount = {};
    final Map<String, String> classIdToName = {};
    
    for (final cls in participatingClasses) {
      final cid = cls['id'] as String;
      final cname = cls['name'] as String;
      classIdToName[cid] = cname;
      final students = _studentsByClass[cid] ?? [];
      
      classStudentCount[cid] = students.length;
      
      String cohort = '';
      if (students.isNotEmpty) {
        final counts = <String, int>{};
        for (final s in students) {
          final a = s['angkatan'] as String;
          counts[a] = (counts[a] ?? 0) + 1;
        }
        cohort = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }
      if (cohort.isEmpty) {
        if (cname.startsWith('XII') || cname.contains('12')) {
          cohort = '2022';
        } else if (cname.startsWith('XI') || cname.contains('11')) {
          cohort = '2023';
        } else {
          cohort = '2024';
        }
      }
      classToCohort[cid] = cohort;
    }

    // 2. Group class IDs by cohort (ONLY classes with students)
    final Map<String, List<String>> classesByCohort = {};
    for (final cls in participatingClasses) {
      final cid = cls['id'] as String;
      if ((classStudentCount[cid] ?? 0) <= 0) continue; // Skip classes with no students
      final cohort = classToCohort[cid]!;
      classesByCohort.putIfAbsent(cohort, () => []).add(cid);
    }

    // Prepare remaining student counts
    final Map<String, int> remainingClassStudents = Map.from(classStudentCount);

    // List of rooms to update
    final List<ExamRoom> updatedRooms = [];

    for (final room in _rooms) {
      final capacity = room.capacity;
      final List<String> roomClasses = [];

      // Find Cohorts that still have students
      final activeCohorts = classesByCohort.keys.where((cohort) {
        return classesByCohort[cohort]!.any((cid) => remainingClassStudents[cid]! > 0);
      }).toList()..sort();

      if (activeCohorts.isEmpty) {
        // No more students to assign
        updatedRooms.add(room.copyWith(classes: []));
        continue;
      }

      // Mix up to maxAngkatan cohorts
      final int numMix = maxAngkatan < activeCohorts.length ? maxAngkatan : activeCohorts.length;
      final List<String> selectedCohorts = [];
      for (int i = 0; i < numMix; i++) {
        selectedCohorts.add(activeCohorts[i]);
      }

      // Find candidate classes from the selected cohorts that still have remaining students
      final Map<String, List<String>> cohortToCandidates = {};
      for (final cohort in selectedCohorts) {
        final list = classesByCohort[cohort]!.where((cid) => remainingClassStudents[cid]! > 0).toList()..sort();
        cohortToCandidates[cohort] = list;
      }

      // Select up to maxKelas classes round-robin from selected cohorts
      final List<String> chosenClassIds = [];
      int cohortPointer = 0;
      bool addedAny = true;
      while (chosenClassIds.length < maxKelas && addedAny) {
        addedAny = false;
        for (int i = 0; i < selectedCohorts.length; i++) {
          final idx = (cohortPointer + i) % selectedCohorts.length;
          final cohort = selectedCohorts[idx];
          final candidates = cohortToCandidates[cohort] ?? [];
          if (candidates.isNotEmpty) {
            final cid = candidates.removeAt(0); // take first class
            chosenClassIds.add(cid);
            addedAny = true;
            cohortPointer = (idx + 1) % selectedCohorts.length;
            break; // break to update index and keep round-robin across cohorts
          }
        }
      }

      final Map<String, int> allocatedCounts = { for (var cid in chosenClassIds) cid : 0 };
      int remainingCapacity = capacity;
      
      // Filter chosenClassIds to those that actually have students
      List<String> activeRoomClasses = chosenClassIds.where((cid) => remainingClassStudents[cid]! > 0).toList();
      int classPointer = 0;

      while (remainingCapacity > 0 && activeRoomClasses.isNotEmpty) {
        final cid = activeRoomClasses[classPointer];
        final currentAllocated = allocatedCounts[cid] ?? 0;
        final totalAvailable = remainingClassStudents[cid]!;
        
        if (currentAllocated < totalAvailable) {
          allocatedCounts[cid] = currentAllocated + 1;
          remainingCapacity--;
          classPointer = (classPointer + 1) % activeRoomClasses.length;
        } else {
          activeRoomClasses.removeAt(classPointer);
          if (activeRoomClasses.isNotEmpty) {
            classPointer = classPointer % activeRoomClasses.length;
          }
        }
      }

      // Subtract allocated counts from remainingClassStudents and format string
      allocatedCounts.forEach((cid, cnt) {
        remainingClassStudents[cid] = remainingClassStudents[cid]! - cnt;
        if (cnt > 0) {
          final cname = classIdToName[cid]!;
          roomClasses.add('$cname:$cnt');
        }
      });

      roomClasses.sort();
      updatedRooms.add(room.copyWith(classes: roomClasses));
    }

    setState(() {
      _rooms.clear();
      _rooms.addAll(updatedRooms);
    });
    _saveDraft();

    // Check for remaining unassigned students
    final List<String> unassignedDetails = [];
    int totalUnassigned = 0;
    remainingClassStudents.forEach((cid, cnt) {
      if (cnt > 0) {
        final cname = classIdToName[cid]!;
        totalUnassigned += cnt;
        unassignedDetails.add('$cname ($cnt siswa)');
      }
    });

    if (totalUnassigned > 0) {
      Get.dialog(
        ValueListenableBuilder<bool>(
          valueListenable: AuthBackground.isDarkMode,
          builder: (context, isDark, _) {
            final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final dialogBg = isDark ? const Color(0xFF1A1730) : Colors.white;
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Text('Kapasitas Kurang', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semua ruangan telah diisi penuh, namun masih ada total $totalUnassigned murid yang belum mendapatkan bangku:',
                    style: TextStyle(color: titleColor.withValues(alpha: 0.85), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        unassignedDetails.join('\n'),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      );
    } else {
      Get.snackbar(
        'Pembagian Otomatis Berhasil',
        'Semua murid telah teralokasikan secara merata ke seluruh ruangan.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  Future<void> _saveAndCreateEvent() async {
    if (_titleController.text.trim().isEmpty) {
      _showError(AppLocalization.isIndonesian
          ? 'Jadwal/Nama Event tidak boleh kosong'
          : 'Schedule/Event Name cannot be empty');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showError(AppLocalization.isIndonesian ? 'Rentang tanggal belum dipilih' : 'Date range has not been selected');
      return;
    }
    if (_slots.isEmpty) {
      _showError(AppLocalization.isIndonesian ? 'Slot waktu belum dikonfigurasi' : 'Time slots have not been configured');
      return;
    }
    if (_rooms.isEmpty) {
      _showError(AppLocalization.isIndonesian ? 'Ruangan belum dikonfigurasi' : 'Rooms have not been configured');
      return;
    }

    // Check scheduled subjects
    final scheduledSubjectIds = _scheduledSubjects.values.toSet();
    final unscheduledSubjects = _subjectConfigs.where((s) => !scheduledSubjectIds.contains(s.subjectId)).toList();
    if (unscheduledSubjects.isNotEmpty) {
      _showError(AppLocalization.isIndonesian
          ? 'Terdapat ${unscheduledSubjects.length} mata pelajaran yang belum dijadwalkan: ${unscheduledSubjects.map((s) => s.subjectName).join(', ')}'
          : 'There are ${unscheduledSubjects.length} subjects that have not been scheduled: ${unscheduledSubjects.map((s) => s.subjectName).join(', ')}');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final event = ExamEvent(
        id: '',
        title: _titleController.text.trim(),
        examType: _examType,
        startDate: _startDate!,
        endDate: _endDate!,
        dailySlots: _slots,
        subjectConfigs: _subjectConfigs,
        rooms: _rooms,
        examStatus: 'Planning',
        isAutoGenerated: false,
        createdAt: DateTime.now(),
      );

      final eventId = await _sessionService.createExamEvent(
          schoolId: schoolId, event: event);

      // Now generate sessions
      final assignments = _calculateRoomAssignments();
      final List<ExamSession> generatedSessions = [];

      final days = _getEventDays();
      for (final day in days) {
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        for (final slot in _slots) {
          for (int i = 0; i < _rooms.length; i++) {
            final room = _rooms[i];
            final roomStudents = assignments[i] ?? [];

            // Group room students by subject scheduled for their class in this slot
            final Map<String, List<Map<String, dynamic>>> studentsBySubject = {};

            for (final student in roomStudents) {
              final clsName = student['className'] as String? ?? '';
              final scheduleKey = '${dayStr}_${slot.name}_${room.name}_$clsName';
              final subjectId = _scheduledSubjects[scheduleKey];
              if (subjectId != null && subjectId.isNotEmpty) {
                studentsBySubject.putIfAbsent(subjectId, () => []).add(student);
              }
            }

            studentsBySubject.forEach((subjectId, sessionStudents) {
              final configMatches = _subjectConfigs.where((c) => c.subjectId == subjectId).toList();
              if (configMatches.isEmpty) return;
              final config = configMatches.first;

              final List<ExamParticipation> participations = sessionStudents.map((s) {
                return ExamParticipation(
                  studentId: s['id'] ?? '',
                  studentName: s['nama'] ?? s['name'] ?? '',
                  nis: s['nis'] ?? '',
                  hasStarted: false,
                  seatNumber: s['seatNumber'] as int? ?? 0,
                  roomName: room.name,
                  angkatan: s['angkatan'] ?? '',
                );
              }).toList();

              final sessionClasses = sessionStudents.map((s) => s['className'] as String).toSet().toList()..sort();

              // Look up proctor from _draftSessions
              String sessionProctorId = '';
              String sessionProctorName = 'Belum ditugaskan';
              if (_draftSessions.isNotEmpty) {
                final matchedDraft = _draftSessions.cast<Map<String, dynamic>?>().firstWhere(
                  (s) => s != null &&
                      s['date'] == day &&
                      s['slotName'] == slot.name &&
                      s['roomName'] == room.name &&
                      s['subjectId'] == config.subjectId,
                  orElse: () => null,
                );
                if (matchedDraft != null) {
                  sessionProctorId = matchedDraft['proctorId'] as String? ?? '';
                  sessionProctorName = matchedDraft['proctorName'] as String? ?? 'Belum ditugaskan';
                }
              }

              final session = ExamSession(
                id: '', // will be set in saveGeneratedSessions
                eventId: eventId,
                subjectId: config.subjectId,
                subjectName: config.subjectName,
                classId: config.classIds.join(', '),
                className: sessionClasses.join(', '),
                date: day,
                slotName: slot.name,
                startTime: slot.startTime,
                endTime: slot.endTime,
                roomName: room.name,
                proctorId: sessionProctorId,
                proctorName: sessionProctorName,
                authorTeacherId: config.authorTeacherId,
                qrToken: ExamSessionService.generateQrToken(),
                isQrActive: false,
                examStatus: 'Scheduled',
                previewParticipations: participations,
              );

              generatedSessions.add(session);
            });
          }
        }
      }

      // Save generated sessions to Firestore
      if (generatedSessions.isNotEmpty) {
        await _sessionService.saveGeneratedSessions(schoolId, generatedSessions);
      }

      if (mounted) {
        setState(() => _isGenerating = false);
        await _clearDraft();
        Get.back(); // Back to list page
        Get.to(() => AdminExamScheduleViewPage(eventId: eventId));
        Get.snackbar(
          AppLocalization.isIndonesian ? 'Sukses' : 'Success',
          AppLocalization.isIndonesian
              ? 'Event ujian berhasil dibuat. Silakan tambahkan jadwal sesi secara manual.'
              : 'Exam event successfully created. Please add session schedules manually.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isGenerating = false);
      _showError(AppLocalization.isIndonesian ? 'Gagal membuat event: $e' : 'Failed to create event: $e');
    }
  }

  // ── Save & Update (Edit Mode) ────────────────────────────────
  Future<void> _saveAndUpdateEvent() async {
    if (_titleController.text.trim().isEmpty) {
      _showError(AppLocalization.isIndonesian ? 'Nama event tidak boleh kosong' : 'Event name cannot be empty');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showError(AppLocalization.isIndonesian ? 'Rentang tanggal belum dipilih' : 'Date range has not been selected');
      return;
    }
    if (_slots.isEmpty) {
      _showError(AppLocalization.isIndonesian ? 'Slot waktu belum dikonfigurasi' : 'Time slots have not been configured');
      return;
    }
    if (_rooms.isEmpty) {
      _showError(AppLocalization.isIndonesian ? 'Ruangan belum dikonfigurasi' : 'Rooms have not been configured');
      return;
    }

    final scheduledSubjectIds = _scheduledSubjects.values.toSet();
    final unscheduledSubjects = _subjectConfigs
        .where((s) => !scheduledSubjectIds.contains(s.subjectId))
        .toList();
    if (unscheduledSubjects.isNotEmpty) {
      _showError(AppLocalization.isIndonesian
          ? 'Terdapat ${unscheduledSubjects.length} mata pelajaran yang belum dijadwalkan: ${unscheduledSubjects.map((s) => s.subjectName).join(', ')}'
          : 'There are ${unscheduledSubjects.length} subjects that have not been scheduled: ${unscheduledSubjects.map((s) => s.subjectName).join(', ')}');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final schoolId = SessionService.currentUser!.schoolId;
      final eventId = _editingEventId ?? widget.editEvent?.id;
      if (eventId == null) {
        _showError(AppLocalization.isIndonesian ? 'ID Event tidak ditemukan' : 'Event ID not found');
        setState(() => _isGenerating = false);
        return;
      }
      final db       = FirebaseFirestore.instance;

      // 1. Update exam_event document
      await db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_events')
          .doc(eventId)
          .update({
        'title':          _titleController.text.trim(),
        'examType':       _examType,
        'startDate':      Timestamp.fromDate(_startDate!),
        'endDate':        Timestamp.fromDate(_endDate!),
        'dailySlots':     _slots.map((s) => s.toMap()).toList(),
        'subjectConfigs': _subjectConfigs.map((c) => c.toMap()).toList(),
        'rooms':          _rooms.map((r) => r.toMap()).toList(),
      });

      // 2. Delete all existing sessions cleanly (including participations subcollections)
      final List<DocumentReference> refsToDelete = [];
      final oldSessionsSnap = await db
          .collection('schools')
          .doc(schoolId)
          .collection('exam_sessions')
          .where('eventId', isEqualTo: eventId)
          .get();

      for (final sDoc in oldSessionsSnap.docs) {
        // Collect participations
        final parts = await sDoc.reference.collection('participations').get();
        for (final pDoc in parts.docs) {
          refsToDelete.add(pDoc.reference);
        }
        refsToDelete.add(sDoc.reference);
      }

      // Execute chunked delete to avoid exceeding batch limit of 500
      for (int i = 0; i < refsToDelete.length; i += 400) {
        final chunk = refsToDelete.sublist(
          i,
          i + 400 > refsToDelete.length ? refsToDelete.length : i + 400,
        );
        final chunkBatch = db.batch();
        for (final ref in chunk) {
          chunkBatch.delete(ref);
        }
        await chunkBatch.commit();
      }

      // 3. Regenerate sessions from current state
      final assignments = _calculateRoomAssignments();
      final List<ExamSession> generatedSessions = [];

      final days = _getEventDays();
      for (final day in days) {
        final dayStr = DateFormat('yyyy-MM-dd').format(day);
        for (final slot in _slots) {
          for (int i = 0; i < _rooms.length; i++) {
            final room = _rooms[i];
            final roomStudents = assignments[i] ?? [];

            final Map<String, List<Map<String, dynamic>>> studentsBySubject = {};
            for (final student in roomStudents) {
              final clsName = student['className'] as String? ?? '';
              final scheduleKey =
                  '${dayStr}_${slot.name}_${room.name}_$clsName';
              final subjectId = _scheduledSubjects[scheduleKey];
              if (subjectId != null && subjectId.isNotEmpty) {
                studentsBySubject.putIfAbsent(subjectId, () => []).add(student);
              }
            }

            studentsBySubject.forEach((subjectId, sessionStudents) {
              final configMatches = _subjectConfigs
                  .where((c) => c.subjectId == subjectId)
                  .toList();
              if (configMatches.isEmpty) return;
              final config = configMatches.first;

              final List<ExamParticipation> participations =
                  sessionStudents.map((s) {
                return ExamParticipation(
                  studentId:   s['id'] ?? '',
                  studentName: s['nama'] ?? s['name'] ?? '',
                  nis:         s['nis'] ?? '',
                  hasStarted:  false,
                  seatNumber:  s['seatNumber'] as int? ?? 0,
                  roomName:    room.name,
                  angkatan:    s['angkatan'] ?? '',
                );
              }).toList();

              final sessionClasses = sessionStudents
                  .map((s) => s['className'] as String)
                  .toSet()
                  .toList()
                ..sort();

              // Preserve proctor assignment from _draftSessions
              String sessionProctorId   = '';
              String sessionProctorName = 'Belum ditugaskan';
              if (_draftSessions.isNotEmpty) {
                final matchedDraft =
                    _draftSessions.cast<Map<String, dynamic>?>().firstWhere(
                  (s) =>
                      s != null &&
                      DateFormat('yyyy-MM-dd').format(s['date'] as DateTime) == dayStr &&
                      s['slotName'] == slot.name &&
                      s['roomName'] == room.name &&
                      s['subjectId'] == config.subjectId,
                  orElse: () => null,
                );
                if (matchedDraft != null) {
                  sessionProctorId   = matchedDraft['proctorId'] as String? ?? '';
                  sessionProctorName = matchedDraft['proctorName'] as String? ?? 'Belum ditugaskan';
                }
              }

              generatedSessions.add(ExamSession(
                id:               '',
                eventId:          eventId,
                subjectId:        config.subjectId,
                subjectName:      config.subjectName,
                classId:          config.classIds.join(', '),
                className:        sessionClasses.join(', '),
                date:             day,
                slotName:         slot.name,
                startTime:        slot.startTime,
                endTime:          slot.endTime,
                roomName:         room.name,
                proctorId:        sessionProctorId,
                proctorName:      sessionProctorName,
                authorTeacherId:  config.authorTeacherId,
                qrToken:          ExamSessionService.generateQrToken(),
                isQrActive:       false,
                examStatus:       'Scheduled',
                previewParticipations: participations,
              ));
            });
          }
        }
      }

      if (generatedSessions.isNotEmpty) {
        await _sessionService.saveGeneratedSessions(schoolId, generatedSessions);
      }

      if (mounted) {
        setState(() => _isGenerating = false);
        await _clearDraft();
        Get.back(); // back to event list
        Get.snackbar(
          AppLocalization.isIndonesian ? 'Berhasil Diperbarui' : 'Updated',
          AppLocalization.isIndonesian
              ? 'Event ujian berhasil diperbarui.'
              : 'Exam event updated successfully.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isGenerating = false);
      _showError(AppLocalization.isIndonesian ? 'Gagal memperbarui event: $e' : 'Failed to update event: $e');
    }
  }



  // ── UI Helpers ───────────────────────────────────────────────
  Widget _buildToggleChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF6366F1).withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF6366F1)
                : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? const Color(0xFF6366F1) : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF6366F1) : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.7)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.7),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _inputDecoration(
      String hint, bool isDark, Color bg, Color border) {
    final hintColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.35);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor),
      filled: true,
      fillColor: bg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
    );
  }

  Widget _buildDatePickerButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required Color inputBg,
    required Color cardBorder,
    required Color titleColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: titleColor, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required Color inputBg,
    required Color cardBorder,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: titleColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep6(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    // Auto-compile sessions if empty but schedule has content
    if (_draftSessions.isEmpty && _scheduledSubjects.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _compileDraftSessions());
    }

    // Group draft sessions by date
    final Map<String, List<Map<String, dynamic>>> sessionsByDay = {};
    for (final session in _draftSessions) {
      final dayStr = DateFormat('yyyy-MM-dd').format(session['date'] as DateTime);
      sessionsByDay.putIfAbsent(dayStr, () => []).add(session);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.isIndonesian ? 'Distribusi Pengawas Ujian' : 'Exam Proctor Assignment',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalization.isIndonesian
                          ? 'Tugaskan guru pengawas untuk setiap ruangan & sesi.'
                          : 'Assign teacher proctors for each room & session.',
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _clearProctors,
                    icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 14),
                    label: Text(
                      AppLocalization.isIndonesian ? 'Kosongkan' : 'Clear',
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _autoAssignProctors,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                    label: Text(
                      AppLocalization.isIndonesian ? 'Atur Otomatis' : 'Auto Assign',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_draftSessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  AppLocalization.isIndonesian
                      ? 'Belum ada jadwal mapel yang disusun di Step sebelumnya.'
                      : 'No subject schedules have been created in the previous step.',
                  style: TextStyle(color: subtitleColor),
                ),
              ),
            )
          else
            ...sessionsByDay.entries.map((entry) {
              final dayStr = entry.key;
              final daySessions = entry.value;
              final parsedDate = DateTime.parse(dayStr);
              final dayLabel = DateFormat('EEEE, dd MMMM yyyy', 'id').format(parsedDate);

              // Group daySessions by slot
              final Map<String, List<Map<String, dynamic>>> sessionsBySlot = {};
              for (final s in daySessions) {
                final slotName = s['slotName'] as String;
                sessionsBySlot.putIfAbsent(slotName, () => []).add(s);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    
                    // Slots inside the day
                    ...sessionsBySlot.entries.map((slotEntry) {
                      final slotName = slotEntry.key;
                      final slotSessions = slotEntry.value;
                      final sampleSession = slotSessions.first;
                      final timeRange = '${sampleSession['startTime']} - ${sampleSession['endTime']}';

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$slotName ($timeRange)',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Group slotSessions by roomName to render 1 card & 1 proctor per room
                            () {
                              final Map<String, List<Map<String, dynamic>>> roomSessionsMap = {};
                              for (final s in slotSessions) {
                                final rName = s['roomName'] as String;
                                roomSessionsMap.putIfAbsent(rName, () => []).add(s);
                              }

                              return Column(
                                children: roomSessionsMap.entries.map((roomEntry) {
                                  final roomName = roomEntry.key;
                                  final roomSessions = roomEntry.value;
                                  final sampleSession = roomSessions.first;
                                  final pId = sampleSession['proctorId'] as String;

                                  final hasConf = roomSessions.any((s) => hasConflict(s));
                                  final hasExceed = roomSessions.any((s) => exceedsDailyLimit(s));

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                roomName,
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              ...roomSessions.map((s) {
                                                final subName = s['subjectName'] as String;
                                                final clsList = s['classes'] as List<String>;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Text(
                                                    '$subName (${clsList.join(', ')})',
                                                    style: TextStyle(
                                                      color: subtitleColor,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                );
                                              }),
                                              if (hasConf || hasExceed) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    if (hasConf) ...[
                                                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 12),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        AppLocalization.isIndonesian ? 'Bentrokan Sesi' : 'Session Conflict',
                                                        style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    if (hasExceed) ...[
                                                      const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 12),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        AppLocalization.isIndonesian ? 'Melebihi 2 Sesi' : 'Exceeds 2 Sessions',
                                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E1C38) : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: hasConf
                                                    ? Colors.redAccent
                                                    : (hasExceed
                                                        ? Colors.orangeAccent
                                                        : (pId.isNotEmpty
                                                            ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                                                            : cardBorder)),
                                              ),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: pId.isEmpty ? null : pId,
                                                hint: Text(
                                                  AppLocalization.isIndonesian ? 'Pilih Pengawas' : 'Select Proctor',
                                                  style: TextStyle(
                                                    color: subtitleColor,
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                                dropdownColor: isDark ? const Color(0xFF1E1C38) : Colors.white,
                                                isExpanded: true,
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontSize: 12,
                                                ),
                                                items: [
                                                  DropdownMenuItem<String>(
                                                    value: null,
                                                    child: Text(
                                                      AppLocalization.isIndonesian ? 'Belum ditugaskan' : 'Not assigned',
                                                      style: const TextStyle(fontStyle: FontStyle.italic),
                                                    ),
                                                  ),
                                                  ...() {
                                                    final List<Map<String, dynamic>> teachersList = List.from(_allTeachers);
                                                    if (pId.isNotEmpty && !teachersList.any((t) => t['id'] == pId)) {
                                                      teachersList.add({
                                                        'id': pId,
                                                        'nama': sampleSession['proctorName'] ?? (AppLocalization.isIndonesian ? 'Loading pengawas...' : 'Loading proctor...'),
                                                      });
                                                    }
                                                    return teachersList.map((teacher) {
                                                      return DropdownMenuItem<String>(
                                                        value: teacher['id'] as String,
                                                        child: Text(teacher['nama'] as String),
                                                      );
                                                    });
                                                  }(),
                                                ],
                                                onChanged: (val) {
                                                  setState(() {
                                                    for (final s in roomSessions) {
                                                      if (val == null) {
                                                        s['proctorId'] = '';
                                                        s['proctorName'] = 'Belum ditugaskan';
                                                      } else {
                                                        final teacher = _allTeachers.firstWhere((t) => t['id'] == val);
                                                        s['proctorId'] = val;
                                                        s['proctorName'] = teacher['nama'] as String;
                                                      }
                                                    }
                                                  });
                                                  _saveDraft();
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            }(),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showSessionDetailDialog(
    String roomName,
    List<Map<String, dynamic>> roomSessions,
    String dayLabel,
    String slotName,
    String timeRange,
  ) {
    final sampleSession = roomSessions.first;
    final proctorName = sampleSession['proctorName'] as String? ?? 'Belum ditugaskan';
    final displayProctorName = (proctorName.isEmpty || proctorName == 'Belum ditugaskan' || proctorName == 'Not assigned')
        ? (AppLocalization.isIndonesian ? 'Belum ditugaskan' : 'Not assigned')
        : proctorName;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalization.isIndonesian ? 'Detail Ruang Ujian' : 'Exam Room Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // Room & Time details
              _buildDetailRow(AppLocalization.isIndonesian ? 'Ruangan' : 'Room', roomName),
              _buildDetailRow(AppLocalization.isIndonesian ? 'Waktu' : 'Time', '$dayLabel • ${slotName.replaceAll('Sesi', AppLocalization.isIndonesian ? 'Sesi' : 'Session')} ($timeRange)'),
              _buildDetailRow(AppLocalization.isIndonesian ? 'Pengawas' : 'Proctor', displayProctorName),
              const SizedBox(height: 16),
              
              Text(
                AppLocalization.isIndonesian ? 'Mata Pelajaran & Pembuat Soal:' : 'Subject & Question Author:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              
              // List subjects and authors
              ...roomSessions.map((session) {
                final subjectName = session['subjectName'] as String;
                final classes = session['classes'] as List<String>;
                final subId = session['subjectId'] as String;
                
                final config = _subjectConfigs.firstWhere(
                  (c) => c.subjectId == subId,
                  orElse: () => const ExamSubjectConfig(
                    subjectId: '',
                    subjectName: '',
                    classIds: [],
                    authorTeacherIds: [],
                    authorTeacherNames: [],
                  ),
                );
                
                final authorText = config.authorTeacherNames.isNotEmpty
                    ? config.authorTeacherNames.join(', ')
                    : (AppLocalization.isIndonesian ? 'Tidak ditentukan' : 'Not specified');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${classes.join(', ')} : $subjectName',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalization.isIndonesian
                            ? 'Pembuat Soal: $authorText'
                            : 'Question Author: $authorText',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printSchedule() async {
    final doc = pw.Document();
    
    // Group draft sessions by date
    final Map<String, List<Map<String, dynamic>>> sessionsByDay = {};
    for (final session in _draftSessions) {
      final dayStr = DateFormat('yyyy-MM-dd').format(session['date'] as DateTime);
      sessionsByDay.putIfAbsent(dayStr, () => []).add(session);
    }

    final sortedDays = sessionsByDay.keys.toList()..sort();

    for (final dayStr in sortedDays) {
      final daySessions = sessionsByDay[dayStr]!;
      final parsedDate = DateTime.parse(dayStr);
      final dayLabel = DateFormat('EEEE, dd MMMM yyyy', 'id').format(parsedDate);

      // Group sessions by slotName for this day
      final Map<String, List<Map<String, dynamic>>> sessionsBySlot = {};
      for (final s in daySessions) {
        final slotName = s['slotName'] as String;
        sessionsBySlot.putIfAbsent(slotName, () => []).add(s);
      }
      final sortedSlots = sessionsBySlot.keys.toList()..sort();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header / Title
                pw.Center(
                  child: pw.Text(
                    _titleController.text.isNotEmpty ? _titleController.text : (AppLocalization.isIndonesian ? 'Jadwal Ujian' : 'Exam Schedule'),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    dayLabel,
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 16),

                // Table representation
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(80),  // Sesi
                    1: pw.FixedColumnWidth(60),  // Ruangan
                    2: pw.FlexColumnWidth(2),    // Mata Pelajaran
                    3: pw.FlexColumnWidth(1.5),  // Pengawas
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              AppLocalization.isIndonesian ? 'Sesi / Waktu' : 'Session / Time',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              AppLocalization.isIndonesian ? 'Ruangan' : 'Room',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              AppLocalization.isIndonesian ? 'Mata Pelajaran (Kelas)' : 'Subject (Class)',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              AppLocalization.isIndonesian ? 'Pengawas' : 'Proctor',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        ),
                      ],
                    ),

                    // Table rows
                    ...sortedSlots.expand((slotName) {
                      final slotSessions = sessionsBySlot[slotName]!
                        ..sort((a, b) => (a['roomName'] as String).compareTo(b['roomName'] as String));
                      
                      final sampleSession = slotSessions.first;
                      final timeRange = '${sampleSession['startTime']} - ${sampleSession['endTime']}';

                      // Group slotSessions by roomName
                      final Map<String, List<Map<String, dynamic>>> roomSessionsMap = {};
                      for (final s in slotSessions) {
                        final rName = s['roomName'] as String;
                        roomSessionsMap.putIfAbsent(rName, () => []).add(s);
                      }

                      final sortedRooms = roomSessionsMap.keys.toList()..sort();

                      return sortedRooms.map((roomName) {
                        final roomSessions = roomSessionsMap[roomName]!;
                        final sampleRoomSession = roomSessions.first;
                        
                        final subjectsText = roomSessions
                            .map((s) => "${(s['classes'] as List<String>).join(', ')} : ${s['subjectName']}")
                            .join(', ');
                        
                        final rawProctorName = sampleRoomSession['proctorName'] as String? ?? 'Belum ditugaskan';
                        final proctorName = (rawProctorName.isEmpty || rawProctorName == 'Belum ditugaskan' || rawProctorName == 'Not assigned')
                            ? (AppLocalization.isIndonesian ? 'Belum ditugaskan' : 'Not assigned')
                            : rawProctorName;

                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                  '${slotName.replaceAll('Sesi', AppLocalization.isIndonesian ? 'Sesi' : 'Session')}\n($timeRange)',
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(roomName, style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(subjectsText, style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(proctorName, style: const pw.TextStyle(fontSize: 8)),
                            ),
                          ],
                        );
                      });
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    // Print / share PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${_titleController.text.trim().replaceAll(' ', '_')}_Jadwal_Ujian.pdf',
    );
  }

  Widget _buildStep7(bool isDark, Color cardColor, Color cardBorder, Color titleColor) {
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    // Auto-compile if sessions empty but schedule exists
    if (_draftSessions.isEmpty && _scheduledSubjects.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _compileDraftSessions());
    }

    // Group draft sessions by date
    final Map<String, List<Map<String, dynamic>>> sessionsByDay = {};
    for (final session in _draftSessions) {
      final dayStr = DateFormat('yyyy-MM-dd').format(session['date'] as DateTime);
      sessionsByDay.putIfAbsent(dayStr, () => []).add(session);
    }

    // Group each day's sessions by slotName for table structure
    final Color headerBg = isDark
        ? const Color(0xFF1E1B4B)
        : const Color(0xFF6366F1).withValues(alpha: 0.07);
    final Color headerText = isDark ? Colors.white70 : const Color(0xFF6366F1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.isIndonesian ? 'Jadwal Ujian Final' : 'Final Exam Schedule',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppLocalization.isIndonesian
                          ? 'Tampilan lengkap jadwal ujian per hari yang siap diterbitkan.'
                          : 'Full list of exam schedules per day ready for publication.',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Summary chip and Print button
              if (_draftSessions.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: _printSchedule,
                  icon: const Icon(Icons.print_rounded, size: 14, color: Color(0xFF6366F1)),
                  label: Text(
                    AppLocalization.isIndonesian ? 'Cetak & Unduh' : 'Print & Download',
                    style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Builder(builder: (context) {
                    final sessionPlural = _draftSessions.length > 1 ? 's' : '';
                    final dayPlural = sessionsByDay.length > 1 ? 's' : '';
                    return Text(
                      AppLocalization.isIndonesian
                          ? '${_draftSessions.length} Sesi • ${sessionsByDay.length} Hari'
                          : '${_draftSessions.length} Session$sessionPlural • ${sessionsByDay.length} Day$dayPlural',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          if (_draftSessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 48, color: subtitleColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalization.isIndonesian ? 'Jadwal belum tersusun.' : 'Schedule not generated yet.',
                      style: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalization.isIndonesian
                          ? 'Kembali ke step sebelumnya dan atur jadwal mapel.'
                          : 'Go back to the previous step and set subject schedules.',
                      style: TextStyle(color: subtitleColor.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sessionsByDay.entries.map((entry) {
              final dayStr = entry.key;
              final daySessions = entry.value;
              final parsedDate = DateTime.parse(dayStr);
              final dayLabel = DateFormat('EEEE, dd MMMM yyyy', AppLocalization.isIndonesian ? 'id' : 'en').format(parsedDate);

              // Collect all unique slots for this day (sorted)
              final slots = daySessions
                  .map((s) => s['slotName'] as String)
                  .toSet()
                  .toList()
                ..sort();

              return LayoutBuilder(
                builder: (context, constraints) {
                  const double minWidth = 550;
                  final double tableWidth = constraints.maxWidth > minWidth ? constraints.maxWidth : minWidth;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                                      : [const Color(0xFF6366F1).withValues(alpha: 0.1), const Color(0xFF8B5CF6).withValues(alpha: 0.05)],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.today_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF6366F1)),
                                  const SizedBox(width: 8),
                                  Text(
                                    dayLabel,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      AppLocalization.isIndonesian
                                          ? '${daySessions.length} sesi'
                                          : '${daySessions.length} session${daySessions.length > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : const Color(0xFF6366F1),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table header row
                            Container(
                              color: headerBg,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                        AppLocalization.isIndonesian ? 'Sesi / Waktu' : 'Session / Time',
                                        style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                        AppLocalization.isIndonesian ? 'Ruangan' : 'Room',
                                        style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        AppLocalization.isIndonesian ? 'Mata Pelajaran' : 'Subject',
                                        style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        AppLocalization.isIndonesian ? 'Pengawas' : 'Proctor',
                                        style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),

                            // Data rows grouped by slot
                            ...slots.expand((slotName) {
                              final slotSessions = daySessions.where((s) => s['slotName'] == slotName).toList()
                                ..sort((a, b) => (a['roomName'] as String).compareTo(b['roomName'] as String));

                              final sampleSession = slotSessions.first;

                              // Group slotSessions by roomName to render 1 row per room in this slot
                              final Map<String, List<Map<String, dynamic>>> roomSessionsMap = {};
                              for (final s in slotSessions) {
                                final rName = s['roomName'] as String;
                                roomSessionsMap.putIfAbsent(rName, () => []).add(s);
                              }

                              return [
                                // Slot separator band
                                Container(
                                  color: isDark
                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.06)
                                      : const Color(0xFF8B5CF6).withValues(alpha: 0.04),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        slotName.replaceAll('Sesi', AppLocalization.isIndonesian ? 'Sesi' : 'Session'),
                                        style: const TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${sampleSession['startTime']} – ${sampleSession['endTime']})',
                                        style: TextStyle(
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // One row per room in this slot
                                ...roomSessionsMap.entries.map((roomEntry) {
                                  final roomName = roomEntry.key;
                                  final roomSessions = roomEntry.value;
                                  final sampleRoomSession = roomSessions.first;

                                  final subjectsText = roomSessions
                                      .map((s) => "${(s['classes'] as List<String>).join(', ')} : ${s['subjectName']}")
                                      .join(', ');

                                  final rawProctorName = sampleRoomSession['proctorName'] as String? ?? 'Belum ditugaskan';
                                  final proctorName = (rawProctorName.isEmpty || rawProctorName == 'Belum ditugaskan' || rawProctorName == 'Not assigned')
                                      ? (AppLocalization.isIndonesian ? 'Belum ditugaskan' : 'Not assigned')
                                      : rawProctorName;
                                  final proctorId = sampleRoomSession['proctorId'] as String? ?? '';
                                  final hasProctor = proctorId.isNotEmpty;

                                  return InkWell(
                                    onTap: () => _showSessionDetailDialog(
                                      roomName,
                                      roomSessions,
                                      dayLabel,
                                      slotName,
                                      '${sampleSession['startTime']} – ${sampleSession['endTime']}',
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: cardBorder, width: 0.5),
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Slot/Time placeholder (empty since shown in band above)
                                          const SizedBox(width: 90),
                                          // Room
                                          SizedBox(
                                            width: 70,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                roomName,
                                                style: const TextStyle(
                                                  color: Color(0xFF6366F1),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Subject
                                          Expanded(
                                            child: Text(
                                              subjectsText,
                                              style: TextStyle(
                                                color: titleColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Proctor
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  hasProctor ? Icons.person_rounded : Icons.person_off_outlined,
                                                  size: 13,
                                                  color: hasProctor ? const Color(0xFF10B981) : Colors.redAccent,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    proctorName,
                                                    style: TextStyle(
                                                      color: hasProctor ? titleColor : Colors.redAccent,
                                                      fontSize: 10,
                                                      fontStyle: hasProctor ? FontStyle.normal : FontStyle.italic,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ];
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }

  List<DateTime> _getEventDays() {
    if (_startDate == null || _endDate == null) return [];
    final List<DateTime> days = [];
    DateTime current = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
    final last = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);

    // Map weekday number → Indonesian day name (lowercase)
    const dayNames = {
      1: 'senin',
      2: 'selasa',
      3: 'rabu',
      4: 'kamis',
      5: 'jumat',
      6: 'sabtu',
      7: 'minggu',
    };

    while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
      final dayName = dayNames[current.weekday] ?? '';
      // If school has KBM day data: only include days with KBM
      // If no data loaded yet: include all (fallback = Senin–Jumat weekdays only)
      final bool isActiveDay = _activeStudyDays.isNotEmpty
          ? _activeStudyDays.contains(dayName)
          : current.weekday <= 5; // Mon-Fri fallback
      if (isActiveDay) {
        days.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  Widget _buildScheduleSection(
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
  ) {
    final days = _getEventDays();
    if (days.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalization.isIndonesian
                    ? 'Rentang tanggal belum ditentukan di Step 1. Silakan tentukan tanggal ujian untuk menyusun jadwal.'
                    : 'Date range not defined in Step 1. Please specify exam dates to arrange the schedule.',
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        ...days.map((day) {
          final dayStr = DateFormat('yyyy-MM-dd').format(day);
          final dayLabel = DateFormat('EEEE, dd MMMM yyyy', AppLocalization.isIndonesian ? 'id' : 'en').format(day);

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day/Date Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Sessions/Slots List
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _slots.map((slot) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Session Name and Time
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  slot.name.replaceAll('Sesi', AppLocalization.isIndonesian ? 'Sesi' : 'Session'),
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${slot.startTime} - ${slot.endTime}',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            
                            // Rooms List inside this session
                            ..._rooms.map((room) {
                              // Extract class names configured for this room in Step 5 (e.g. from "X IPA 1:12" -> "X IPA 1")
                              final List<String> roomClassNames = room.classes.map((c) => c.split(':')[0]).toList();
                              
                              if (roomClassNames.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Room name
                                    Row(
                                      children: [
                                        const Icon(Icons.meeting_room_rounded, size: 14, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 6),
                                        Text(
                                          room.name,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    // Classes in this room
                                    ...roomClassNames.map((clsName) {
                                      final scheduleKey = '${dayStr}_${slot.name}_${room.name}_$clsName';
                                      final selectedSubjectId = _scheduledSubjects[scheduleKey];
                                      
                                      // Get subjects that are available for this class
                                      // A subject config contains class IDs it belongs to.
                                      // We filter `_subjectConfigs` to only show subjects that this class is participant of.
                                      final classObj = _allClasses.firstWhere((c) => c['name'] == clsName, orElse: () => {});
                                      final classId = classObj['id'] ?? '';
                                      
                                      final classSubjects = _subjectConfigs.where((sub) {
                                        return sub.classIds.contains(classId);
                                      }).toList();

                                      // Filter out subjects that are already scheduled in other slots/days globally
                                      final currentSlotPrefix = '${dayStr}_${slot.name}_';
                                      final scheduledInOtherSlots = _scheduledSubjects.entries
                                          .where((e) => !e.key.startsWith(currentSlotPrefix))
                                          .map((e) => e.value)
                                          .toSet();

                                      final availableSubjects = classSubjects.where((sub) {
                                        return !scheduledInOtherSlots.contains(sub.subjectId);
                                      }).toList();

// Safety check: ensure selected value is in the items list to prevent crash
                                       if (selectedSubjectId != null && !availableSubjects.any((sub) => sub.subjectId == selectedSubjectId)) {
                                         final matched = _subjectConfigs.firstWhere(
                                           (sub) => sub.subjectId == selectedSubjectId,
                                           orElse: () => ExamSubjectConfig(
                                             subjectId: selectedSubjectId,
                                             subjectName: AppLocalization.isIndonesian ? 'Loading mapel...' : 'Loading subject...',
                                             classIds: [],
                                             authorTeacherIds: [],
                                             authorTeacherNames: [],
                                           ),
                                         );
                                         availableSubjects.add(matched);
                                       }
                                      
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                clsName,
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.02),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: selectedSubjectId != null
                                                        ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                                                        : cardBorder,
                                                  ),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value: selectedSubjectId,
                                                    hint: Text(
                                                      AppLocalization.isIndonesian ? 'Pilih Mata Pelajaran' : 'Select Subject',
                                                      style: TextStyle(
                                                        color: subtitleColor,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                    dropdownColor: isDark ? const Color(0xFF1E1C38) : Colors.white,
                                                    isExpanded: true,
                                                    style: TextStyle(
                                                      color: titleColor,
                                                      fontSize: 11,
                                                      fontWeight: selectedSubjectId != null ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                    items: [
                                                      DropdownMenuItem<String>(
                                                        value: null,
                                                        child: Text(
                                                          AppLocalization.isIndonesian
                                                              ? 'Kosong / Tidak ada ujian'
                                                              : 'Empty / No exam',
                                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                                        ),
                                                      ),
                                                      ...availableSubjects.map((sub) {
                                                        return DropdownMenuItem<String>(
                                                          value: sub.subjectId,
                                                          child: Text(sub.subjectName, style: const TextStyle(fontSize: 11)),
                                                        );
                                                      }),
                                                    ],
                                                    onChanged: (val) {
                                                      setState(() {
                                                        // Update for this class name in ALL rooms for this specific day and slot
                                                        for (final r in _rooms) {
                                                          final rClasses = r.classes.map((c) => c.split(':')[0]).toList();
                                                          if (rClasses.contains(clsName)) {
                                                            final targetKey = '${dayStr}_${slot.name}_${r.name}_$clsName';
                                                            if (val == null) {
                                                              _scheduledSubjects.remove(targetKey);
                                                            } else {
                                                              _scheduledSubjects[targetKey] = val;
                                                            }
                                                          }
                                                        }
                                                      });
                                                      _saveDraft();
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  bool hasConflict(Map<String, dynamic> currentSession) {
    final pId = currentSession['proctorId'] as String;
    if (pId.isEmpty) return false;
    
    final date = currentSession['date'] as DateTime;
    final slotName = currentSession['slotName'] as String;
    final roomName = currentSession['roomName'] as String;
    
    return _draftSessions.any((s) =>
        s['proctorId'] == pId &&
        s['date'] == date &&
        s['slotName'] == slotName &&
        s['roomName'] != roomName);
  }

  bool exceedsDailyLimit(Map<String, dynamic> currentSession) {
    final pId = currentSession['proctorId'] as String;
    if (pId.isEmpty) return false;
    
    final date = currentSession['date'] as DateTime;
    
    final dailyCount = _draftSessions.where((s) =>
        s['proctorId'] == pId &&
        s['date'] == date).length;
        
    return dailyCount > 2;
  }

  void _clearProctors() {
    setState(() {
      for (final session in _draftSessions) {
        session['proctorId'] = '';
        session['proctorName'] = '';
      }
    });
    _saveDraft();
    Get.snackbar(
      'Sukses',
      'Distribusi pengawas berhasil dikosongkan.',
      backgroundColor: const Color(0xFFEF4444),
      colorText: Colors.white,
    );
  }

  void _autoAssignProctors() {
    if (_allTeachers.isEmpty) {
      _showError(AppLocalization.isIndonesian
          ? 'Tidak ada data guru untuk ditugaskan sebagai pengawas.'
          : 'No teacher data available to assign as proctors.');
      return;
    }

    // Compile sessions first if not yet done
    if (_draftSessions.isEmpty) {
      if (_scheduledSubjects.isEmpty) {
        _showError(AppLocalization.isIndonesian
            ? 'Jadwal mata pelajaran belum dikonfigurasi di Step sebelumnya.'
            : 'Subject schedule has not been configured in the previous step.');
        return;
      }
      _compileDraftSessions();
      // Re-run after compile in next frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoAssignProctors());
      return;
    }

    setState(() {
      // ★ Gunakan Random.secure() untuk pengacakan sejati
      final rng = Random.secure();

      // Group draft sessions by date
      final Map<String, List<Map<String, dynamic>>> sessionsByDay = {};
      for (final session in _draftSessions) {
        final dayStr = DateFormat('yyyy-MM-dd').format(session['date'] as DateTime);
        sessionsByDay.putIfAbsent(dayStr, () => []).add(session);
      }

      // Assign for each day
      sessionsByDay.forEach((dayStr, daySessions) {
        // Track daily proctor usage count
        final Map<String, int> dailyProctorCounts = {};
        for (final t in _allTeachers) {
          dailyProctorCounts[t['id'] as String] = 0;
        }

        // ★ Buat pool guru yang sudah di-shuffle untuk hari ini
        //   (dikocok ulang setiap hari agar distribusi antar hari berbeda)
        final dailyTeacherPool = List<Map<String, dynamic>>.from(_allTeachers)..shuffle(rng);

        // Group daySessions by slot
        final Map<String, List<Map<String, dynamic>>> sessionsBySlot = {};
        for (final s in daySessions) {
          final slotName = s['slotName'] as String;
          sessionsBySlot.putIfAbsent(slotName, () => []).add(s);
        }

        // Assign slot by slot
        sessionsBySlot.forEach((slotName, slotSessions) {
          final Set<String> assignedInThisSlot = {};

          // Group slotSessions by roomName to distribute exactly 1 proctor per room
          final Map<String, List<Map<String, dynamic>>> sessionsByRoom = {};
          for (final s in slotSessions) {
            final rName = s['roomName'] as String;
            sessionsByRoom.putIfAbsent(rName, () => []).add(s);
          }

          // Shuffle rooms to distribute randomly
          final roomNames = sessionsByRoom.keys.toList()..shuffle(rng);

          for (final rName in roomNames) {
            final roomSessions = sessionsByRoom[rName]!;
            String? chosenId;
            String chosenName = 'Belum ditugaskan';

            final candidates = List<Map<String, dynamic>>.from(dailyTeacherPool);
            candidates.sort((a, b) {
              final countA = dailyProctorCounts[a['id']] ?? 0;
              final countB = dailyProctorCounts[b['id']] ?? 0;
              return countA.compareTo(countB);
            });

            for (final teacher in candidates) {
              final tId = teacher['id'] as String;
              final dailyCount = dailyProctorCounts[tId] ?? 0;

              // Constraints:
              // 1. Not already assigned in this slot
              // 2. Daily count < 2
              if (!assignedInThisSlot.contains(tId) && dailyCount < 2) {
                chosenId = tId;
                chosenName = teacher['nama'] as String;
                break;
              }
            }

            // Assign this chosen proctor to all sessions in this room for this slot
            for (final s in roomSessions) {
              if (chosenId != null) {
                s['proctorId'] = chosenId;
                s['proctorName'] = chosenName;
              } else {
                s['proctorId'] = '';
                s['proctorName'] = 'Belum ditugaskan';
              }
            }

            if (chosenId != null) {
              assignedInThisSlot.add(chosenId);
              dailyProctorCounts[chosenId] = (dailyProctorCounts[chosenId] ?? 0) + 1;
            }
          }
        });
      });
    });

    _saveDraft();

    Get.snackbar(
      'Sukses',
      'Pengawas berhasil didistribusikan secara otomatis sesuai ketentuan.',
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
    );
  }

  List<Map<String, dynamic>> _draftSessions = [];

  void _compileDraftSessions() {
    final assignments = _calculateRoomAssignments();
    final List<Map<String, dynamic>> compiled = [];

    final days = _getEventDays();
    if (days.isEmpty) return;

    for (final day in days) {
      final dayStr = DateFormat('yyyy-MM-dd').format(day);
      for (final slot in _slots) {
        for (int i = 0; i < _rooms.length; i++) {
          final room = _rooms[i];
          final roomStudents = assignments[i] ?? [];

          // Group room students by subject scheduled for their class in this slot
          final Map<String, List<Map<String, dynamic>>> studentsBySubject = {};

          for (final student in roomStudents) {
            final clsName = student['className'] as String? ?? '';
            final scheduleKey = '${dayStr}_${slot.name}_${room.name}_$clsName';
            final subjectId = _scheduledSubjects[scheduleKey];
            if (subjectId != null && subjectId.isNotEmpty) {
              studentsBySubject.putIfAbsent(subjectId, () => []).add(student);
            }
          }

          // Compile a session for each scheduled subject in this room
          studentsBySubject.forEach((subjectId, sessionStudents) {
            final configMatches = _subjectConfigs.where((c) => c.subjectId == subjectId).toList();
            if (configMatches.isEmpty) return;
            final config = configMatches.first;

            final sessionClasses = sessionStudents.map((s) => s['className'] as String).toSet().toList()..sort();

            // Check if this session already exists in _draftSessions (to preserve proctor).
            // Use date string comparison to avoid DateTime microsecond mismatch.
            final existing = _draftSessions.cast<Map<String, dynamic>?>().firstWhere(
              (s) => s != null &&
                  DateFormat('yyyy-MM-dd').format(s['date'] as DateTime) == dayStr &&
                  s['slotName'] == slot.name &&
                  s['roomName'] == room.name &&
                  s['subjectId'] == config.subjectId,
              orElse: () => null,
            );

            compiled.add({
              'date': day,
              'slotName': slot.name,
              'startTime': slot.startTime,
              'endTime': slot.endTime,
              'roomName': room.name,
              'subjectId': config.subjectId,
              'subjectName': config.subjectName,
              'classes': sessionClasses,
              'proctorId': existing != null ? existing['proctorId'] ?? '' : '',
              'proctorName': existing != null ? existing['proctorName'] ?? 'Belum ditugaskan' : 'Belum ditugaskan',
              'students': sessionStudents,
            });
          });
        }
      }
    }

    // Sort compiled draft sessions by date, then slot, then room
    compiled.sort((a, b) {
      final dateCompare = (a['date'] as DateTime).compareTo(b['date'] as DateTime);
      if (dateCompare != 0) return dateCompare;
      final slotCompare = (a['slotName'] as String).compareTo(b['slotName'] as String);
      if (slotCompare != 0) return slotCompare;
      return (a['roomName'] as String).compareTo(b['roomName'] as String);
    });

    setState(() {
      _draftSessions = compiled;
    });
  }

  Map<int, List<Map<String, dynamic>>> _calculateRoomAssignments() {
    final Map<int, List<Map<String, dynamic>>> assignments = {};
    final Set<String> assignedStudentIds = {};

    for (int index = 0; index < _rooms.length; index++) {
      final room = _rooms[index];
      final List<String> roomClassNames = room.classes.map((c) => c.split(':')[0]).toList();

      // For each class, retrieve its unassigned students
      final Map<String, List<Map<String, dynamic>>> classStudents = {};
      for (final rawCls in room.classes) {
        final parts = rawCls.split(':');
        final clsName = parts[0];

        final cls = _allClasses.firstWhere(
          (c) => c['name'] == clsName,
          orElse: () => <String, dynamic>{},
        );
        final cid = cls['id'];
        if (cid != null) {
          final students = _studentsByClass[cid] ?? [];
          final List<Map<String, dynamic>> unassigned = [];
          for (final s in students) {
            if (!assignedStudentIds.contains(s['id'])) {
              unassigned.add({
                ...s,
                'className': clsName,
                'classId': cid,
              });
            }
          }
          
          if (_isRandom) {
            unassigned.shuffle();
          } else {
            unassigned.sort((a, b) => (a['nama'] as String).compareTo(b['nama'] as String));
          }

          // Get the target count configured for this class in this room
          int targetCount = unassigned.length;
          if (parts.length > 1) {
            targetCount = int.tryParse(parts[1]) ?? unassigned.length;
          }

          // Limit to the target count
          if (targetCount < unassigned.length) {
            classStudents[clsName] = unassigned.sublist(0, targetCount);
          } else {
            classStudents[clsName] = unassigned;
          }
        }
      }

      // Filter to keep only classes that actually have remaining students to place
      final List<String> activeClasses = roomClassNames.where((clsName) => classStudents[clsName]?.isNotEmpty ?? false).toList();
      final List<Map<String, dynamic>> interleaved = [];
      int seatNumber = 1;

      if (_isZigzag) {
        // Group active classes by cohort/angkatan
        final Map<String, List<String>> cohortToClassesMap = {};
        for (final clsName in activeClasses) {
          final clsObj = _allClasses.firstWhere((c) => c['name'] == clsName, orElse: () => {});
          final classId = clsObj['id'] ?? '';
          final students = _studentsByClass[classId] ?? [];
          String cohort = '';
          if (students.isNotEmpty) {
            final counts = <String, int>{};
            for (final s in students) {
              final a = s['angkatan'] as String;
              counts[a] = (counts[a] ?? 0) + 1;
            }
            cohort = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
          }
          if (cohort.isEmpty) {
            if (clsName.contains('XII') || clsName.contains('12')) {
              cohort = '2022';
            } else if (clsName.contains('XI') || clsName.contains('11')) {
              cohort = '2023';
            } else {
              cohort = '2024';
            }
          }
          cohortToClassesMap.putIfAbsent(cohort, () => []).add(clsName);
        }

        // Sort class names alphabetically inside each cohort to be deterministic
        cohortToClassesMap.forEach((cohort, list) => list.sort());

        // Interleave classes from different cohorts
        final List<String> sortedCohorts = cohortToClassesMap.keys.toList()..sort();
        final List<String> orderedActiveClasses = [];
        if (sortedCohorts.isNotEmpty) {
          int maxLen = cohortToClassesMap.values.map((l) => l.length).reduce((a, b) => a > b ? a : b);
          for (int step = 0; step < maxLen; step++) {
            for (final cohort in sortedCohorts) {
              final list = cohortToClassesMap[cohort]!;
              if (step < list.length) {
                orderedActiveClasses.add(list[step]);
              }
            }
          }
        }

        final Map<String, int> classIndices = { for (var c in orderedActiveClasses) c : 0 };
        int classPointer = 0;

        while (seatNumber <= room.capacity && orderedActiveClasses.isNotEmpty) {
          final clsName = orderedActiveClasses[classPointer];
          final students = classStudents[clsName]!;
          final idx = classIndices[clsName]!;

          if (idx < students.length) {
            final student = students[idx];
            final copy = Map<String, dynamic>.from(student);
            copy['seatNumber'] = seatNumber;
            interleaved.add(copy);
            assignedStudentIds.add(student['id'] as String);

            classIndices[clsName] = idx + 1;
            seatNumber++;

            // Move pointer to the next active class
            if (orderedActiveClasses.isNotEmpty) {
              classPointer = (classPointer + 1) % orderedActiveClasses.length;
            }
          } else {
            // This class is exhausted, remove it from round-robin rotation
            orderedActiveClasses.removeAt(classPointer);
            if (orderedActiveClasses.isNotEmpty) {
              classPointer = classPointer % orderedActiveClasses.length;
            }
          }
        }
      } else {
        // Sequential allocation (not zigzag)
        for (final clsName in roomClassNames) {
          final students = classStudents[clsName] ?? [];
          for (final student in students) {
            if (seatNumber > room.capacity) break;
            final copy = Map<String, dynamic>.from(student);
            copy['seatNumber'] = seatNumber;
            interleaved.add(copy);
            assignedStudentIds.add(student['id'] as String);
            seatNumber++;
          }
          if (seatNumber > room.capacity) break;
        }
      }

      assignments[index] = interleaved;
    }
    return assignments;
  }

  Map<String, int> _getClassUnassignedCounts(Map<int, List<Map<String, dynamic>>> assignments) {
    final Set<String> assignedIds = {};
    assignments.values.forEach((list) {
      for (final s in list) {
        assignedIds.add(s['id'] as String);
      }
    });

    final Map<String, int> remainingCounts = {};
    for (final cls in _allClasses) {
      final className = cls['name'] ?? '';
      final classId = cls['id'] ?? '';
      final students = _studentsByClass[classId] ?? [];
      
      int remaining = 0;
      for (final s in students) {
        if (!assignedIds.contains(s['id'])) {
          remaining++;
        }
      }
      remainingCounts[className] = remaining;
    }
    return remainingCounts;
  }
}

