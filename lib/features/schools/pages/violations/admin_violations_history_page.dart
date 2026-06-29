import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../../../students/data/student_service.dart';

class AdminViolationsHistoryPage extends StatefulWidget {
  final bool hideBackButton;
  const AdminViolationsHistoryPage({super.key, this.hideBackButton = false});

  @override
  State<AdminViolationsHistoryPage> createState() => _AdminViolationsHistoryPageState();
}

class _AdminViolationsHistoryPageState extends State<AdminViolationsHistoryPage> {
  final _studentService = StudentService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedClassFilter = 'Semua Kelas';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, String schoolId, String violationId) async {
    final isDark = AuthBackground.isDarkMode.value;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 10),
            Text(
              'Hapus Catatan',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus catatan pelanggaran ini? Poin murid akan kembali normal.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _studentService.deleteViolation(schoolId, violationId);
        Get.snackbar(
          'Sukses',
          'Catatan pelanggaran berhasil dihapus.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Gagal menghapus pelanggaran: $e',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              bottom: false,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    automaticallyImplyLeading: !widget.hideBackButton,
                    leading: widget.hideBackButton
                        ? null
                        : Container(
                            margin: const EdgeInsets.only(left: 16),
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                    title: Text(
                      'Riwayat Pelanggaran Murid',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                    ),
                  ),

                  // Search and Filter Header Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          // Search Input
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Cari nama murid...',
                              hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                              prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear_rounded, color: subTextColor, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              fillColor: inputFillColor,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: cardBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Class Filter Stream
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('schools')
                                .doc(schoolId)
                                .collection('classes')
                                .snapshots(),
                            builder: (context, snapshot) {
                              final classes = snapshot.data?.docs.map((doc) => doc.data()['namaKelas'] as String).toList() ?? [];
                              classes.sort((a, b) => a.compareTo(b));
                              final classOptions = ['Semua Kelas', ...classes];

                              // Safe check in case class options is empty or value changes
                              if (!classOptions.contains(_selectedClassFilter)) {
                                _selectedClassFilter = 'Semua Kelas';
                              }

                              return DropdownButtonFormField<String>(
                                dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                style: TextStyle(color: textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  fillColor: inputFillColor,
                                  filled: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                value: _selectedClassFilter,
                                items: classOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt,
                                    child: Text(opt),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClassFilter = val!;
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Violations list
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _studentService.getViolationsBySchool(schoolId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(color: isDark ? Colors.white : const Color(0xFF8B5CF6)),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      
                      // Filter locally
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data();
                        final studentName = (data['studentName'] ?? '').toString().toLowerCase();
                        final className = (data['className'] ?? '').toString();
                        
                        final matchesSearch = studentName.contains(_searchQuery);
                        final matchesClass = _selectedClassFilter == 'Semua Kelas' || className == _selectedClassFilter;

                        return matchesSearch && matchesClass;
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 64,
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada catatan pelanggaran murid.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: subTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data();
                              final date = data['date'] != null ? (data['date'] as Timestamp).toDate() : null;
                              final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
                              final poin = data['poin'] ?? 0;
                              final studentName = data['studentName'] ?? 'Murid';
                              final className = data['className'] ?? 'Kelas';
                              final jenis = data['jenis'] ?? 'Pelanggaran';
                              final keterangan = data['keterangan'] ?? '';
                              final recordedBy = data['recordedBy'] ?? '-';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorderColor),
                                  boxShadow: isDark ? [] : [
                                    BoxShadow(
                                      color: shadowColor,
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            studentName,
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '-$poin Poin',
                                          style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Kelas: $className',
                                      style: TextStyle(color: subTextColor, fontSize: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(color: cardBorderColor, height: 1),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(Icons.report_rounded, color: Color(0xFFEF4444), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            jenis,
                                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (keterangan.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 26),
                                        child: Text(
                                          keterangan,
                                          style: TextStyle(color: subTextColor, fontSize: 12, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Divider(color: cardBorderColor, height: 1),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Oleh: $recordedBy • $dateStr',
                                          style: TextStyle(color: subTextColor, fontSize: 11),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          onPressed: () => _confirmDelete(context, schoolId, doc.id),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: filteredDocs.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
