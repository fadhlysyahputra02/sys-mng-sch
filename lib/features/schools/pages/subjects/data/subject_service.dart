import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _subjectsRef(String schoolId) =>
      _db.collection('schools').doc(schoolId).collection('subjects');

  Stream<QuerySnapshot<Map<String, dynamic>>> getSubjects(String schoolId) {
    return _subjectsRef(schoolId).snapshots();
  }

  bool _isSimilarName(String name1, String name2) {
    // Normalize string: lowercase, keep only alphanumeric
    String clean(String s) {
      return s.toLowerCase().replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final cleanA = clean(name1);
    final cleanB = clean(name2);
    
    if (cleanA == cleanB) return true;

    // Extract initials (acronyms) from a multi-word string
    List<String> getInitials(String s) {
      final words = s.toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && w != 'dan' && w != 'ke' && w != 'di' && w != 'atau')
          .toList();
      if (words.isEmpty) return [];

      final firstChars = words.map((w) => w[0]).join();
      final initialsList = <String>[firstChars];

      if (words.contains('kewarganegaraan')) {
        final idx = words.indexOf('kewarganegaraan');
        final customWords = List<String>.from(words);
        customWords[idx] = 'kn';
        initialsList.add(customWords.map((w) => w[0]).join());
      }
      return initialsList;
    }

    final initialsA = getInitials(name1);
    final initialsB = getInitials(name2);

    if (initialsA.any((init) => init == cleanB)) return true;
    if (initialsB.any((init) => init == cleanA)) return true;

    // Common Indonesian abbreviation mapping
    final Map<String, Set<String>> commonAbbreviations = {
      'pkn': {'pendidikan kewarganegaraan', 'pendidikan pancasila dan kewarganegaraan', 'kewarganegaraan'},
      'ppkn': {'pendidikan pancasila dan kewarganegaraan', 'pendidikan kewarganegaraan', 'pendidikan pancasila kewarganegaraan'},
      'ipa': {'ilmu pengetahuan alam', 'sains'},
      'ips': {'ilmu pengetahuan sosial'},
      'pjok': {'pendidikan jasmani olahraga dan kesehatan', 'penjasorkes', 'pendidikan jasmani', 'penjas'},
      'penjas': {'pendidikan jasmani', 'pendidikan jasmani olahraga dan kesehatan', 'penjasorkes'},
      'penjasorkes': {'pendidikan jasmani olahraga dan kesehatan', 'pendidikan jasmani', 'penjas'},
      'pai': {'pendidikan agama islam', 'agama islam'},
      'pabp': {'pendidikan agama dan budi pekerti', 'pendidikan agama islam dan budi pekerti'},
      'mtk': {'matematika'},
      'sbdp': {'seni budaya dan prakarya', 'seni budaya'},
      'sbk': {'seni budaya dan keterampilan', 'seni budaya'},
    };

    bool checkAbbr(String abbr, String fullName) {
      final cleanFull = clean(fullName);
      if (commonAbbreviations.containsKey(abbr)) {
        for (final target in commonAbbreviations[abbr]!) {
          if (clean(target) == cleanFull) return true;
        }
      }
      return false;
    }

    if (checkAbbr(cleanA, name2) || checkAbbr(cleanB, name1)) return true;

    return false;
  }

  Future<void> _checkDuplicateOrSimilar({
    required String schoolId,
    required String kodeMapel,
    required String namaMapel,
    String? excludeSubjectId,
  }) async {
    final snapshot = await _subjectsRef(schoolId).get();
    final cleanNewCode = kodeMapel.toLowerCase().trim();

    for (final doc in snapshot.docs) {
      if (excludeSubjectId != null && doc.id == excludeSubjectId) {
        continue;
      }

      final data = doc.data();
      final String existingCode = (data['kodeMapel'] ?? '').toString().toLowerCase().trim();
      final String existingName = (data['namaMapel'] ?? '').toString();

      if (existingCode == cleanNewCode) {
        throw Exception('Kode mata pelajaran "$kodeMapel" sudah terdaftar.');
      }

      if (_isSimilarName(existingName, namaMapel)) {
        throw Exception('Mata pelajaran "$namaMapel" hampir sama atau mirip dengan yang sudah ada: "$existingName" ($existingCode).');
      }
    }
  }

  Future<void> addSubject({
    required String schoolId,
    required String kodeMapel,
    required String namaMapel,
    required int kkm,
  }) async {
    await _checkDuplicateOrSimilar(
      schoolId: schoolId,
      kodeMapel: kodeMapel,
      namaMapel: namaMapel,
    );

    final doc = _subjectsRef(schoolId).doc();

    await doc.set({
      'subjectId': doc.id,
      'schoolId': schoolId,
      'kodeMapel': kodeMapel,
      'namaMapel': namaMapel,
      'kkm': kkm,
      'aktif': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubject({
    required String schoolId,
    required String subjectId,
  }) async {
    // 1. Cek apakah mapel terjadwal di kelas (class_schedules)
    final scheduledQuery = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('class_schedules')
        .where('subjectId', isEqualTo: subjectId)
        .limit(1)
        .get();

    if (scheduledQuery.docs.isNotEmpty) {
      throw Exception('Mata pelajaran tidak dapat dihapus karena sudah terjadwal di kelas.');
    }

    // 2. Cek apakah mapel diampu oleh guru (teacher_subjects)
    final teacherQuery = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('teacher_subjects')
        .where('subjectId', isEqualTo: subjectId)
        .limit(1)
        .get();

    if (teacherQuery.docs.isNotEmpty) {
      throw Exception('Mata pelajaran tidak dapat dihapus karena sudah menjadi pilihan diampu oleh guru.');
    }

    await _subjectsRef(schoolId).doc(subjectId).delete();
  }

  Future<void> updateSubject({
    required String schoolId,
    required String subjectId,
    required String namaMapel,
    required String kodeMapel,
    required int kkm,
  }) async {
    await _checkDuplicateOrSimilar(
      schoolId: schoolId,
      kodeMapel: kodeMapel,
      namaMapel: namaMapel,
      excludeSubjectId: subjectId,
    );

    await _subjectsRef(schoolId).doc(subjectId).update({
      'namaMapel': namaMapel,
      'kodeMapel': kodeMapel,
      'kkm': kkm,
    });
  }
}

