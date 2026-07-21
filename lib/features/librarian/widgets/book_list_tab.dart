import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../services/library_service.dart';
import '../../../core/localization/app_localization.dart';

class BookListTab extends StatefulWidget {
  final bool isDark;

  const BookListTab({super.key, required this.isDark});

  @override
  State<BookListTab> createState() => _BookListTabState();
}

class _BookListTabState extends State<BookListTab> {
  final LibraryService _libraryService = LibraryService();
  final _formKey = GlobalKey<FormState>();

  final _judulController = TextEditingController();
  final _pengarangController = TextEditingController();
  final _penerbitController = TextEditingController();
  final _tahunController = TextEditingController();
  final _isbnController = TextEditingController();
  final _stokController = TextEditingController();
  final _rakController = TextEditingController();

  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _judulController.dispose();
    _pengarangController.dispose();
    _penerbitController.dispose();
    _tahunController.dispose();
    _isbnController.dispose();
    _stokController.dispose();
    _rakController.dispose();
    super.dispose();
  }

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

  void _showBookDialog({String? bookId, Map<String, dynamic>? initialData}) {
    String? selectedKlasifikasi = 'Umum';
    if (initialData != null) {
      _judulController.text = initialData['judul'] ?? '';
      _pengarangController.text = initialData['pengarang'] ?? '';
      _penerbitController.text = initialData['penerbit'] ?? '';
      _tahunController.text = initialData['tahun'] ?? '';
      _isbnController.text = initialData['isbn'] ?? '';
      _stokController.text = (initialData['stok'] ?? 0).toString();
      _rakController.text = initialData['rak'] ?? '';
      selectedKlasifikasi = initialData['klasifikasi'] ?? 'Umum';
    } else {
      _judulController.clear();
      _pengarangController.clear();
      _penerbitController.clear();
      _tahunController.clear();
      _isbnController.clear();
      _stokController.clear();
      _rakController.clear();
    }

    final isEdit = bookId != null;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final dialogBg = widget.isDark ? const Color(0xFF1E1B4B) : Colors.white;
          final textColor = widget.isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = widget.isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1E1B4B).withOpacity(0.5);
          final fieldFill = widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
          final fieldBorder = widget.isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12);

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: fieldBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit
                            ? (AppLocalization.isIndonesian ? 'Ubah Informasi Buku' : 'Edit Book Info')
                            : (AppLocalization.isIndonesian ? 'Tambah Buku Baru' : 'Add New Book'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEdit
                            ? (AppLocalization.isIndonesian ? 'Perbarui detail data katalog buku.' : 'Update book catalog details.')
                            : (AppLocalization.isIndonesian ? 'Isi formulir untuk menambahkan buku ke perpustakaan.' : 'Fill the form to add a book to the library.'),
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                      const SizedBox(height: 20),

                      // Judul
                      _buildTextField(
                        controller: _judulController,
                        label: AppLocalization.isIndonesian ? 'Judul Buku' : 'Book Title',
                        icon: Icons.title_rounded,
                        isDark: widget.isDark,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? (AppLocalization.isIndonesian ? 'Judul buku wajib diisi' : 'Book title is required')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      // Pengarang & Penerbit in Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _pengarangController,
                              label: AppLocalization.isIndonesian ? 'Pengarang' : 'Author',
                              icon: Icons.person_outline_rounded,
                              isDark: widget.isDark,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? (AppLocalization.isIndonesian ? 'Wajib diisi' : 'Required')
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _penerbitController,
                              label: AppLocalization.isIndonesian ? 'Penerbit' : 'Publisher',
                              icon: Icons.business_rounded,
                              isDark: widget.isDark,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? (AppLocalization.isIndonesian ? 'Wajib diisi' : 'Required')
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tahun & ISBN in Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _tahunController,
                              label: AppLocalization.isIndonesian ? 'Tahun Terbit' : 'Publish Year',
                              icon: Icons.calendar_today_rounded,
                              keyboardType: TextInputType.number,
                              isDark: widget.isDark,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? (AppLocalization.isIndonesian ? 'Wajib diisi' : 'Required')
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _isbnController,
                              label: 'ISBN',
                              icon: Icons.qr_code_rounded,
                              isDark: widget.isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Stok & Rak in Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _stokController,
                              label: AppLocalization.isIndonesian ? 'Stok (Jumlah)' : 'Stock (Quantity)',
                              icon: Icons.inventory_2_outlined,
                              keyboardType: TextInputType.number,
                              isDark: widget.isDark,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return AppLocalization.isIndonesian ? 'Wajib diisi' : 'Required';
                                }
                                if (int.tryParse(v) == null) {
                                  return AppLocalization.isIndonesian ? 'Harus angka' : 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _rakController,
                              label: AppLocalization.isIndonesian ? 'Lokasi Rak' : 'Shelf Location',
                              icon: Icons.grid_view_rounded,
                              isDark: widget.isDark,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? (AppLocalization.isIndonesian ? 'Wajib diisi' : 'Required')
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Klasifikasi
                      DropdownButtonFormField<String>(
                        dropdownColor: widget.isDark ? const Color(0xFF1E1B4B) : Colors.white,
                        value: selectedKlasifikasi,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: AppLocalization.isIndonesian ? 'Klasifikasi Buku' : 'Book Classification',
                          labelStyle: TextStyle(color: subTextColor, fontSize: 13),
                          filled: true,
                          fillColor: fieldFill,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: fieldBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          prefixIcon: Icon(Icons.category_rounded, color: const Color(0xFF6366F1), size: 20),
                        ),
                        items: ['Matematika', 'Sains', 'Umum', 'Seni', 'Other'].map((k) {
                          String display = k;
                          if (!AppLocalization.isIndonesian) {
                            if (k == 'Matematika') display = 'Mathematics';
                            if (k == 'Sains') display = 'Science';
                            if (k == 'Umum') display = 'General';
                            if (k == 'Seni') display = 'Arts';
                          }
                          return DropdownMenuItem<String>(
                            value: k,
                            child: Text(display, style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedKlasifikasi = val;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : () => Get.back(),
                            child: Text(
                              AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                              style: TextStyle(color: textColor.withOpacity(0.5)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    if (!_formKey.currentState!.validate()) return;
                                    setStateDialog(() => _isLoading = true);

                                    try {
                                      final judul = _judulController.text.trim();
                                      final pengarang = _pengarangController.text.trim();
                                      final penerbit = _penerbitController.text.trim();
                                      final tahun = _tahunController.text.trim();
                                      final isbn = _isbnController.text.trim();
                                      final stok = int.parse(_stokController.text.trim());
                                      final rak = _rakController.text.trim();

                                      if (isEdit) {
                                        await _libraryService.updateBook(
                                          bookId: bookId,
                                          judul: judul,
                                          pengarang: pengarang,
                                          penerbit: penerbit,
                                          tahun: tahun,
                                          isbn: isbn,
                                          stok: stok,
                                          rak: rak,
                                          klasifikasi: selectedKlasifikasi ?? 'Umum',
                                        );
                                        _showNotification(
                                          AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
                                          AppLocalization.isIndonesian ? 'Informasi buku berhasil diperbarui.' : 'Book information updated successfully.',
                                          true,
                                        );
                                      } else {
                                        await _libraryService.addBook(
                                          judul: judul,
                                          pengarang: pengarang,
                                          penerbit: penerbit,
                                          tahun: tahun,
                                          isbn: isbn,
                                          stok: stok,
                                          rak: rak,
                                          klasifikasi: selectedKlasifikasi ?? 'Umum',
                                        );
                                        _showNotification(
                                          AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
                                          AppLocalization.isIndonesian ? 'Buku baru berhasil terdaftar.' : 'New book registered successfully.',
                                          true,
                                        );
                                      }
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                    } catch (e) {
                                      _showNotification(
                                        AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
                                        e.toString(),
                                        false,
                                      );
                                    } finally {
                                      setStateDialog(() => _isLoading = false);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    isEdit
                                        ? (AppLocalization.isIndonesian ? 'Perbarui' : 'Update')
                                        : (AppLocalization.isIndonesian ? 'Simpan' : 'Save'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
      barrierDismissible: false,
    );
  }

  void _deleteBook(String bookId, String judul) async {
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              AppLocalization.isIndonesian ? 'Hapus Buku' : 'Delete Book',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          AppLocalization.isIndonesian
              ? 'Apakah Anda yakin ingin menghapus buku "$judul" dari katalog perpustakaan?'
              : 'Are you sure you want to delete book "$judul" from the library catalog?',
          style: TextStyle(color: textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
              style: TextStyle(color: textColor.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              AppLocalization.isIndonesian ? 'Hapus' : 'Delete',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _libraryService.deleteBook(bookId);
        _showNotification(
          AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
          AppLocalization.isIndonesian ? 'Buku "$judul" berhasil dihapus.' : 'Book "$judul" successfully deleted.',
          true,
        );
      } catch (e) {
        _showNotification(
          AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
          e.toString(),
          false,
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subTextColor = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1E1B4B).withOpacity(0.5);
    final fieldFill = isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02);
    final fieldBorder = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12);

    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 14),
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        prefixIcon: Icon(icon, color: subTextColor, size: 18),
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
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
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
        // Action Bar (Search + Add Button)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLocalization.isIndonesian
                        ? 'Cari judul, pengarang, atau ISBN...'
                        : 'Search title, author, or ISBN...',
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
                onPressed: () => _showBookDialog(),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: Text(
                  AppLocalization.isIndonesian ? 'Buku' : 'Book',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        // Catalog List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _libraryService.getBooks(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 48, color: subTextColor.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalization.isIndonesian ? 'Belum ada buku terdaftar.' : 'No books registered yet.',
                        style: TextStyle(color: subTextColor),
                      ),
                    ],
                  ),
                );
              }

              final books = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final judul = (data['judul'] ?? '').toString().toLowerCase();
                final pengarang = (data['pengarang'] ?? '').toString().toLowerCase();
                final isbn = (data['isbn'] ?? '').toString().toLowerCase();
                return judul.contains(_searchQuery) ||
                    pengarang.contains(_searchQuery) ||
                    isbn.contains(_searchQuery);
              }).toList();

              if (books.isEmpty) {
                return Center(
                  child: Text(
                    AppLocalization.isIndonesian ? 'Buku tidak ditemukan.' : 'Book not found.',
                    style: TextStyle(color: subTextColor),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final doc = books[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  final judul = data['judul'] ?? '-';
                  final pengarang = data['pengarang'] ?? '-';
                  final penerbit = data['penerbit'] ?? '-';
                  final tahun = data['tahun'] ?? '-';
                  final isbn = data['isbn'] ?? '';
                  final stok = data['stok'] as int? ?? 0;
                  final rak = data['rak'] ?? '-';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: fieldBorder),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Placeholder
                        Container(
                          width: 55,
                          height: 75,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                judul,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${AppLocalization.isIndonesian ? 'Pengarang' : 'Author'}: $pengarang',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                              Text(
                                '${AppLocalization.isIndonesian ? 'Penerbit' : 'Publisher'}: $penerbit ($tahun)',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                              if (isbn.isNotEmpty)
                                Text(
                                  'ISBN: $isbn',
                                  style: TextStyle(fontSize: 11, color: subTextColor.withOpacity(0.8)),
                                ),
                              const SizedBox(height: 10),

                              // Badges Row
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (stok > 0 ? const Color(0xFF10B981) : Colors.red).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      stok > 0
                                          ? (AppLocalization.isIndonesian ? 'Stok: $stok Buku' : 'Stock: $stok Books')
                                          : (AppLocalization.isIndonesian ? 'Stok Habis' : 'Out of Stock'),
                                      style: TextStyle(
                                        color: stok > 0 ? const Color(0xFF10B981) : Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${AppLocalization.isIndonesian ? 'Rak' : 'Shelf'}: $rak',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      data['klasifikasi'] ?? 'Umum',
                                      style: const TextStyle(
                                        color: Color(0xFF6366F1),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Edit / Delete actions
                        Column(
                          children: [
                            IconButton(
                              onPressed: () => _showBookDialog(bookId: id, initialData: data),
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                              tooltip: AppLocalization.isIndonesian ? 'Edit Buku' : 'Edit Book',
                            ),
                            IconButton(
                              onPressed: () => _deleteBook(id, judul),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              tooltip: AppLocalization.isIndonesian ? 'Hapus Buku' : 'Delete Book',
                            ),
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
