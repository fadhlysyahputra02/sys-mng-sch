import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exam_event_model.dart';
import 'exam_session_service.dart';

// ─────────────────────────────────────────────────────────────
//  ExamSchedulerService — Auto-Scheduler & Proctor Randomizer
//
//  ALGORITMA:
//  1. generateSchedule(): Greedy assignment mapel → hari/slot
//     Constraint: satu kelas tidak boleh punya dua ujian di slot/hari yang sama
//
//  2. assignProctors(): Randomized assignment pengawas
//     Constraint:
//       a) Guru TIDAK boleh mengawas mapel yang dia sendiri buat soalnya (authorTeacherId)
//       b) FAIRNESS: Max 2 sesi per hari per guru (hardcoded)
//       c) Guru tidak aktif (aktif == false) tidak digunakan
// ─────────────────────────────────────────────────────────────
class ExamSchedulerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _maxSessionsPerDayPerProctor = 2;

  // ─────────────────────────────────────────────────
  //  Step 1: Generate jadwal dari konfigurasi event
  // ─────────────────────────────────────────────────

  /// Menghasilkan list ExamSession (belum ada proctorId) dari ExamEvent.
  /// Algoritma greedy:
  ///   - Iterasi setiap subjectConfig → setiap classId
  ///   - Cari slot kosong (tidak bentrok dengan kelas yang sama di hari+slot yang sama)
  ///   - Assign ke hari+slot paling awal yang tersedia
  /// Ambil hari belajar aktif dari jadwal regular pelajaran di Firestore
  Future<Set<String>> getActiveStudyDays(String schoolId) async {
    final snap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('class_schedules')
        .get();

    final Set<String> days = {};
    for (final doc in snap.docs) {
      final day = doc.data()['hari'] as String?;
      if (day != null && day.isNotEmpty) {
        days.add(day.trim().toLowerCase());
      }
    }
    return days;
  }

  Future<List<ExamSession>> generateSchedule(String schoolId, ExamEvent event) async {
    final activeStudyDays = await getActiveStudyDays(schoolId);

    final List<DateTime> availableDates = _getWorkDays(
      event.startDate,
      event.endDate,
      activeStudyDays,
    );

    if (availableDates.isEmpty || event.dailySlots.isEmpty) return [];

    final List<ExamSession> sessions = [];
    final Set<String> occupiedSlots = {};

    int dateIndex = 0;
    int slotIndex = 0;

    for (final subjectConfig in event.subjectConfigs) {
      bool foundSlot = false;

      // Search all slots starting from the current dateIndex and slotIndex
      int tempDateIdx = dateIndex;
      int tempSlotIdx = slotIndex;

      int totalSlots = availableDates.length * event.dailySlots.length;
      for (int i = 0; i < totalSlots; i++) {
        final date = availableDates[tempDateIdx];
        final slot = event.dailySlots[tempSlotIdx];

        // Check if this slot is free for ALL classIds in this subjectConfig
        bool allFree = true;
        for (final classId in subjectConfig.classIds) {
          final key = '${classId}_${_dateKey(date)}_${slot.name}';
          if (occupiedSlots.contains(key)) {
            allFree = false;
            break;
          }
        }

        if (allFree) {
          // Found it!
          for (final classId in subjectConfig.classIds) {
            final key = '${classId}_${_dateKey(date)}_${slot.name}';
            occupiedSlots.add(key);

            sessions.add(ExamSession(
              id: '',
              eventId: event.id,
              subjectId: subjectConfig.subjectId,
              subjectName: subjectConfig.subjectName,
              classId: classId,
              className: '',
              date: DateTime(date.year, date.month, date.day),
              slotName: slot.name,
              startTime: slot.startTime,
              endTime: slot.endTime,
              roomName: '',
              proctorId: '',
              proctorName: '',
              authorTeacherId: subjectConfig.authorTeacherId,
              qrToken: ExamSessionService.generateQrToken(),
              isQrActive: false,
              examStatus: 'Scheduled',
            ));
          }

          foundSlot = true;
          // Set the pointer for the NEXT subject to search starting from the slot right after this one
          slotIndex = tempSlotIdx + 1;
          dateIndex = tempDateIdx;
          if (slotIndex >= event.dailySlots.length) {
            slotIndex = 0;
            dateIndex++;
          }
          if (dateIndex >= availableDates.length) {
            dateIndex = 0;
          }
          break;
        }

        // Advance slot pointer
        tempSlotIdx++;
        if (tempSlotIdx >= event.dailySlots.length) {
          tempSlotIdx = 0;
          tempDateIdx++;
        }
        if (tempDateIdx >= availableDates.length) {
          tempDateIdx = 0;
        }
      }

      if (!foundSlot) {
        // Fallback: if we checked every slot and couldn't find one where all classes are free,
        // we just schedule it in the last date & first slot as fallback.
        final fallbackDate = availableDates.last;
        final fallbackSlot = event.dailySlots.first;
        for (final classId in subjectConfig.classIds) {
          sessions.add(ExamSession(
            id: '',
            eventId: event.id,
            subjectId: subjectConfig.subjectId,
            subjectName: subjectConfig.subjectName,
            classId: classId,
            className: '',
            date: fallbackDate,
            slotName: fallbackSlot.name,
            startTime: fallbackSlot.startTime,
            endTime: fallbackSlot.endTime,
            roomName: '',
            proctorId: '',
            proctorName: '',
            authorTeacherId: subjectConfig.authorTeacherId,
            qrToken: ExamSessionService.generateQrToken(),
            isQrActive: false,
            examStatus: 'Scheduled',
          ));
        }
      }
    }

    // Sort by date and slot
    sessions.sort((a, b) {
      final dateCmp = a.date.compareTo(b.date);
      if (dateCmp != 0) return dateCmp;
      return a.slotName.compareTo(b.slotName);
    });

    return sessions;
  }

  // ─────────────────────────────────────────────────
  //  Step 2: Assign pengawas ke setiap sesi
  // ─────────────────────────────────────────────────

  /// Mengambil data guru dari Firestore dan assign pengawas ke setiap sesi.
  /// Constraint:
  ///   a) Guru adalah author soal → skip
  ///   b) Guru sudah mengawas ≥ maxSessionsPerDay di hari yang sama → skip
  ///   c) Tidak ada guru tersedia → biarkan kosong (admin manual override)
  Future<List<ExamSession>> assignProctors({
    required String schoolId,
    required List<ExamSession> sessions,
  }) async {
    // Ambil seluruh guru aktif
    final teacherSnap = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('teachers')
        .where('aktif', isEqualTo: true)
        .get();

    if (teacherSnap.docs.isEmpty) return sessions;

    final teachers = teacherSnap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'nama': data['nama'] ?? '',
      };
    }).toList();

    // Tracker beban pengawas: key = "teacherId_dateStr" → jumlah sesi
    final Map<String, int> proctorLoad = {};

    final rng = Random.secure();
    final List<ExamSession> result = [];

    for (final session in sessions) {
      final dateKey = _dateKey(session.date);

      // Kumpulkan kandidat yang eligible
      final List<Map<String, dynamic>> candidates = [];
      for (final teacher in teachers) {
        final tid = teacher['id'] as String;

        // Constraint a: author soal tidak boleh mengawas
        if (tid == session.authorTeacherId) continue;

        // Constraint b: maks 2 sesi per hari
        final loadKey = '${tid}_$dateKey';
        final currentLoad = proctorLoad[loadKey] ?? 0;
        if (currentLoad >= _maxSessionsPerDayPerProctor) continue;

        candidates.add(teacher);
      }

      String assignedProctorId = '';
      String assignedProctorName = '';

      if (candidates.isNotEmpty) {
        // Pilih kandidat dengan beban paling sedikit di hari itu (fairness)
        candidates.sort((a, b) {
          final loadA =
              proctorLoad['${a['id']}_$dateKey'] ?? 0;
          final loadB =
              proctorLoad['${b['id']}_$dateKey'] ?? 0;
          return loadA.compareTo(loadB);
        });

        // Ambil semua kandidat dengan beban minimum (untuk randomisasi di antara mereka)
        final minLoad = proctorLoad['${candidates.first['id']}_$dateKey'] ?? 0;
        final minCandidates = candidates
            .where((c) => (proctorLoad['${c['id']}_$dateKey'] ?? 0) == minLoad)
            .toList();

        // Pilih acak dari kandidat dengan beban minimum
        final picked = minCandidates[rng.nextInt(minCandidates.length)];

        assignedProctorId = picked['id'] as String;
        assignedProctorName = picked['nama'] as String;

        // Update load tracker
        final loadKey = '${assignedProctorId}_$dateKey';
        proctorLoad[loadKey] = (proctorLoad[loadKey] ?? 0) + 1;
      }

      result.add(session.copyWith(
        proctorId: assignedProctorId,
        proctorName: assignedProctorName,
      ));
    }

    return result;
  }

  // ─────────────────────────────────────────────────
  //  Step 3: Distribute Rooms and Alternating Seats
  // ─────────────────────────────────────────────────

  /// Mendistribusikan siswa ke ruangan dan nomor kursi secara selang-seling (interleaved),
  /// yang bersifat STABLE (tetap) selama event berlangsung untuk satu siswa.
  Future<List<ExamSession>> distributeRoomsAndSeats({
    required String schoolId,
    required List<ExamSession> sessions,
    required List<ExamRoom> rooms,
    required bool randomizeStudents,
  }) async {
    if (rooms.isEmpty) return sessions;

    // 1. Collect all participating classes
    final classIds = sessions.map((s) => s.classId).toSet().toList();
    final Map<String, List<Map<String, dynamic>>> studentsByClass = {};

    // 2. Fetch all students for the participating classes
    for (final cid in classIds) {
      if (cid.isEmpty) continue;
      final snap = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('classId', isEqualTo: cid)
          .get();
      studentsByClass[cid] = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'nama': data['nama'] ?? '',
          'nis': data['nis'] ?? '',
          'angkatan': (data['angkatan'] ?? '').toString().trim(),
        };
      }).toList();
    }

    // Mapping: studentId -> { 'roomName': roomName, 'seatNumber': seat, ... }
    final Map<String, Map<String, dynamic>> globalSeating = {};

    if (!randomizeStudents) {
      // Group and sort students strictly by class (non-randomized)
      final List<Map<String, dynamic>> sortedStudentsNonRandom = [];
      for (final cid in classIds) {
        final cStudents = List<Map<String, dynamic>>.from(studentsByClass[cid] ?? []);
        cStudents.sort((a, b) => (a['nama'] as String).compareTo(b['nama'] as String));
        sortedStudentsNonRandom.addAll(cStudents);
      }

      int studentIndex = 0;
      for (final room in rooms) {
        final capacity = room.capacity;
        for (int seat = 1; seat <= capacity; seat++) {
          if (studentIndex >= sortedStudentsNonRandom.length) break;
          final std = sortedStudentsNonRandom[studentIndex++];
          globalSeating[std['id']] = {
            'roomName': room.name,
            'seatNumber': seat,
            'studentName': std['nama'] as String,
            'nis': std['nis'] as String,
            'angkatan': std['angkatan'] as String,
          };
        }
      }
    } else {
      // 3. Collect all students from all participating classes
      final List<Map<String, dynamic>> allStudents = [];
      final Map<String, String> studentToClassMap = {};

      for (final cid in classIds) {
        final cStudents = studentsByClass[cid] ?? [];
        for (final std in cStudents) {
          allStudents.add(std);
          studentToClassMap[std['id']] = cid;
        }
      }

      // 4. Group students by angkatan and interleave them (interleaved seating layout)
      final Map<String, List<Map<String, dynamic>>> studentsByAngkatan = {};
      for (final std in allStudents) {
        final angkatan = std['angkatan'].isNotEmpty ? std['angkatan'] : '-';
        studentsByAngkatan.putIfAbsent(angkatan, () => []).add(std);
      }

      // Shuffle each cohort list to randomize within cohort
      for (final list in studentsByAngkatan.values) {
        list.shuffle();
      }

      // Re-order cohorts so that if we have 3 cohorts (e.g. 2022, 2023, 2024),
      // we pair 2022 (XII) and 2024 (X) first, leaving 2023 (XI) for the end.
      final sortedAngkatans = studentsByAngkatan.keys.toList()..sort();
      if (sortedAngkatans.length == 3) {
        final temp = sortedAngkatans[1]; // e.g. "2023"
        sortedAngkatans[1] = sortedAngkatans[2]; // e.g. "2024"
        sortedAngkatans[2] = temp;
      } else {
        // Default to sorting by cohort size descending for general cases
        sortedAngkatans.sort((a, b) => studentsByAngkatan[b]!.length.compareTo(studentsByAngkatan[a]!.length));
      }

      final List<Map<String, dynamic>> interleavedStudents = [];
      final List<List<Map<String, dynamic>>> cohortQueues = sortedAngkatans.map((c) => studentsByAngkatan[c]!).toList();

      List<Map<String, dynamic>> currentListA = [];
      List<Map<String, dynamic>> currentListB = [];

      while (cohortQueues.isNotEmpty || currentListA.isNotEmpty || currentListB.isNotEmpty) {
        if (currentListA.isEmpty && cohortQueues.isNotEmpty) {
          currentListA = cohortQueues.removeAt(0);
        }
        if (currentListB.isEmpty && cohortQueues.isNotEmpty) {
          currentListB = cohortQueues.removeAt(0);
        }

        if (currentListA.isNotEmpty && currentListB.isNotEmpty) {
          while (currentListA.isNotEmpty && currentListB.isNotEmpty) {
            interleavedStudents.add(currentListA.removeAt(0));
            interleavedStudents.add(currentListB.removeAt(0));
          }
        } else if (currentListA.isNotEmpty) {
          interleavedStudents.addAll(currentListA);
          currentListA.clear();
        } else if (currentListB.isNotEmpty) {
          interleavedStudents.addAll(currentListB);
          currentListB.clear();
        }
      }

      int studentIndex = 0;
      for (final room in rooms) {
        final capacity = room.capacity;
        for (int seat = 1; seat <= capacity; seat++) {
          if (studentIndex >= interleavedStudents.length) break;
          final selectedStudent = interleavedStudents[studentIndex++];
          globalSeating[selectedStudent['id']] = {
            'roomName': room.name,
            'seatNumber': seat,
            'studentName': selectedStudent['nama'] as String,
            'nis': selectedStudent['nis'] as String,
            'angkatan': selectedStudent['angkatan'] as String,
          };
        }
      }
    }

    // 5. Enrich each ExamSession with room and participation list
    final List<ExamSession> enrichedSessions = [];

    for (final s in sessions) {
      // Find all students in this session's class
      final classStudents = studentsByClass[s.classId] ?? [];
      
      final List<ExamParticipation> parts = [];
      final Set<String> usedRooms = {};

      for (final std in classStudents) {
        final seatInfo = globalSeating[std['id']];
        if (seatInfo != null) {
          parts.add(ExamParticipation(
            studentId: std['id'] as String,
            studentName: seatInfo['studentName'] as String,
            nis: seatInfo['nis'] as String,
            hasStarted: false,
            seatNumber: seatInfo['seatNumber'] as int,
            roomName: seatInfo['roomName'] as String,
            angkatan: seatInfo['angkatan'] as String,
          ));
          usedRooms.add(seatInfo['roomName'] as String);
        }
      }

      // Sort parts by roomName and seatNumber
      parts.sort((a, b) {
        final roomCmp = a.roomName.compareTo(b.roomName);
        if (roomCmp != 0) return roomCmp;
        return a.seatNumber.compareTo(b.seatNumber);
      });

      final roomNameStr = usedRooms.isEmpty ? '-' : usedRooms.toList().join(', ');

      enrichedSessions.add(s.copyWith(
        roomName: roomNameStr,
        previewParticipations: parts,
      ));
    }

    return enrichedSessions;
  }

  // ─────────────────────────────────────────────────
  //  Helper: Fetch className dari Firestore
  // ─────────────────────────────────────────────────

  /// Mengisi field className pada setiap sesi berdasarkan classId
  Future<List<ExamSession>> enrichWithClassNames({
    required String schoolId,
    required List<ExamSession> sessions,
  }) async {
    // Kumpulkan classIds unik
    final classIds = sessions.map((s) => s.classId).toSet();
    final Map<String, String> classNameMap = {};

    for (final classId in classIds) {
      if (classId.isEmpty) continue;
      final doc = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .doc(classId)
          .get();
      if (doc.exists) {
        classNameMap[classId] = doc.data()?['name'] ?? classId;
      }
    }

    return sessions.map((s) {
      return ExamSession(
        id: s.id,
        eventId: s.eventId,
        subjectId: s.subjectId,
        subjectName: s.subjectName,
        classId: s.classId,
        className: classNameMap[s.classId] ?? s.classId,
        date: s.date,
        slotName: s.slotName,
        startTime: s.startTime,
        endTime: s.endTime,
        roomName: s.roomName,
        proctorId: s.proctorId,
        proctorName: s.proctorName,
        authorTeacherId: s.authorTeacherId,
        qrToken: s.qrToken,
        isQrActive: s.isQrActive,
        examStatus: s.examStatus,
        previewParticipations: s.previewParticipations,
      );
    }).toList();
  }

  // ─────────────────────────────────────────────────
  //  Utility
  // ─────────────────────────────────────────────────

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Kembalikan semua hari kerja dalam rentang tanggal, dengan filtering Sabtu-Minggu berdasarkan active study days
  List<DateTime> _getWorkDays(DateTime start, DateTime end, Set<String> activeStudyDays) {
    final List<DateTime> days = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(endDay)) {
      final weekday = current.weekday;
      
      bool includeDay = true;
      if (weekday == DateTime.saturday) {
        includeDay = activeStudyDays.contains('sabtu');
      } else if (weekday == DateTime.sunday) {
        includeDay = activeStudyDays.contains('minggu');
      }
      
      if (includeDay) {
        days.add(current);
      }
      
      current = current.add(const Duration(days: 1));
    }
    return days;
  }
}
