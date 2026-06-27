import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;


import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../classes/data/class_service.dart';
import '../../subjects/data/subject_service.dart';
import '../../teachers/data/teacher_service.dart';
import '../Service/class_schedule_service.dart';

class AutoScheduleGeneratorPage extends StatefulWidget {
  const AutoScheduleGeneratorPage({super.key});

  @override
  State<AutoScheduleGeneratorPage> createState() => _AutoScheduleGeneratorPageState();
}

class _AutoScheduleGeneratorPageState extends State<AutoScheduleGeneratorPage> {
  final _classService = ClassService();
  final _subjectService = SubjectService();
  final _teacherService = TeacherService();
  final _scheduleService = ClassScheduleService();

  bool _isLoading = false;
  String _statusMessage = '';

  // Generator Config
  List<String> _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'];
  int _slotsPerDay = 8;
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  int _minutesPerSlot = 45;
  
  // Breaks Config
  int _break1AfterSlot = 4;
  int _break1DurationMin = 30;
  
  int _break2AfterSlot = 6;
  int _break2DurationMin = 15;

  Future<void> _runGenerator() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Memuat data kelas, guru, dan mata pelajaran...';
    });

    try {
      final schoolId = SessionService.currentUser!.schoolId;

      // 1. Fetch all data
      final classesSnap = await _classService.getClasses(schoolId).first;
      final subjectsSnap = await _subjectService.getSubjects(schoolId).first;
      final teachersSnap = await _teacherService.getTeachers(schoolId).first;

      final classes = classesSnap.docs;
      final subjects = subjectsSnap.docs;
      final teachers = teachersSnap.docs;

      if (classes.isEmpty || subjects.isEmpty || teachers.isEmpty) {
        throw ('Data kelas, mata pelajaran, atau guru masih kosong. Silakan isi terlebih dahulu.');
      }

      // 1.5 Fetch teacher subject mappings
      final tsSnap = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('teacher_subjects')
          .get();
      
      final Map<String, List<String>> eligibleTeachersBySubject = {};
      for (final doc in tsSnap.docs) {
        final data = doc.data();
        final sId = data['subjectId'] as String?;
        final tId = data['teacherId'] as String?;
        if (sId != null && tId != null) {
          eligibleTeachersBySubject.putIfAbsent(sId, () => []).add(tId);
        }
      }

      setState(() {
        _statusMessage = 'Menghitung kombinasi jadwal...';
      });

      // We need a list to store generated schedules
      final List<Map<String, dynamic>> generatedSchedules = [];

      // A helper to track which teacher is busy at which Day-Slot index
      // Key: "Hari_SlotIndex", Value: Set of teacherIds
      final Map<String, Set<String>> busyTeachers = {};

      // Helper to calculate time
      String formatTime(TimeOfDay t) {
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }

      TimeOfDay addMinutes(TimeOfDay t, int min) {
        int totalMin = t.hour * 60 + t.minute + min;
        return TimeOfDay(hour: (totalMin ~/ 60) % 24, minute: totalMin % 60);
      }

      // Generate times for a day
      final List<Map<String, dynamic>> daySlots = [];
      TimeOfDay currentTime = _startTime;
      int subjectSlotIndex = 1;

      while (subjectSlotIndex <= _slotsPerDay) {
        final start = currentTime;
        final end = addMinutes(start, _minutesPerSlot);
        daySlots.add({
          'type': 'pelajaran',
          'slotIndex': subjectSlotIndex,
          'start': formatTime(start),
          'end': formatTime(end),
        });
        currentTime = end;

        if (subjectSlotIndex == _break1AfterSlot) {
          final breakEnd = addMinutes(currentTime, _break1DurationMin);
          daySlots.add({
            'type': 'istirahat',
            'slotIndex': -1,
            'start': formatTime(currentTime),
            'end': formatTime(breakEnd),
          });
          currentTime = breakEnd;
        } else if (subjectSlotIndex == _break2AfterSlot) {
          final breakEnd = addMinutes(currentTime, _break2DurationMin);
          daySlots.add({
            'type': 'istirahat',
            'slotIndex': -1,
            'start': formatTime(currentTime),
            'end': formatTime(breakEnd),
          });
          currentTime = breakEnd;
        }

        subjectSlotIndex++;
      }

      final lessonSlots = daySlots.where((s) => s['type'] == 'pelajaran').toList();

      // 2. Generate for each class
      for (final c in classes) {
        final classId = c.id;
        final className = c.data()['namaKelas'] ?? '';

        final classData = c.data() as Map<String, dynamic>? ?? {};
        Map<String, int> quotas = {};
        if (classData['subjectQuotas'] != null) {
          quotas = Map<String, int>.from(classData['subjectQuotas']);
        }

        final totalSubjectSlots = _days.length * _slotsPerDay;
        if (totalSubjectSlots == 0) continue;

        // Partition subjects into blocks of sizes 1, 2, or 3
        final List<Map<String, dynamic>> blocks = [];

        if (quotas.isNotEmpty) {
          for (final subject in subjects) {
            int quota = quotas[subject.id] ?? 0;
            if (quota <= 0) continue;

            while (quota > 0) {
              if (quota == 3) {
                final isGrouped = math.Random().nextInt(100) < 80;
                if (isGrouped) {
                  blocks.add({'subjectId': subject.id, 'size': 3, 'doc': subject});
                  quota -= 3;
                } else {
                  blocks.add({'subjectId': subject.id, 'size': 2, 'doc': subject});
                  blocks.add({'subjectId': subject.id, 'size': 1, 'doc': subject});
                  quota -= 3;
                }
              } else if (quota >= 4) {
                blocks.add({'subjectId': subject.id, 'size': 2, 'doc': subject});
                quota -= 2;
              } else if (quota == 2) {
                blocks.add({'subjectId': subject.id, 'size': 2, 'doc': subject});
                quota -= 2;
              } else {
                blocks.add({'subjectId': subject.id, 'size': 1, 'doc': subject});
                quota -= 1;
              }
            }
          }
        } else {
          // Fallback: Pro-rata random blocks if no quotas configured
          int quotaCount = totalSubjectSlots;
          int sIdx = 0;
          while (quotaCount > 0) {
            final subject = subjects[sIdx % subjects.length];
            final size = quotaCount >= 2 ? 2 : 1;
            blocks.add({'subjectId': subject.id, 'size': size, 'doc': subject});
            quotaCount -= size;
            sIdx++;
          }
        }

        // Sort blocks by size descending (size 3 blocks first, then 2, then 1)
        blocks.sort((a, b) => (b['size'] as int).compareTo(a['size'] as int));

        // Key: "hari", Value: Map of slotIndex to schedule entry map
        final Map<String, Map<int, Map<String, dynamic>>> classGrid = {};
        for (final day in _days) {
          classGrid[day] = {};
        }

        Map<String, String> assignedTeacherForSubject = {};

        for (final block in blocks) {
          final subjectId = block['subjectId'] as String;
          final subjectDoc = block['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
          final blockSize = block['size'] as int;

          List<String> eligibleTeacherIds = eligibleTeachersBySubject[subjectId] ?? [];
          if (assignedTeacherForSubject.containsKey(subjectId)) {
            eligibleTeacherIds = [assignedTeacherForSubject[subjectId]!];
          }

          // Options search
          final List<Map<String, dynamic>> options = [];

          for (final day in _days) {
            // "asal bukan di hari yang sama" rule:
            bool alreadyScheduledToday = false;
            for (final slot in lessonSlots) {
              final sIdx = slot['slotIndex'] as int;
              if (classGrid[day]!.containsKey(sIdx) && classGrid[day]![sIdx]?['subjectId'] == subjectId) {
                alreadyScheduledToday = true;
                break;
              }
            }
            if (alreadyScheduledToday) continue;

            // Find consecutive slots that are free
            for (int i = 0; i <= lessonSlots.length - blockSize; i++) {
              bool fits = true;
              for (int j = 0; j < blockSize; j++) {
                final slotIdx = lessonSlots[i + j]['slotIndex'] as int;
                if (classGrid[day]!.containsKey(slotIdx)) {
                  fits = false;
                  break;
                }
              }
              if (!fits) continue;

              // Check if any eligible teacher is free
              for (final tId in eligibleTeacherIds) {
                bool teacherFree = true;
                for (int j = 0; j < blockSize; j++) {
                  final slotIdx = lessonSlots[i + j]['slotIndex'] as int;
                  final slotKey = '${day}_$slotIdx';
                  if (busyTeachers[slotKey]?.contains(tId) == true) {
                    teacherFree = false;
                    break;
                  }
                }

                if (teacherFree) {
                  options.add({
                    'day': day,
                    'startIndex': i,
                    'teacherId': tId,
                  });
                }
              }
            }
          }

          // Assign block
          if (options.isNotEmpty) {
            final opt = options[math.Random().nextInt(options.length)];
            final day = opt['day'] as String;
            final startIndex = opt['startIndex'] as int;
            final tId = opt['teacherId'] as String;

            final teacherDoc = teachers.firstWhere((t) => t.id == tId);

            for (int j = 0; j < blockSize; j++) {
              final slot = lessonSlots[startIndex + j];
              final slotIdx = slot['slotIndex'] as int;
              final slotKey = '${day}_$slotIdx';

              busyTeachers.putIfAbsent(slotKey, () => <String>{}).add(tId);
              assignedTeacherForSubject[subjectId] = tId;

              classGrid[day]![slotIdx] = {
                'classId': classId,
                'className': className,
                'jenisJadwal': 'pelajaran',
                'subjectId': subjectId,
                'subjectName': subjectDoc.data()['namaMapel'] ?? 'Pelajaran',
                'teacherId': tId,
                'teacherName': teacherDoc.data()['nama'] ?? 'Guru',
                'hari': day,
                'jamMulai': slot['start'],
                'jamSelesai': slot['end'],
              };
            }
          } else {
            // Fallback 1: search for placement ignoring teacher conflict
            final List<Map<String, dynamic>> fallbackOptions = [];
            for (final day in _days) {
              bool alreadyScheduledToday = false;
              for (final slot in lessonSlots) {
                final sIdx = slot['slotIndex'] as int;
                if (classGrid[day]!.containsKey(sIdx) && classGrid[day]![sIdx]?['subjectId'] == subjectId) {
                  alreadyScheduledToday = true;
                  break;
                }
              }
              if (alreadyScheduledToday) continue;

              for (int i = 0; i <= lessonSlots.length - blockSize; i++) {
                bool fits = true;
                for (int j = 0; j < blockSize; j++) {
                  final slotIdx = lessonSlots[i + j]['slotIndex'] as int;
                  if (classGrid[day]!.containsKey(slotIdx)) {
                    fits = false;
                    break;
                  }
                }
                if (fits) {
                  final tId = eligibleTeacherIds.isNotEmpty ? eligibleTeacherIds.first : '';
                  fallbackOptions.add({
                    'day': day,
                    'startIndex': i,
                    'teacherId': tId,
                  });
                }
              }
            }

            if (fallbackOptions.isNotEmpty) {
              final opt = fallbackOptions[math.Random().nextInt(fallbackOptions.length)];
              final day = opt['day'] as String;
              final startIndex = opt['startIndex'] as int;
              final tId = opt['teacherId'] as String;

              final teacherDoc = tId.isNotEmpty ? teachers.firstWhereOrNull((t) => t.id == tId) : null;

              for (int j = 0; j < blockSize; j++) {
                final slot = lessonSlots[startIndex + j];
                final slotIdx = slot['slotIndex'] as int;
                final slotKey = '${day}_$slotIdx';

                if (tId.isNotEmpty) {
                  busyTeachers.putIfAbsent(slotKey, () => <String>{}).add(tId);
                  assignedTeacherForSubject[subjectId] = tId;
                }

                classGrid[day]![slotIdx] = {
                  'classId': classId,
                  'className': className,
                  'jenisJadwal': 'pelajaran',
                  'subjectId': subjectId,
                  'subjectName': subjectDoc.data()['namaMapel'] ?? 'Pelajaran',
                  'teacherId': tId,
                  'teacherName': teacherDoc?.data()['nama'] ?? 'Guru Bentrok/Kosong',
                  'hari': day,
                  'jamMulai': slot['start'],
                  'jamSelesai': slot['end'],
                };
              }
            } else {
              // Fallback 2: split block into size 1 blocks and place them anywhere
              for (int k = 0; k < blockSize; k++) {
                final List<Map<String, dynamic>> singleSlotOptions = [];
                
                // Try to find empty slots on days where this subject is NOT already scheduled
                for (final day in _days) {
                  bool alreadyScheduledToday = false;
                  for (final slot in lessonSlots) {
                    final sIdx = slot['slotIndex'] as int;
                    if (classGrid[day]!.containsKey(sIdx) && classGrid[day]![sIdx]?['subjectId'] == subjectId) {
                      alreadyScheduledToday = true;
                      break;
                    }
                  }
                  if (alreadyScheduledToday) continue;

                  for (final slot in lessonSlots) {
                    final sIdx = slot['slotIndex'] as int;
                    if (!classGrid[day]!.containsKey(sIdx)) {
                      singleSlotOptions.add({'day': day, 'slot': slot});
                    }
                  }
                }

                Map<String, dynamic>? chosenSlot;
                if (singleSlotOptions.isNotEmpty) {
                  // Pick randomly from options that respect "different days"
                  chosenSlot = singleSlotOptions[math.Random().nextInt(singleSlotOptions.length)];
                } else {
                  // If not possible, pick from any available empty slots across all days
                  final List<Map<String, dynamic>> allEmptySlots = [];
                  for (final day in _days) {
                    for (final slot in lessonSlots) {
                      final sIdx = slot['slotIndex'] as int;
                      if (!classGrid[day]!.containsKey(sIdx)) {
                        allEmptySlots.add({'day': day, 'slot': slot});
                      }
                    }
                  }
                  if (allEmptySlots.isNotEmpty) {
                    chosenSlot = allEmptySlots[math.Random().nextInt(allEmptySlots.length)];
                  }
                }

                if (chosenSlot != null) {
                  final day = chosenSlot['day'] as String;
                  final slot = chosenSlot['slot'] as Map<String, dynamic>;
                  final sIdx = slot['slotIndex'] as int;
                  final slotKey = '${day}_$sIdx';

                  final tId = eligibleTeacherIds.isNotEmpty ? eligibleTeacherIds.first : '';
                  final teacherDoc = tId.isNotEmpty ? teachers.firstWhereOrNull((t) => t.id == tId) : null;

                  if (tId.isNotEmpty) {
                    busyTeachers.putIfAbsent(slotKey, () => <String>{}).add(tId);
                    assignedTeacherForSubject[subjectId] = tId;
                  }

                  classGrid[day]![sIdx] = {
                    'classId': classId,
                    'className': className,
                    'jenisJadwal': 'pelajaran',
                    'subjectId': subjectId,
                    'subjectName': subjectDoc.data()['namaMapel'] ?? 'Pelajaran',
                    'teacherId': tId,
                    'teacherName': teacherDoc?.data()['nama'] ?? 'Guru Bentrok/Kosong',
                    'hari': day,
                    'jamMulai': slot['start'],
                    'jamSelesai': slot['end'],
                  };
                }
              }
            }
          }
        }

        // Assemble schedule for this class
        for (final day in _days) {
          for (final slot in daySlots) {
            if (slot['type'] == 'istirahat') {
              generatedSchedules.add({
                'classId': classId,
                'className': className,
                'jenisJadwal': 'istirahat',
                'subjectId': '',
                'subjectName': 'Istirahat',
                'teacherId': '',
                'teacherName': '-',
                'hari': day,
                'jamMulai': slot['start'],
                'jamSelesai': slot['end'],
              });
            } else {
              final sIdx = slot['slotIndex'] as int;
              if (classGrid[day]!.containsKey(sIdx)) {
                generatedSchedules.add(classGrid[day]![sIdx]!);
              } else {
                generatedSchedules.add({
                  'classId': classId,
                  'className': className,
                  'jenisJadwal': 'kosong',
                  'subjectId': '',
                  'subjectName': 'Jam Kosong',
                  'teacherId': '',
                  'teacherName': '-',
                  'hari': day,
                  'jamMulai': slot['start'],
                  'jamSelesai': slot['end'],
                });
              }
            }
          }
        }
      }

      setState(() {
        _statusMessage = 'Menyimpan ${generatedSchedules.length} jadwal ke database...';
      });

      // 3. Batch Write
      await _scheduleService.replaceAllSchedulesBySchool(
        schoolId: schoolId,
        schedules: generatedSchedules,
      );

      setState(() {
        _isLoading = false;
        _statusMessage = 'Selesai!';
      });

      Get.back();
      Get.snackbar(
        'Berhasil', 
        'Jadwal otomatis untuk semua kelas berhasil dibuat!',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Get.snackbar(
        'Gagal', 
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _selectDays() async {
    final allDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final selected = List<String>.from(_days);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F0C20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              title: const Text('Pilih Hari Belajar', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allDays.map((d) {
                    final isSelected = selected.contains(d);
                    return CheckboxListTile(
                      title: Text(d, style: const TextStyle(color: Colors.white)),
                      value: isSelected,
                      activeColor: const Color(0xFFEC4899),
                      checkColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                      onChanged: (val) {
                        setStateDialog(() {
                          if (val == true) {
                            selected.add(d);
                            // Sort based on allDays order
                            selected.sort((a, b) => allDays.indexOf(a).compareTo(allDays.indexOf(b)));
                          } else {
                            selected.remove(d);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _days = selected;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final textMainColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final infoTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonColor, size: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Generate Jadwal',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Expanded(
                  child: _isLoading 
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFFEC4899)),
                            const SizedBox(height: 24),
                            Text(
                              _statusMessage,
                              style: TextStyle(color: textMainColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFEC4899).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Color(0xFFEC4899)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Fitur ini akan membuatkan jadwal penuh untuk semua kelas secara pro-rata menggunakan semua guru dan mata pelajaran yang ada. Anda masih bisa mengeditnya nanti di tiap kelas.',
                                    style: TextStyle(color: infoTextColor, fontSize: 13, height: 1.5),
                                  ),
                                )
                              ],
                            ),
                          ),
                      const SizedBox(height: 24),
                      
                      _buildConfigItem(
                        icon: Icons.calendar_month_rounded,
                        title: 'Hari Belajar',
                        value: _days.isEmpty ? 'Pilih Hari' : '${_days.first} - ${_days.last} (${_days.length} hr)',
                        onTap: _selectDays,
                      ),
                      const SizedBox(height: 12),
                      _buildConfigDropdown(
                        icon: Icons.view_list_rounded,
                        title: 'Jam Pelajaran per Hari',
                        value: _slotsPerDay,
                        items: [6, 7, 8, 9, 10],
                        suffix: 'Jam',
                        onChanged: (val) {
                          if (val != null) setState(() => _slotsPerDay = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildConfigDropdown(
                        icon: Icons.timer_rounded,
                        title: 'Durasi per Jam',
                        value: _minutesPerSlot,
                        items: [30, 35, 40, 45, 60],
                        suffix: 'Menit',
                        onChanged: (val) {
                          if (val != null) setState(() => _minutesPerSlot = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildConfigItem(
                        icon: Icons.play_circle_fill_rounded,
                        title: 'Jam Mulai Sekolah',
                        value: '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (time != null) {
                            setState(() => _startTime = time);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildConfigDropdown(
                        icon: Icons.coffee_rounded,
                        title: 'Letak Istirahat 1',
                        value: _break1AfterSlot,
                        items: [0, 2, 3, 4, 5],
                        suffix: 'JP',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _break1AfterSlot = val;
                              if (_break2AfterSlot > 0 && _break2AfterSlot <= _break1AfterSlot) {
                                _break2AfterSlot = 0;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildConfigDropdown(
                        icon: Icons.timer_outlined,
                        title: 'Durasi Istirahat 1',
                        value: _break1DurationMin,
                        items: [15, 20, 30, 40, 45, 60],
                        suffix: 'Menit',
                        onChanged: (val) {
                          if (val != null) setState(() => _break1DurationMin = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildConfigDropdown(
                        icon: Icons.coffee_rounded,
                        title: 'Letak Istirahat 2',
                        value: _break2AfterSlot,
                        items: [0, 4, 5, 6, 7],
                        suffix: 'JP',
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _break2AfterSlot = val;
                              if (_break1AfterSlot > 0 && _break2AfterSlot > 0 && _break2AfterSlot <= _break1AfterSlot) {
                                _break1AfterSlot = 0;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildConfigDropdown(
                        icon: Icons.timer_outlined,
                        title: 'Durasi Istirahat 2',
                        value: _break2DurationMin,
                        items: [10, 15, 20, 30, 40, 45, 60],
                        suffix: 'Menit',
                        onChanged: (val) {
                          if (val != null) setState(() => _break2DurationMin = val);
                        },
                      ),

                      const SizedBox(height: 24),
                      // Summary / Sync info card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                          ),
                          boxShadow: isDark
                              ? const []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ringkasan Jadwal Mingguan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E1B4B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              label: 'Total JP per Minggu',
                              value: '$_totalJpPerWeek JP',
                              isDark: isDark,
                              valueColor: const Color(0xFFEC4899),
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              label: 'Durasi KBM per Hari',
                              value: '${(_slotsPerDay * _minutesPerSlot) ~/ 60} jam ${(_slotsPerDay * _minutesPerSlot) % 60} menit',
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              label: 'Estimasi Jam Pulang',
                              value: 'Pukul ${_calculateSchoolEndTime()} WIB',
                              isDark: isDark,
                              valueColor: const Color(0xFF10B981),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 12),
                            Text(
                              'Sinkronisasi Konfigurasi:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• 1 Hari = $_slotsPerDay JP @ $_minutesPerSlot Menit = ${(_slotsPerDay * _minutesPerSlot) ~/ 60} jam ${(_slotsPerDay * _minutesPerSlot) % 60} menit pembelajaran aktif per hari.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Dengan ${_days.length} hari belajar per minggu, maka alokasi jadwal otomatis ini akan menghasilkan total $_totalJpPerWeek JP per minggu untuk setiap kelas.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEC4899),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _runGenerator,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC4899),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: const Color(0xFFEC4899).withValues(alpha: 0.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome_rounded),
                              SizedBox(width: 10),
                              Text('Mulai Generate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildConfigItem({required IconData icon, required String title, required String value, VoidCallback? onTap}) {
    final isDark = AuthBackground.isDarkMode.value;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final cardTextColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E1B4B);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final editIconColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final shadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
            boxShadow: shadow,
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(title, style: TextStyle(color: cardTextColor, fontSize: 15)),
              ),
              Text(
                value,
                style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.edit_rounded, color: editIconColor, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigDropdown({
    required IconData icon, 
    required String title, 
    required int value, 
    required List<int> items,
    required String suffix,
    required ValueChanged<int?> onChanged,
  }) {
    final isDark = AuthBackground.isDarkMode.value;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final cardTextColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E1B4B);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final dropdownBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final arrowColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
    final shadow = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: shadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: TextStyle(color: cardTextColor, fontSize: 15)),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              dropdownColor: dropdownBg,
              icon: Icon(Icons.arrow_drop_down_rounded, color: arrowColor),
              style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.bold, fontSize: 15),
              items: items.map((e) {
                String displayText = '$e $suffix';
                if (e == 0) {
                  displayText = 'Tidak Ada';
                } else if (title.contains('Istirahat') && !title.contains('Durasi')) {
                  displayText = 'Setelah Jam ke-$e';
                }
                return DropdownMenuItem<int>(
                  value: e,
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: isDark ? const Color(0xFFEC4899) : const Color(0xFF1E1B4B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  int get _totalJpPerWeek => _days.length * _slotsPerDay;

  String _calculateSchoolEndTime() {
    int totalMinutes = _slotsPerDay * _minutesPerSlot;
    if (_break1AfterSlot > 0 && _slotsPerDay > _break1AfterSlot) {
      totalMinutes += _break1DurationMin;
    }
    if (_break2AfterSlot > 0 && _slotsPerDay > _break2AfterSlot) {
      totalMinutes += _break2DurationMin;
    }

    int startMinutes = _startTime.hour * 60 + _startTime.minute;
    int endMinutes = startMinutes + totalMinutes;

    final endHour = (endMinutes ~/ 60) % 24;
    final endMinute = endMinutes % 60;

    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final defaultValColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E1B4B);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: labelColor),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? defaultValColor,
          ),
        ),
      ],
    );
  }
}
