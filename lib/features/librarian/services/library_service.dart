import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/session_service.dart';

class LibraryService {
  final _db = FirebaseFirestore.instance;

  String get schoolId => SessionService.currentUser?.schoolId ?? '';

  // Helpers for references
  CollectionReference<Map<String, dynamic>> get _booksRef => _db
      .collection('schools')
      .doc(schoolId)
      .collection('library_books');

  CollectionReference<Map<String, dynamic>> get _loansRef => _db
      .collection('schools')
      .doc(schoolId)
      .collection('library_loans');

  CollectionReference<Map<String, dynamic>> get _visitorsRef => _db
      .collection('schools')
      .doc(schoolId)
      .collection('library_visitors');

  // --- BOOK OPERATIONS ---

  Stream<QuerySnapshot<Map<String, dynamic>>> getBooks() {
    return _booksRef.orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> addBook({
    required String judul,
    required String pengarang,
    required String penerbit,
    required String tahun,
    required String isbn,
    required int stok,
    required String rak,
  }) async {
    if (schoolId.isEmpty) throw 'Sekolah tidak teridentifikasi';

    final doc = _booksRef.doc();
    await doc.set({
      'bookId': doc.id,
      'judul': judul,
      'pengarang': pengarang,
      'penerbit': penerbit,
      'tahun': tahun,
      'isbn': isbn,
      'stok': stok,
      'rak': rak,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBook({
    required String bookId,
    required String judul,
    required String pengarang,
    required String penerbit,
    required String tahun,
    required String isbn,
    required int stok,
    required String rak,
  }) async {
    await _booksRef.doc(bookId).update({
      'judul': judul,
      'pengarang': pengarang,
      'penerbit': penerbit,
      'tahun': tahun,
      'isbn': isbn,
      'stok': stok,
      'rak': rak,
    });
  }

  Future<void> deleteBook(String bookId) async {
    await _booksRef.doc(bookId).delete();
  }

  // --- VISITOR LOG OPERATIONS ---

  Stream<QuerySnapshot<Map<String, dynamic>>> getVisitors() {
    return _visitorsRef.orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> recordVisitor({
    required String studentId,
    required String studentNis,
    required String studentName,
    required String className,
  }) async {
    if (schoolId.isEmpty) throw 'Sekolah tidak teridentifikasi';

    final doc = _visitorsRef.doc();
    await doc.set({
      'visitorId': doc.id,
      'studentId': studentId,
      'studentNis': studentNis,
      'studentName': studentName,
      'className': className,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- LOAN OPERATIONS ---

  Stream<QuerySnapshot<Map<String, dynamic>>> getLoans() {
    return _loansRef.orderBy('loanDate', descending: true).snapshots();
  }

  Future<void> borrowBook({
    required String studentId,
    required String studentNis,
    required String studentName,
    required String className,
    required String bookId,
    required String bookTitle,
    required DateTime loanDate,
    required DateTime dueDate,
  }) async {
    if (schoolId.isEmpty) throw 'Sekolah tidak teridentifikasi';

    final bookDocRef = _booksRef.doc(bookId);

    // Gunakan Transaction untuk memastikan stok buku berkurang secara aman
    await _db.runTransaction((transaction) async {
      final bookSnap = await transaction.get(bookDocRef);
      if (!bookSnap.exists) throw 'Buku tidak ditemukan';

      final currentStock = bookSnap.data()?['stok'] as int? ?? 0;
      if (currentStock <= 0) throw 'Stok buku habis';

      final loanDocRef = _loansRef.doc();
      transaction.set(loanDocRef, {
        'loanId': loanDocRef.id,
        'studentId': studentId,
        'studentNis': studentNis,
        'studentName': studentName,
        'className': className,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'loanDate': Timestamp.fromDate(loanDate),
        'dueDate': Timestamp.fromDate(dueDate),
        'returnDate': null,
        'status': 'Dipinjam',
        'fine': 0.0,
      });

      transaction.update(bookDocRef, {'stok': currentStock - 1});
    });
  }

  Future<void> returnBook({
    required String loanId,
    required String bookId,
    required double fine,
  }) async {
    final loanDocRef = _loansRef.doc(loanId);
    final bookDocRef = _booksRef.doc(bookId);

    await _db.runTransaction((transaction) async {
      final loanSnap = await transaction.get(loanDocRef);
      if (!loanSnap.exists) throw 'Peminjaman tidak ditemukan';
      if (loanSnap.data()?['status'] == 'Kembali') throw 'Buku sudah dikembalikan sebelumnya';

      final bookSnap = await transaction.get(bookDocRef);
      if (!bookSnap.exists) throw 'Buku tidak ditemukan';

      final currentStock = bookSnap.data()?['stok'] as int? ?? 0;

      transaction.update(loanDocRef, {
        'returnDate': FieldValue.serverTimestamp(),
        'status': 'Kembali',
        'fine': fine,
      });

      transaction.update(bookDocRef, {'stok': currentStock + 1});
    });
  }
}
