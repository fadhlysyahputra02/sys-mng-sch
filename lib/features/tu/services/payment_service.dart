import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a master bill and automatically assign student_bills to all targeted students.
  Future<void> createBill({
    required String schoolId,
    required String title,
    required double amount,
    required DateTime dueDate,
    required String description,
    String? classId,
    String? className,
  }) async {
    // 1. Create Master Bill document
    final billRef = _firestore.collection('schools').doc(schoolId).collection('bills').doc();
    final billId = billRef.id;

    final masterBillData = {
      'id': billId,
      'title': title,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'description': description,
      'classId': classId,
      'className': className,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await billRef.set(masterBillData);

    // 2. Query targeted students
    Query<Map<String, dynamic>> studentsQuery = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students');

    if (classId != null && classId.isNotEmpty) {
      studentsQuery = studentsQuery.where('classId', isEqualTo: classId);
    }

    final studentsSnapshot = await studentsQuery.get();

    // 3. Create student_bills and personal notifications in batches of 400
    int count = 0;
    WriteBatch batch = _firestore.batch();
    final String formattedAmount = _formatRupiah(amount);

    for (var studentDoc in studentsSnapshot.docs) {
      final studentData = studentDoc.data();
      final studentUid = studentData['uid'] as String?;
      final studentLang = studentData['language'] as String? ?? 'id';
      final parentUid = studentData['parentId'] as String?;

      final studentBillRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('student_bills')
          .doc();

      final studentBillData = {
        'id': studentBillRef.id,
        'billId': billId,
        'title': title,
        'amount': amount,
        'dueDate': Timestamp.fromDate(dueDate),
        'description': description,
        'studentId': studentDoc.id,
        'studentName': studentData['nama'] ?? 'Murid',
        'classId': studentData['classId'],
        'className': studentData['className'] ?? className ?? '-',
        'status': 'unpaid', // unpaid, pending, paid
        'paymentMethod': null,
        'buktiBase64': null,
        'rejectionReason': null,
        'uploadedAt': null,
        'verifiedAt': null,
        'verifiedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      batch.set(studentBillRef, studentBillData);
      count++;

      // Kirim notifikasi personal ke murid
      if (studentUid != null && studentUid.isNotEmpty) {
        final notifTitle = studentLang == 'en' ? 'New Bill' : 'Tagihan Baru';
        final notifContent = studentLang == 'en'
            ? 'New bill "$title" of $formattedAmount has been issued.'
            : 'Tagihan baru "$title" sebesar $formattedAmount telah diterbitkan.';

        final studentNotifRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('notifications')
            .doc();

        batch.set(studentNotifRef, {
          'title': notifTitle,
          'content': notifContent,
          'targetType': 'personal',
          'targetId': studentUid,
          'targetName': studentData['nama'] ?? 'Murid',
          'senderId': 'tu_system',
          'senderName': 'Bagian Keuangan',
          'senderRole': 'tu',
          'category': 'payment',
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }

      // Kirim notifikasi personal ke orang tua (jika terhubung)
      if (parentUid != null && parentUid.isNotEmpty) {
        final parentNotifRef = _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('notifications')
            .doc();

        batch.set(parentNotifRef, {
          'title': 'Tagihan Baru',
          'content': 'Tagihan baru "$title" untuk anak Anda ${studentData['nama'] ?? "Murid"} sebesar $formattedAmount telah diterbitkan.',
          'targetType': 'personal',
          'targetId': parentUid,
          'targetName': 'Orang Tua ${studentData['nama'] ?? "Murid"}',
          'senderId': 'tu_system',
          'senderName': 'Bagian Keuangan',
          'senderRole': 'tu',
          'category': 'payment',
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }

      if (count >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
    }
  }

  /// Stream of master bills
  Stream<QuerySnapshot<Map<String, dynamic>>> getBills(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream of bills for a specific student
  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentBills(
    String schoolId,
    String studentId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('student_bills')
        .where('studentId', isEqualTo: studentId)
        .snapshots();
  }

  /// Stream of pending student bills (for TU verification)
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingStudentBills(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('student_bills')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// Stream of all student bills (for TU overview/reports)
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllStudentBills(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('student_bills')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Upload payment receipt base64 and change status to pending
  Future<void> uploadReceipt({
    required String schoolId,
    required String studentBillId,
    required String buktiBase64,
    required String paymentMethod,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('student_bills')
        .doc(studentBillId)
        .update({
      'status': 'pending',
      'buktiBase64': buktiBase64,
      'paymentMethod': paymentMethod,
      'uploadedAt': FieldValue.serverTimestamp(),
      'rejectionReason': null, // Reset rejection reason on re-upload
    });
  }

  /// Verify and update student bill status (paid or unpaid with reason)
  Future<void> updateStudentBillStatus({
    required String schoolId,
    required String studentBillId,
    required String status,
    String? verifiedBy,
    String? rejectionReason,
    String? paymentMethod,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status,
    };

    if (status == 'paid') {
      updates['verifiedAt'] = FieldValue.serverTimestamp();
      updates['verifiedBy'] = verifiedBy;
      if (paymentMethod != null) {
        updates['paymentMethod'] = paymentMethod;
      }
    } else if (status == 'unpaid') {
      updates['rejectionReason'] = rejectionReason;
      updates['buktiBase64'] = null; // Clear rejected proof so they can re-upload
      updates['paymentMethod'] = null;
      updates['uploadedAt'] = null;
    }

    // Ambil data sebelum update untuk kebutuhan notifikasi
    DocumentSnapshot<Map<String, dynamic>>? billDoc;
    try {
      billDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('student_bills')
          .doc(studentBillId)
          .get();
    } catch (_) {}

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('student_bills')
        .doc(studentBillId)
        .update(updates);

    if (billDoc != null && billDoc.exists) {
      final billData = billDoc.data();
      if (billData != null) {
        final String studentId = billData['studentId'] ?? '';
        final String billTitle = billData['title'] ?? 'Tagihan';
        final String studentName = billData['studentName'] ?? 'Murid';

        if (studentId.isNotEmpty) {
          try {
            final studentDoc = await _firestore
                .collection('schools')
                .doc(schoolId)
                .collection('students')
                .doc(studentId)
                .get();

            if (studentDoc.exists) {
              final studentUid = studentDoc.data()?['uid'];
              final parentUid = studentDoc.data()?['parentId'];

              // Ambil bahasa preferensi murid
              String studentLang = 'id';
              if (studentUid != null && studentUid.toString().isNotEmpty) {
                try {
                  final userDoc = await _firestore.collection('users').doc(studentUid.toString()).get();
                  if (userDoc.exists) {
                    studentLang = userDoc.data()?['language'] ?? 'id';
                  }
                } catch (_) {}
              }

              // Ambil bahasa preferensi orang tua
              String parentLang = 'id';
              if (parentUid != null && parentUid.toString().isNotEmpty) {
                try {
                  final userDoc = await _firestore.collection('users').doc(parentUid.toString()).get();
                  if (userDoc.exists) {
                    parentLang = userDoc.data()?['language'] ?? 'id';
                  }
                } catch (_) {}
              }

              // Tentukan pesan untuk murid
              final studentTitle = studentLang == 'en'
                  ? (status == 'paid' ? 'Payment Approved' : 'Payment Rejected')
                  : (status == 'paid' ? 'Pembayaran Lunas' : 'Pembayaran Ditolak');

              final studentContent = studentLang == 'en'
                  ? (status == 'paid'
                      ? 'Payment for "$billTitle" has been verified and marked as PAID.'
                      : 'Payment for "$billTitle" has been REJECTED. Reason: ${rejectionReason ?? "-"}')
                  : (status == 'paid'
                      ? 'Pembayaran untuk "$billTitle" telah diverifikasi dan dinyatakan LUNAS.'
                      : 'Pembayaran untuk "$billTitle" DITOLAK. Alasan: ${rejectionReason ?? "-"}');

              // Tentukan pesan untuk orang tua
              final parentTitle = parentLang == 'en'
                  ? (status == 'paid' ? 'Payment Approved' : 'Payment Rejected')
                  : (status == 'paid' ? 'Pembayaran Lunas' : 'Pembayaran Ditolak');

              final parentContent = parentLang == 'en'
                  ? (status == 'paid'
                      ? 'Payment for "$billTitle" has been verified and marked as PAID.'
                      : 'Payment for "$billTitle" has been REJECTED. Reason: ${rejectionReason ?? "-"}')
                  : (status == 'paid'
                      ? 'Pembayaran untuk "$billTitle" telah diverifikasi dan dinyatakan LUNAS.'
                      : 'Pembayaran untuk "$billTitle" DITOLAK. Alasan: ${rejectionReason ?? "-"}');

              // Kirim notifikasi ke murid
              if (studentUid != null && studentUid.toString().isNotEmpty) {
                await _firestore
                    .collection('schools')
                    .doc(schoolId)
                    .collection('notifications')
                    .add({
                  'title': studentTitle,
                  'content': studentContent,
                  'targetType': 'personal',
                  'targetId': studentUid,
                  'targetName': studentName,
                  'senderId': 'tu_system',
                  'senderName': verifiedBy ?? 'Petugas TU',
                  'senderRole': 'tu',
                  'category': 'payment',
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }

              // Kirim notifikasi ke orang tua (jika terhubung)
              if (parentUid != null && parentUid.toString().isNotEmpty) {
                await _firestore
                    .collection('schools')
                    .doc(schoolId)
                    .collection('notifications')
                    .add({
                  'title': parentTitle,
                  'content': parentContent,
                  'targetType': 'personal',
                  'targetId': parentUid,
                  'targetName': 'Orang Tua $studentName',
                  'senderId': 'tu_system',
                  'senderName': verifiedBy ?? 'Petugas TU',
                  'senderRole': 'tu',
                  'category': 'payment',
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
            }
          } catch (e) {
            print('Gagal mengirim notifikasi pembayaran: $e');
          }
        }
      }
    }
  }

  String _formatRupiah(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }
}
