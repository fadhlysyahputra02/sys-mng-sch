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

    // 3. Create student_bills in batches of 400 (to avoid Firestore batch write limit of 500)
    int count = 0;
    WriteBatch batch = _firestore.batch();

    for (var studentDoc in studentsSnapshot.docs) {
      final studentData = studentDoc.data();
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

    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('student_bills')
        .doc(studentBillId)
        .update(updates);
  }
}
