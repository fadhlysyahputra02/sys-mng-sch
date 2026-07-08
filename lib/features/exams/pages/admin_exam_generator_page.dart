import 'dart:convert';
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
import 'admin_exam_schedule_view_page.dart';

// ─────────────────────────────────────────────────────────────
//  AdminExamGeneratorPage — Form multi-step konfigurasi UTS/UAS
//  Step 1: Info dasar (nama, tipe, rentang tanggal)
//  Step 2: Konfigurasi slot waktu harian
//  Step 3: Pilih mapel + kelas + author soal
//  Step 4: Preview & Generate jadwal
// ─────────────────────────────────────────────────────────────
class AdminExamGeneratorPage extends StatefulWidget {
  final bool restoreFromFirestore;
  const AdminExamGeneratorPage({super.key, this.restoreFromFirestore = false});

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
      
      await prefs.setBool('exam_draft_exists', true);

      // Firestore sync
      final schoolId = SessionService.currentUser?.schoolId;
      if (schoolId != null) {
        final db = FirebaseFirestore.instance;
        await db.collection('schools').doc(schoolId).collection('exam_drafts').doc('current').set({
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

      setState(() {
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
              title: Text('Draf Ditemukan', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
              content: Text(
                'Ada draf pembuatan ujian yang belum selesai. Apakah Anda ingin melanjutkan draf tersebut?',
                style: TextStyle(color: titleColor.withValues(alpha: 0.7)),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _clearDraft();
                  },
                  child: const Text('Mulai Baru', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
                  child: const Text('Lanjutkan'),
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

  @override
  void initState() {
    super.initState();
    _loadSchoolData();
    _titleController.addListener(_onTitleChanged);
    if (widget.restoreFromFirestore) {
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
          if (cid.isNotEmpty) {
            _studentsByClass.putIfAbsent(cid, () => []).add({
              'id': doc.id,
              'nama': data['nama'] ?? '',
              'nis': data['nis'] ?? '',
              'angkatan': (data['angkatan'] ?? '').toString().trim(),
            });
          }
        }

        _isLoadingData = false;
      });
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < 6) {
      if (_currentStep == 4) {
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
          _showError('Nama event ujian tidak boleh kosong');
          return false;
        }
        if (_startDate == null || _endDate == null) {
          _showError('Pilih rentang tanggal ujian');
          return false;
        }
        if (_endDate!.isBefore(_startDate!)) {
          _showError('Tanggal akhir harus setelah tanggal mulai');
          return false;
        }
        return true;
      case 1:
        if (_slots.isEmpty) {
          _showError('Tambahkan minimal satu slot waktu');
          return false;
        }
        return true;
      case 2:
        if (_subjectConfigs.isEmpty) {
          _showError('Tambahkan minimal satu mata pelajaran');
          return false;
        }
        for (final config in _subjectConfigs) {
          if (config.authorTeacherIds.isEmpty) {
            _showError(
                'Pilih pembuat soal untuk "${config.subjectName}"');
            return false;
          }
          if (config.classIds.isEmpty) {
            _showError(
                'Pilih kelas untuk "${config.subjectName}"');
            return false;
          }
        }
        return true;
      case 3:
        if (_rooms.isEmpty) {
          _showError('Tambahkan minimal satu ruangan ujian');
          return false;
        }
        for (final room in _rooms) {
          if (room.name.trim().isEmpty) {
            _showError('Nama ruangan tidak boleh kosong');
            return false;
          }
          if (room.capacity <= 0) {
            _showError('Kapasitas ruangan "${room.name}" harus lebih dari 0');
            return false;
          }
        }
        return true;
      case 4:
        final scheduledSubjectIds = _scheduledSubjects.values.toSet();
        final unscheduledSubjects = _subjectConfigs.where((s) => !scheduledSubjectIds.contains(s.subjectId)).toList();
        if (unscheduledSubjects.isNotEmpty) {
          _showError('Terdapat ${unscheduledSubjects.length} mata pelajaran yang belum dijadwalkan: '
              '${unscheduledSubjects.map((s) => s.subjectName).join(', ')}');
          return false;
        }
        return true;
      case 5:
        final unassignedCount = _draftSessions.where((s) => (s['proctorId'] as String).isEmpty).length;
        if (unassignedCount > 0) {
          _showError('Terdapat $unassignedCount sesi ujian yang belum memiliki pengawas.');
          return false;
        }
        for (final s in _draftSessions) {
          if (hasConflict(s)) {
            _showError('Terdapat bentrokan sesi pengawas (satu guru mengawas beberapa kelas di sesi yang sama).');
            return false;
          }
          if (exceedsDailyLimit(s)) {
            _showError('Terdapat guru yang ditugaskan mengawas melebihi batas 2 sesi dalam sehari.');
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
                                AppLocalization.isIndonesian ? 'Buat Jadwal Ujian Semester' : 'Create Semester Exam Schedule',
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
                          child: _currentStep < 6
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
                                  onPressed:
                                      _isGenerating ? null : _saveAndCreateEvent,
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
        ? ['Info Dasar', 'Slot Waktu', 'Mata Pelajaran', 'Ruang Ujian', 'Jadwal & Meja', 'Pengawas', 'Jadwal Final']
        : ['Basic Info', 'Time Slots', 'Subjects', 'Exam Rooms', 'Schedule & Seats', 'Proctors', 'Final Schedule'];
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
          Text('Slot Waktu Harian',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Tentukan sesi-sesi ujian per hari',
              style: TextStyle(color: subtitleColor, fontSize: 13)),
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
                        child: Text(slot.name,
                            style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
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
                          label: 'Mulai: ${slot.startTime}',
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
                          label: 'Selesai: ${slot.endTime}',
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
                  name: 'Sesi $nextNum',
                  startTime: '10:00',
                  endTime: '12:00',
                ));
              });
              _saveDraft();
            },
            icon: const Icon(Icons.add_circle_outline_rounded,
                color: Color(0xFF8B5CF6)),
            label: const Text('Tambah Sesi',
                style: TextStyle(color: Color(0xFF8B5CF6))),
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
          Text('Mata Pelajaran & Kelas',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Pilih mapel, kelas peserta, dan pembuat soal',
              style: TextStyle(color: subtitleColor, fontSize: 13)),
          const SizedBox(height: 20),

          ..._subjectConfigs.asMap().entries.map((entry) {
            final i = entry.key;
            final config = entry.value;
            return _buildSubjectConfigCard(
                i, config, isDark, cardColor, cardBorder, titleColor, subtitleColor);
          }),

          // Tombol tambah mapel
          OutlinedButton.icon(
            onPressed: () => _showAddSubjectDialog(
                isDark, cardColor, cardBorder, titleColor, subtitleColor),
            icon: const Icon(Icons.add_rounded, color: Color(0xFF8B5CF6)),
            label: const Text('Tambah Mata Pelajaran',
                style: TextStyle(color: Color(0xFF8B5CF6))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF8B5CF6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
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
        : 'Belum dipilih';
    final classNames = config.classIds
        .map((id) => _allClasses
            .firstWhere((c) => c['id'] == id,
                orElse: () => {'name': id})['name'] as String)
        .join(', ');

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
          _buildInfoRow(Icons.person_rounded, 'Pembuat Soal: $authorNames',
              subtitleColor),
          const SizedBox(height: 4),
          _buildInfoRow(
              Icons.class_rounded,
              config.classIds.isEmpty
                  ? 'Kelas: Belum dipilih'
                  : 'Kelas: $classNames',
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

        final List<Map<String, dynamic>> list = snap.docs.map((d) {
          final data = d.data();
          return {
            'id': data['teacherId']?.toString() ?? '',
            'nama': data['teacherName']?.toString() ?? '',
          };
        }).where((t) => t['id'].isNotEmpty && t['nama'].isNotEmpty).toList();

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
                  Text('Tambah Mata Pelajaran',
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Pilih Mapel
                  Text('Mata Pelajaran',
                      style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
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
                    hint: Text('Pilih Mata Pelajaran',
                        style: TextStyle(color: subtitleColor)),
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
                  Text('Guru Penguji / Pembuat Soal (Bisa Pilih > 1)',
                      style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (selectedSubjectId == null)
                    Text('Pilih mata pelajaran terlebih dahulu',
                        style: TextStyle(color: subtitleColor.withValues(alpha: 0.5), fontSize: 13))
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
                        return FilterChip(
                          label: Text(t['nama']),
                          selected: isSelected,
                          selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          checkmarkColor: const Color(0xFF8B5CF6),
                          labelStyle: TextStyle(
                            color: isSelected ? const Color(0xFF8B5CF6) : titleColor,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF8B5CF6) : cardBorder,
                            ),
                          ),
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                selectedAuthorIds.add(t['id'] as String);
                                selectedAuthorNames.add(t['nama'] as String);
                              } else {
                                selectedAuthorIds.remove(t['id']);
                                selectedAuthorNames.remove(t['nama']);
                              }
                            });
                          },
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
                        _showError('Pilih mata pelajaran');
                        return;
                      }
                      if (selectedAuthorIds.isEmpty) {
                        _showError('Pilih minimal satu guru pengoreksi');
                        return;
                      }
                      if (selectedClassIds.isEmpty) {
                        _showError('Pilih minimal satu kelas');
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
          Text('Konfigurasi Ruang Ujian',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Daftarkan ruangan yang akan digunakan beserta kapasitas kursinya',
              style: TextStyle(color: subtitleColor, fontSize: 13)),
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
                Text('Tambah Ruang Ujian',
                    style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _roomNameController,
                        decoration: InputDecoration(
                          hintText: 'Nama Ruang (e.g. Ruang 03)',
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
                          hintText: 'Kapasitas',
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
                      _showError('Nama ruangan tidak boleh kosong');
                      return;
                    }
                    if (capacity <= 0) {
                      _showError('Kapasitas ruangan harus lebih dari 0');
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
                  label: const Text('Tambah ke Daftar'),
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
          Text('Daftar Ruangan Terdaftar (${_rooms.length})',
              style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 10),
          if (_rooms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Belum ada ruangan terdaftar.',
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
                              'Kapasitas: ${room.capacity} Kursi',
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
          Text('Finalisasi & Simpan Event',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Pastikan seluruh konfigurasi dasar berikut sudah sesuai.',
              style: TextStyle(color: subtitleColor, fontSize: 13)),
          const SizedBox(height: 24),


          
          if (_rooms.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Daftar Ruang Ujian (${_rooms.length})',
                    style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _autoAssignClassesToRooms,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Atur Otomatis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final assignments = _calculateRoomAssignments();
                final remainingCounts = _getClassUnassignedCounts(assignments);

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rooms.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    final expandedSet = _expandedRooms ??= {};
                    final isExpanded = expandedSet.contains(room.name);

                    final isEven = index % 2 == 0;
                    final itemBgColor = isEven
                        ? (isDark ? const Color(0xFF1E1C38) : const Color(0xFFF5F3FF))
                        : (isDark ? const Color(0xFF1B1A30) : const Color(0xFFEEF2FF));
                    final itemBorderColor = isEven
                        ? (isDark ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : const Color(0xFF8B5CF6).withValues(alpha: 0.15))
                        : (isDark ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.15));

                    return Ink(
                      decoration: BoxDecoration(
                        color: itemBgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: itemBorderColor),
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
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.meeting_room_rounded,
                                          color: const Color(0xFF6366F1), size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        room.name,
                                        style: TextStyle(
                                          color: titleColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Kapasitas: ${room.capacity} Kursi',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black87,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (room.classes.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                                        ),
                                        child: Text(
                                          '${room.classes.length} Kelas',
                                          style: const TextStyle(
                                            color: Color(0xFF6366F1),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                  // Nomor Meja
                                  Row(
                                    children: [
                                      Icon(Icons.table_restaurant_rounded, size: 13, color: const Color(0xFF6366F1)),
                                      const SizedBox(width: 6),
                                      Text(
                              'Nomor Meja (${room.capacity} Meja)',
                                        style: TextStyle(
                                          color: titleColor.withValues(alpha: 0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: () {
                                      final interleaved = assignments[index] ?? [];
                                      return List.generate(room.capacity, (idx) {
                                        final num = idx + 1;
                                        final student = idx < interleaved.length ? interleaved[idx] : null;
                                        final hasStudent = student != null;
                                        final name = hasStudent ? student['nama'] ?? '' : 'Kosong';
                                        final angkatan = hasStudent ? student['angkatan'] ?? '' : '';
                                        final clsName = hasStudent ? student['className'] ?? '' : '';

                                        return Container(
                                          width: 105,
                                          height: 58,
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: hasStudent
                                                ? (isDark
                                                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                                                    : const Color(0xFF6366F1).withValues(alpha: 0.05))
                                                : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: hasStudent
                                                  ? (isDark
                                                      ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                                                      : const Color(0xFF6366F1).withValues(alpha: 0.18))
                                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                              width: 0.8,
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
                                                  if (hasStudent)
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
                                                  color: hasStudent
                                                      ? (isDark ? Colors.white : const Color(0xFF1E1B4B))
                                                      : (isDark ? Colors.white30 : Colors.black38),
                                                  fontSize: 9,
                                                  fontWeight: hasStudent ? FontWeight.bold : FontWeight.normal,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (hasStudent)
                                                Text(
                                                  '${room.name}-$num-$angkatan',
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white38 : Colors.black38,
                                                    fontSize: 6.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        );
                                      });
                                    }(),
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Pilih Kelas',
                                    style: TextStyle(
                                      color: titleColor.withValues(alpha: 0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_allClasses.isEmpty)
                                    Text(
                                      'Tidak ada data kelas.',
                                      style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _allClasses.map((cls) {
                                        final className = cls['name'] ?? '';
                                        final classId = cls['id'] ?? '';
                                        final totalInClass = _studentsByClass[classId]?.length ?? 0;
                                        final remaining = remainingCounts[className] ?? 0;
                                        final isSelected = room.classes.contains(className);
                                        final displayText = remaining == 0
                                            ? '$className (Penuh)'
                                            : '$className ($remaining/$totalInClass)';

                                        return GestureDetector(
                                          onTap: () {
                                            if (!isSelected && room.classes.length >= 3) {
                                              Get.snackbar(
                                                'Peringatan',
                                                'Maksimal 3 kelas dalam satu ruangan',
                                                backgroundColor: const Color(0xFFEF4444),
                                                colorText: Colors.white,
                                                snackPosition: SnackPosition.BOTTOM,
                                                margin: const EdgeInsets.all(16),
                                              );
                                              return;
                                            }
                                            setState(() {
                                              final updatedClasses = List<String>.from(room.classes);
                                              if (isSelected) {
                                                updatedClasses.remove(className);
                                              } else {
                                                updatedClasses.add(className);
                                              }
                                              _rooms[index] = room.copyWith(classes: updatedClasses);
                                            });
                                            _saveDraft();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF6366F1)
                                                  : const Color(0xFF6366F1).withValues(alpha: 0.04),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF6366F1)
                                                    : (isDark ? Colors.white24 : Colors.black12),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isSelected
                                                      ? Icons.check_circle_rounded
                                                      : Icons.radio_button_off_rounded,
                                                  color: isSelected ? Colors.white : subtitleColor,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  displayText,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : titleColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
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
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildScheduleSection(isDark, cardColor, cardBorder, titleColor, subtitleColor),
            ],
          const SizedBox(height: 24),


          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _autoAssignClassesToRooms() {
    if (_allClasses.isEmpty) return;

    // 1. Map classId to cohort and student count
    final Map<String, String> classToCohort = {};
    final Map<String, int> classStudentCount = {};
    final Map<String, String> classIdToName = {};
    
    for (final cls in _allClasses) {
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
    for (final cls in _allClasses) {
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
      final List<String> assignedClasses = [];

      // Find Cohort queues that still have students
      final activeCohorts = classesByCohort.keys.where((cohort) {
        return classesByCohort[cohort]!.any((cid) => remainingClassStudents[cid]! > 0);
      }).toList()..sort();

      if (activeCohorts.isEmpty) {
        // No more students to assign
        updatedRooms.add(room.copyWith(classes: []));
        continue;
      }

      // We want to select at most 2 classes to mix (ideally from different cohorts)
      String? classA;
      String? classB;

      if (activeCohorts.length >= 2) {
        // Mix two different cohorts
        final cohortA = activeCohorts[0];
        final cohortB = activeCohorts[1];

        classA = classesByCohort[cohortA]!.firstWhere((cid) => remainingClassStudents[cid]! > 0);
        classB = classesByCohort[cohortB]!.firstWhere((cid) => remainingClassStudents[cid]! > 0);
      } else {
        // Only one cohort has remaining students
        final cohort = activeCohorts[0];
        final candidates = classesByCohort[cohort]!.where((cid) => remainingClassStudents[cid]! > 0).toList();
        if (candidates.isNotEmpty) {
          classA = candidates[0];
        }
        if (candidates.length >= 2) {
          classB = candidates[1];
        }
      }

      // Now fill the room with students from classA and classB
      int filledA = 0;
      int filledB = 0;

      if (classA != null && classB != null) {
        // Both classes selected
        final nameA = classIdToName[classA]!;
        final nameB = classIdToName[classB]!;
        assignedClasses.add(nameA);
        assignedClasses.add(nameB);

        int targetA = (capacity / 2).ceil();
        int targetB = capacity - targetA;

        // Fill Class A
        final remA = remainingClassStudents[classA]!;
        if (remA >= targetA) {
          remainingClassStudents[classA] = remA - targetA;
          filledA = targetA;
        } else {
          remainingClassStudents[classA] = 0;
          filledA = remA;
        }

        // Fill Class B
        final remB = remainingClassStudents[classB]!;
        if (remB >= targetB) {
          remainingClassStudents[classB] = remB - targetB;
          filledB = targetB;
        } else {
          remainingClassStudents[classB] = 0;
          filledB = remB;
        }

        // If Class A or B had leftovers, fill the remainder
        int totalFilled = filledA + filledB;
        if (totalFilled < capacity) {
          int leftover = capacity - totalFilled;
          if (remainingClassStudents[classA]! > 0) {
            final rem = remainingClassStudents[classA]!;
            if (rem >= leftover) {
              remainingClassStudents[classA] = rem - leftover;
              filledA += leftover;
            } else {
              remainingClassStudents[classA] = 0;
              filledA += rem;
            }
          } else if (remainingClassStudents[classB]! > 0) {
            final rem = remainingClassStudents[classB]!;
            if (rem >= leftover) {
              remainingClassStudents[classB] = rem - leftover;
              filledB += leftover;
            } else {
              remainingClassStudents[classB] = 0;
              filledB += rem;
            }
          }
        }
      } else if (classA != null) {
        // Only classA selected
        final nameA = classIdToName[classA]!;
        assignedClasses.add(nameA);

        final remA = remainingClassStudents[classA]!;
        if (remA >= capacity) {
          remainingClassStudents[classA] = remA - capacity;
        } else {
          remainingClassStudents[classA] = 0;
        }
      }

      assignedClasses.sort();
      updatedRooms.add(room.copyWith(classes: assignedClasses));
    }

    setState(() {
      _rooms.clear();
      _rooms.addAll(updatedRooms);
    });
    _saveDraft();

    // Check for remaining unassigned students
    final List<String> unassignedDetails = [];
    int totalUnassigned = 0;
    remainingClassStudents.forEach((cid, count) {
      if (count > 0) {
        final cname = classIdToName[cid]!;
        totalUnassigned += count;
        unassignedDetails.add('$cname ($count siswa)');
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
      _showError('Jadwal/Nama Event tidak boleh kosong');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showError('Rentang tanggal belum dipilih');
      return;
    }
    if (_slots.isEmpty) {
      _showError('Slot waktu belum dikonfigurasi');
      return;
    }
    if (_rooms.isEmpty) {
      _showError('Ruangan belum dikonfigurasi');
      return;
    }

    // Check scheduled subjects
    final scheduledSubjectIds = _scheduledSubjects.values.toSet();
    final unscheduledSubjects = _subjectConfigs.where((s) => !scheduledSubjectIds.contains(s.subjectId)).toList();
    if (unscheduledSubjects.isNotEmpty) {
      _showError('Terdapat ${unscheduledSubjects.length} mata pelajaran yang belum dijadwalkan: '
          '${unscheduledSubjects.map((s) => s.subjectName).join(', ')}');
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

      _scheduledSubjects.forEach((scheduleKey, subjectId) {
        // scheduleKey format is "yyyy-MM-dd_slotName"
        final firstUnderscore = scheduleKey.indexOf('_');
        if (firstUnderscore == -1) return;
        final dayStr = scheduleKey.substring(0, firstUnderscore);
        final slotName = scheduleKey.substring(firstUnderscore + 1);

        final date = DateTime.tryParse(dayStr);
        if (date == null) return;

        final slotMatches = _slots.where((s) => s.name == slotName).toList();
        if (slotMatches.isEmpty) return;
        final slot = slotMatches.first;

        final configMatches = _subjectConfigs.where((c) => c.subjectId == subjectId).toList();
        if (configMatches.isEmpty) return;
        final config = configMatches.first;

        // For each room
        for (int i = 0; i < _rooms.length; i++) {
          final room = _rooms[i];
          final roomStudents = assignments[i] ?? [];

          // Find students in this room taking this subject
          final sessionStudents = roomStudents
              .where((s) => config.classIds.contains(s['classId']))
              .toList();

          if (sessionStudents.isNotEmpty) {
            // Generate participations
            final List<ExamParticipation> participations = sessionStudents.map((s) {
              return ExamParticipation(
                studentId: s['id'] ?? '',
                studentName: s['name'] ?? '',
                nis: s['nis'] ?? '',
                hasStarted: false,
                seatNumber: s['seatNumber'] as int? ?? 0,
                roomName: room.name,
                angkatan: s['angkatan'] ?? '',
              );
            }).toList();

            // Find overlapping classes in this session
            final sessionClasses = sessionStudents.map((s) => s['className'] as String).toSet().toList()..sort();

            // Look up proctor from _draftSessions
            String sessionProctorId = '';
            String sessionProctorName = 'Belum ditugaskan';
            if (_draftSessions.isNotEmpty) {
              final matchedDraft = _draftSessions.cast<Map<String, dynamic>?>().firstWhere(
                (s) => s != null &&
                    s['date'] == date &&
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
              date: date,
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
          }
        }
      });

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
          'Sukses',
          'Event ujian berhasil dibuat. Silakan tambahkan jadwal sesi secara manual.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isGenerating = false);
      _showError('Gagal membuat event: $e');
    }
  }



  // ── UI Helpers ───────────────────────────────────────────────
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
                      'Distribusi Pengawas Ujian',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tugaskan guru pengawas untuk setiap ruangan & sesi.',
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _autoAssignProctors,
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('Atur Otomatis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_draftSessions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'Belum ada jadwal mapel yang disusun di Step sebelumnya.',
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
                            ...slotSessions.map((session) {
                              final roomName = session['roomName'] as String;
                              final subjectName = session['subjectName'] as String;
                              final classes = session['classes'] as List<String>;
                              final pId = session['proctorId'] as String;

                              final hasConf = hasConflict(session);
                              final hasExceed = exceedsDailyLimit(session);

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
                                          const SizedBox(height: 2),
                                          Text(
                                            '$subjectName (${classes.join(', ')})',
                                            style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (hasConf || hasExceed) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (hasConf) ...[
                                                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 12),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Bentrokan Sesi',
                                                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (hasExceed) ...[
                                                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 12),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'Melebihi 2 Sesi',
                                                    style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
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
                                              'Pilih Pengawas',
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
                                              const DropdownMenuItem<String>(
                                                value: null,
                                                child: Text(
                                                  'Belum ditugaskan',
                                                  style: TextStyle(fontStyle: FontStyle.italic),
                                                ),
                                              ),
                                              ..._allTeachers.map((teacher) {
                                                return DropdownMenuItem<String>(
                                                  value: teacher['id'] as String,
                                                  child: Text(teacher['nama'] as String),
                                                );
                                              }),
                                            ],
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == null) {
                                                  session['proctorId'] = '';
                                                  session['proctorName'] = 'Belum ditugaskan';
                                                } else {
                                                  final teacher = _allTeachers.firstWhere((t) => t['id'] == val);
                                                  session['proctorId'] = val;
                                                  session['proctorName'] = teacher['nama'] as String;
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
            }),
        ],
      ),
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
                      'Jadwal Ujian Final',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Tampilan lengkap jadwal ujian per hari yang siap diterbitkan.',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Summary chip
              if (_draftSessions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_draftSessions.length} Sesi • ${sessionsByDay.length} Hari',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                      'Jadwal belum tersusun.',
                      style: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kembali ke step sebelumnya dan atur jadwal mapel.',
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
              final dayLabel = DateFormat('EEEE, dd MMMM yyyy', 'id').format(parsedDate);

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
                                      '${daySessions.length} sesi',
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
                                    child: Text('Sesi / Waktu', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text('Ruangan', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: Text('Mata Pelajaran', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: Text('Pengawas', style: TextStyle(color: headerText, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),

                            // Data rows grouped by slot
                            ...slots.expand((slotName) {
                              final slotSessions = daySessions.where((s) => s['slotName'] == slotName).toList()
                                ..sort((a, b) => (a['roomName'] as String).compareTo(b['roomName'] as String));

                              final sampleSession = slotSessions.first;

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
                                        slotName,
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

                                // One row per session in this slot
                                ...slotSessions.map((session) {
                                  final roomName = session['roomName'] as String;
                                  final subjectName = session['subjectName'] as String;
                                  final proctorName = session['proctorName'] as String;
                                  final proctorId = session['proctorId'] as String;
                                  final hasProctor = proctorId.isNotEmpty;

                                  return Container(
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
                                            subjectName,
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
    while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
      days.add(current);
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
                'Rentang tanggal belum ditentukan di Step 1. Silakan tentukan tanggal ujian untuk menyusun jadwal.',
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
        Text(
          'Jadwal Ujian & Mata Pelajaran',
          style: TextStyle(
            color: titleColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tentukan hari dan slot waktu untuk masing-masing mata pelajaran. Satu mata pelajaran hanya bisa dijadwalkan sekali.',
          style: TextStyle(color: subtitleColor, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...days.map((day) {
          final dayStr = DateFormat('yyyy-MM-dd').format(day);
          final dayLabel = DateFormat('EEEE, dd MMMM yyyy', 'id').format(day);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                // Slots
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: _slots.map((slot) {
                      final scheduleKey = '${dayStr}_${slot.name}';
                      final selectedSubjectId = _scheduledSubjects[scheduleKey];

                      // Determine items for this slot
                      final scheduledIds = _scheduledSubjects.entries
                          .where((e) => e.key != scheduleKey)
                          .map((e) => e.value)
                          .toSet();

                      final availableSubjects = _subjectConfigs.where((sub) {
                        return !scheduledIds.contains(sub.subjectId);
                      }).toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slot.name,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${slot.startTime} - ${slot.endTime}',
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedSubjectId != null
                                        ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                                        : cardBorder,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedSubjectId,
                                    hint: Text(
                                      'Pilih Mata Pelajaran',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    dropdownColor: isDark ? const Color(0xFF1E1C38) : Colors.white,
                                    isExpanded: true,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 12,
                                      fontWeight: selectedSubjectId != null ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text(
                                          'Kosong / Tidak ada ujian',
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                      ...availableSubjects.map((sub) {
                                        return DropdownMenuItem<String>(
                                          value: sub.subjectId,
                                          child: Text(sub.subjectName),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == null) {
                                          _scheduledSubjects.remove(scheduleKey);
                                        } else {
                                          _scheduledSubjects[scheduleKey] = val;
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
                  ),
                ),
              ],
            ),
          );
        }),
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

  void _autoAssignProctors() {
    if (_allTeachers.isEmpty) {
      _showError('Tidak ada data guru untuk ditugaskan sebagai pengawas.');
      return;
    }

    // Compile sessions first if not yet done
    if (_draftSessions.isEmpty) {
      if (_scheduledSubjects.isEmpty) {
        _showError('Jadwal mata pelajaran belum dikonfigurasi di Step sebelumnya.');
        return;
      }
      _compileDraftSessions();
      // Re-run after compile in next frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoAssignProctors());
      return;
    }

    setState(() {
      // Group draft sessions by date
      final Map<String, List<Map<String, dynamic>>> sessionsByDay = {};
      for (final session in _draftSessions) {
        final dayStr = DateFormat('yyyy-MM-dd').format(session['date'] as DateTime);
        sessionsByDay.putIfAbsent(dayStr, () => []).add(session);
      }

      // Assign for each day
      sessionsByDay.forEach((dayStr, daySessions) {
        // Track daily proctor usage count
        final Map<String, int> dailyProctorCounts = {}; // teacherId -> count
        for (final t in _allTeachers) {
          dailyProctorCounts[t['id'] as String] = 0;
        }

        // Group daySessions by slot
        final Map<String, List<Map<String, dynamic>>> sessionsBySlot = {};
        for (final s in daySessions) {
          final slotName = s['slotName'] as String;
          sessionsBySlot.putIfAbsent(slotName, () => []).add(s);
        }

        // Assign slot by slot
        sessionsBySlot.forEach((slotName, slotSessions) {
          final Set<String> assignedInThisSlot = {};

          for (final session in slotSessions) {
            // Find candidate teacher
            String? chosenId;
            String chosenName = 'Belum ditugaskan';

            // Sort teachers by current daily count
            final candidates = List<Map<String, dynamic>>.from(_allTeachers);
            candidates.sort((a, b) {
              final countA = dailyProctorCounts[a['id']] ?? 0;
              final countB = dailyProctorCounts[b['id']] ?? 0;
              return countA.compareTo(countB);
            });

            for (final teacher in candidates) {
              final tId = teacher['id'] as String;
              final dailyCount = dailyProctorCounts[tId] ?? 0;

              // Constraints:
              // 1. Not already teaching in this slot
              // 2. Daily count < 2
              if (!assignedInThisSlot.contains(tId) && dailyCount < 2) {
                chosenId = tId;
                chosenName = teacher['nama'] as String;
                break;
              }
            }

            if (chosenId != null) {
              session['proctorId'] = chosenId;
              session['proctorName'] = chosenName;
              assignedInThisSlot.add(chosenId);
              dailyProctorCounts[chosenId] = (dailyProctorCounts[chosenId] ?? 0) + 1;
            } else {
              session['proctorId'] = '';
              session['proctorName'] = 'Belum ditugaskan';
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

    _scheduledSubjects.forEach((scheduleKey, subjectId) {
      // scheduleKey format is "yyyy-MM-dd_slotName"
      final firstUnderscore = scheduleKey.indexOf('_');
      if (firstUnderscore == -1) return; // Malformed key, skip
      final dayStr = scheduleKey.substring(0, firstUnderscore);
      final slotName = scheduleKey.substring(firstUnderscore + 1);

      final date = DateTime.tryParse(dayStr);
      if (date == null) return; // Malformed date, skip

      final slotMatches = _slots.where((s) => s.name == slotName).toList();
      if (slotMatches.isEmpty) return; // Slot not found, skip
      final slot = slotMatches.first;

      final configMatches = _subjectConfigs.where((c) => c.subjectId == subjectId).toList();
      if (configMatches.isEmpty) return; // Config not found, skip
      final config = configMatches.first;

      for (int i = 0; i < _rooms.length; i++) {
        final room = _rooms[i];
        final roomStudents = assignments[i] ?? [];

        // Find students in this room taking this subject by classId
        final sessionStudents = roomStudents
            .where((s) => config.classIds.contains(s['classId'] ?? ''))
            .toList();

        // Determine classes for this session:
        // Prefer student-derived, fall back to room.classes intersection with config.classIds
        List<String> sessionClasses;
        if (sessionStudents.isNotEmpty) {
          sessionClasses = sessionStudents.map((s) => s['className'] as String).toSet().toList()..sort();
        } else {
          // Match room classes to config classIds by name
          final configClassNames = _allClasses
              .where((c) => config.classIds.contains(c['id']))
              .map((c) => c['name'] as String)
              .toSet();
          sessionClasses = room.classes
              .where((clsName) => configClassNames.contains(clsName))
              .toList()..sort();
        }

        if (sessionClasses.isNotEmpty) {
          // Check if this session already exists in our state _draftSessions
          final existing = _draftSessions.cast<Map<String, dynamic>?>().firstWhere(
            (s) => s != null &&
                s['date'] == date &&
                s['slotName'] == slot.name &&
                s['roomName'] == room.name &&
                s['subjectId'] == config.subjectId,
            orElse: () => null,
          );

          compiled.add({
            'date': date,
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
        }
      }
    });

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
      final List<Map<String, dynamic>> roomStudents = [];

      for (final clsName in room.classes) {
        final cls = _allClasses.firstWhere(
          (c) => c['name'] == clsName,
          orElse: () => <String, dynamic>{},
        );
        final cid = cls['id'];
        if (cid != null) {
          final students = _studentsByClass[cid];
          if (students != null) {
            for (final s in students) {
              if (!assignedStudentIds.contains(s['id'])) {
                roomStudents.add({
                  ...s,
                  'className': clsName,
                  'classId': cid, // ensure classId is available for subject matching
                });
              }
            }
          }
        }
      }

      if (roomStudents.isEmpty) {
        assignments[index] = [];
        continue;
      }

      final Map<String, List<Map<String, dynamic>>> byAngkatan = {};
      for (final s in roomStudents) {
        final a = (s['angkatan'] as String).isNotEmpty ? s['angkatan'] as String : '-';
        byAngkatan.putIfAbsent(a, () => []).add(s);
      }

      final sortedAngkatans = byAngkatan.keys.toList()
        ..sort((a, b) => byAngkatan[b]!.length.compareTo(byAngkatan[a]!.length));

      List<Map<String, dynamic>> listA = [];
      List<Map<String, dynamic>> listB = [];

      if (sortedAngkatans.isNotEmpty) {
        listA = List<Map<String, dynamic>>.from(byAngkatan[sortedAngkatans[0]]!);
      }
      if (sortedAngkatans.length > 1) {
        for (int i = 1; i < sortedAngkatans.length; i++) {
          listB.addAll(byAngkatan[sortedAngkatans[i]]!);
        }
      }

      listA.sort((a, b) => (a['nama'] as String).compareTo(b['nama'] as String));
      listB.sort((a, b) => (a['nama'] as String).compareTo(b['nama'] as String));

      final List<Map<String, dynamic>> interleaved = [];
      int idxA = 0;
      int idxB = 0;
      
      for (int i = 0; i < room.capacity; i++) {
        if (idxA >= listA.length && idxB >= listB.length) break;
        
        Map<String, dynamic>? picked;
        if (i % 2 == 0) {
          if (idxA < listA.length) {
            picked = listA[idxA++];
          } else if (idxB < listB.length) {
            picked = listB[idxB++];
          }
        } else {
          if (idxB < listB.length) {
            picked = listB[idxB++];
          } else if (idxA < listA.length) {
            picked = listA[idxA++];
          }
        }

        if (picked != null) {
          interleaved.add(picked);
          assignedStudentIds.add(picked['id'] as String);
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

