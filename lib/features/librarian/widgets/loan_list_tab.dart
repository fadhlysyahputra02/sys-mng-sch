import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../services/library_service.dart';
import '../../students/pages/student_qr_scanner_page.dart';

class LoanListTab extends StatefulWidget {
  final bool isDark;

  const LoanListTab({super.key, required this.isDark});

  @override
  State<LoanListTab> createState() => _LoanListTabState();
}

class _LoanListTabState extends State<LoanListTab> {
  final LibraryService _libraryService = LibraryService();
  String _searchQuery = '';

  // Form selections for Manual / QR Loan
  String? _selectedStudentId;
  String? _selectedStudentNis;
  String? _selectedStudentName;
  String? _selectedClassName;

  String? _selectedBookId;
  String? _selectedBookTitle;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));

  void _showNotification(String title, String message, bool isSuccess) {
    Get.snackbar(
      title,
      message,
      backgroundColor: isSuccess ? const Color(0xFF10B981) : Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _showBorrowDialog() {
    _selectedStudentId = null;
    _selectedStudentNis = null;
    _selectedStudentName = null;
    _selectedClassName = null;
    _selectedBookId = null;
    _selectedBookTitle = null;
    _dueDate = DateTime.now().add(const Duration(days: 7));

    String studentSearchQuery = '';
    String bookSearchQuery = '';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final dialogBg = widget.isDark ? const Color(0xFF1E1B4B) : Colors.white;
          final textColor = widget.isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = widget.isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1E1B4B).withOpacity(0.5);
          final fieldBorder = widget.isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12);
          final cardBg = widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02);

          // Handler for QR Scanning inside dialog
          void scanStudentQr() async {
            final result = await Get.to<String>(() => const StudentQrScannerPage(
                  title: 'Scan QR Peminjam',
                  subtitle: 'Arahkan kamera ke QR Kartu Siswa',
                ));

            if (result != null && result.isNotEmpty) {
              try {
                final Map<String, dynamic> payload = jsonDecode(result);
                setStateDialog(() {
                  _selectedStudentId = payload['studentId']?.toString() ?? '';
                  _selectedStudentNis = payload['nis']?.toString() ?? '';
                  _selectedStudentName = payload['nama']?.toString() ?? '';
                  _selectedClassName = payload['className']?.toString() ?? '-';
                });
                _showNotification('Berhasil', 'Siswa $_selectedStudentName teridentifikasi!', true);
              } catch (e) {
                _showNotification('Gagal', 'QR Code tidak dikenali.', false);
              }
            }
          }

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: fieldBorder),
            ),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peminjaman Buku Baru',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Isi data siswa dan pilih buku yang dipinjam.',
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                    const SizedBox(height: 20),

                    // --- SISWA SECTION ---
                    Text(
                      '1. Identitas Peminjam (Siswa)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedStudentId != null) ...[
                      // Display Selected Student Info Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_rounded, color: Color(0xFF6366F1)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedStudentName!,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                                  ),
                                  Text(
                                    'NIS: $_selectedStudentNis • Kelas: $_selectedClassName',
                                    style: TextStyle(color: subTextColor, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setStateDialog(() {
                                  _selectedStudentId = null;
                                  _selectedStudentName = null;
                                  _selectedStudentNis = null;
                                  _selectedClassName = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Search Student or Scan QR Button Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: textColor, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Cari nama siswa...',
                                hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (v) {
                                setStateDialog(() {
                                  studentSearchQuery = v.trim().toLowerCase();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: scanStudentQr,
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                            label: const Text('Scan', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Student Query Results
                      if (studentSearchQuery.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(color: fieldBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('schools')
                                .doc(LibraryService().schoolId)
                                .collection('students')
                                .snapshots(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                              final matched = snap.data!.docs.where((doc) {
                                final d = doc.data() as Map<String, dynamic>;
                                final nama = (d['nama'] ?? '').toString().toLowerCase();
                                return nama.contains(studentSearchQuery);
                              }).toList();

                              if (matched.isEmpty) {
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Siswa tidak ditemukan.', style: TextStyle(fontSize: 12)),
                                ));
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: matched.length,
                                itemBuilder: (c, idx) {
                                  final d = matched[idx].data() as Map<String, dynamic>;
                                  final sId = d['studentId'] ?? '';
                                  final sNis = d['nis'] ?? '-';
                                  final sName = d['nama'] ?? '-';
                                  final sClass = d['className'] ?? '-';

                                  return ListTile(
                                    dense: true,
                                    title: Text(sName, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    subtitle: Text('NIS: $sNis • Kelas: $sClass', style: TextStyle(color: subTextColor)),
                                    onTap: () {
                                      setStateDialog(() {
                                        _selectedStudentId = sId;
                                        _selectedStudentNis = sNis;
                                        _selectedStudentName = sName;
                                        _selectedClassName = sClass;
                                        studentSearchQuery = '';
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],

                    const SizedBox(height: 20),

                    // --- BUKU SECTION ---
                    Text(
                      '2. Buku Yang Dipinjam',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedBookId != null) ...[
                      // Display Selected Book Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bookmark_rounded, color: Color(0xFF10B981)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedBookTitle!,
                                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setStateDialog(() {
                                  _selectedBookId = null;
                                  _selectedBookTitle = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Book search field
                      TextField(
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari judul buku di perpus...',
                          hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          setStateDialog(() {
                            bookSearchQuery = v.trim().toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      // Book query results
                      if (bookSearchQuery.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          decoration: BoxDecoration(
                            border: Border.all(color: fieldBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _libraryService.getBooks(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                              final matched = snap.data!.docs.where((doc) {
                                final d = doc.data() as Map<String, dynamic>;
                                final judul = (d['judul'] ?? '').toString().toLowerCase();
                                final stok = d['stok'] as int? ?? 0;
                                return judul.contains(bookSearchQuery) && stok > 0;
                              }).toList();

                              if (matched.isEmpty) {
                                return const Center(child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Buku tidak ditemukan/stok habis.', style: TextStyle(fontSize: 12)),
                                ));
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                itemCount: matched.length,
                                itemBuilder: (c, idx) {
                                  final d = matched[idx].data() as Map<String, dynamic>;
                                  final bId = d['bookId'] ?? '';
                                  final bTitle = d['judul'] ?? '-';
                                  final bStok = d['stok'] ?? 0;

                                  return ListTile(
                                    dense: true,
                                    title: Text(bTitle, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                    subtitle: Text('Stok: $bStok Buku • Rak: ${d['rak'] ?? '-'}', style: TextStyle(color: subTextColor)),
                                    onTap: () {
                                      setStateDialog(() {
                                        _selectedBookId = bId;
                                        _selectedBookTitle = bTitle;
                                        bookSearchQuery = '';
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],

                    const SizedBox(height: 20),

                    // --- DEADLINE DATE SECTION ---
                    Text(
                      '3. Tanggal Batas Pengembalian',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: fieldBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _dueDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  _dueDate = picked;
                                });
                              }
                            },
                            child: const Text('Ubah Tanggal'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Actions row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('Batal', style: TextStyle(color: textColor.withOpacity(0.5))),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: (_selectedStudentId == null || _selectedBookId == null)
                              ? null
                              : () async {
                                  try {
                                    await _libraryService.borrowBook(
                                      studentId: _selectedStudentId!,
                                      studentNis: _selectedStudentNis!,
                                      studentName: _selectedStudentName!,
                                      className: _selectedClassName!,
                                      bookId: _selectedBookId!,
                                      bookTitle: _selectedBookTitle!,
                                      loanDate: DateTime.now(),
                                      dueDate: _dueDate,
                                    );
                                    _showNotification('Berhasil', 'Transaksi peminjaman dicatat.', true);
                                    Get.back();
                                  } catch (e) {
                                    _showNotification('Gagal', e.toString(), false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text(
                            'Simpan',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );
  }

  void _returnBook(String loanId, String bookId, String title, DateTime dueDate) async {
    final now = DateTime.now();
    final isLate = now.isAfter(dueDate);
    int lateDays = 0;
    double fine = 0.0;

    if (isLate) {
      lateDays = now.difference(dueDate).inDays;
      if (lateDays > 0) {
        fine = lateDays * 1000.0; // Denda Rp 1.000 per hari
      }
    }

    final dialogBg = widget.isDark ? const Color(0xFF1E1B4B) : Colors.white;
    final dialogBorder = widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1E1B4B);

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dialogBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('Pengembalian Buku', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin buku "$title" telah dikembalikan oleh siswa?',
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14),
            ),
            if (fine > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Terlambat Mengembalikan!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Terlambat $lateDays hari. Denda yang dikenakan:', style: const TextStyle(color: Colors.red, fontSize: 11)),
                          Text('Rp ${fine.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Batal',
              style: TextStyle(color: textColor.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Tandai Kembali', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _libraryService.returnBook(
          loanId: loanId,
          bookId: bookId,
          fine: fine,
        );
        _showNotification('Berhasil', 'Pengembalian buku dicatat.', true);
      } catch (e) {
        _showNotification('Gagal', e.toString(), false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = widget.isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF1E1B4B).withOpacity(0.6);
    final fieldFill = widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
    final fieldBorder = widget.isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12);
    final cardBg = widget.isDark ? Colors.white.withOpacity(0.04) : Colors.white;

    return Column(
      children: [
        // Action Bar (Search + Add Loan Button)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Cari peminjam, NIS, atau judul buku...',
                    hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
                    filled: true,
                    fillColor: fieldFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _searchQuery = v.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showBorrowDialog,
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                label: const Text('Pinjam Buku', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        // Loans List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _libraryService.getLoans(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 48, color: subTextColor.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text('Belum ada transaksi peminjaman.', style: TextStyle(color: subTextColor)),
                    ],
                  ),
                );
              }

              final loans = snapshot.data!.docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final name = (d['studentName'] ?? '').toString().toLowerCase();
                final nis = (d['studentNis'] ?? '').toString().toLowerCase();
                final title = (d['bookTitle'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) || nis.contains(_searchQuery) || title.contains(_searchQuery);
              }).toList();

              if (loans.isEmpty) {
                return Center(
                  child: Text('Transaksi tidak ditemukan.', style: TextStyle(color: subTextColor)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                itemCount: loans.length,
                itemBuilder: (context, index) {
                  final doc = loans[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  final studentName = data['studentName'] ?? '-';
                  final studentNis = data['studentNis'] ?? '-';
                  final className = data['className'] ?? '-';
                  final bookId = data['bookId'] ?? '';
                  final bookTitle = data['bookTitle'] ?? '-';
                  final loanDate = (data['loanDate'] as Timestamp?)?.toDate();
                  final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
                  final returnDate = (data['returnDate'] as Timestamp?)?.toDate();
                  final status = data['status'] ?? 'Dipinjam';
                  final fine = data['fine'] as double? ?? 0.0;

                  final bool isOverdue = status == 'Dipinjam' && dueDate != null && DateTime.now().isAfter(dueDate);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOverdue ? Colors.red.withOpacity(0.3) : fieldBorder,
                      ),
                      boxShadow: widget.isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Book Title
                              Text(
                                bookTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Student Info
                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 14, color: subTextColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$studentName (NIS: $studentNis • Kelas $className)',
                                    style: TextStyle(fontSize: 12, color: subTextColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Date details
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 14, color: subTextColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pinjam: ${loanDate != null ? "${loanDate.day}/${loanDate.month}/${loanDate.year}" : "-"} • '
                                    'Tempo: ${dueDate != null ? "${dueDate.day}/${dueDate.month}/${dueDate.year}" : "-"}',
                                    style: TextStyle(fontSize: 12, color: subTextColor),
                                  ),
                                ],
                              ),

                              if (returnDate != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Kembali: ${returnDate.day}/${returnDate.month}/${returnDate.year}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                              ],

                              if (fine > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Denda Terbayar: Rp ${fine.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Status Badge or Return Action
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (status == 'Kembali'
                                    ? const Color(0xFF10B981)
                                    : (isOverdue ? Colors.red : Colors.orange)).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status == 'Kembali' ? 'Kembali' : (isOverdue ? 'Terlambat' : 'Dipinjam'),
                                style: TextStyle(
                                  color: status == 'Kembali'
                                      ? const Color(0xFF10B981)
                                      : (isOverdue ? Colors.red : Colors.orange),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (status == 'Dipinjam') ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _returnBook(id, bookId, bookTitle, dueDate!),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text(
                                  'Kembalikan',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
