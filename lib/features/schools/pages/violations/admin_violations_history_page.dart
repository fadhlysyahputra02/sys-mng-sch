import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../../../students/data/student_service.dart';
import '../../../../core/localization/app_localization.dart';

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
  int _selectedTab = 0; // 0: History, 1: Leaderboard

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
              AppLocalization.isIndonesian ? 'Hapus Catatan' : 'Delete Record',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          AppLocalization.isIndonesian
              ? 'Apakah Anda yakin ingin menghapus catatan pelanggaran ini? Poin murid akan kembali normal.'
              : 'Are you sure you want to delete this violation record? Student points will return to normal.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppLocalization.cancelButton,
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
            child: Text(AppLocalization.isIndonesian ? 'Hapus' : 'Delete', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _studentService.deleteViolation(schoolId, violationId);
        Get.snackbar(
          AppLocalization.isIndonesian ? 'Sukses' : 'Success',
          AppLocalization.isIndonesian ? 'Catatan pelanggaran berhasil dihapus.' : 'Violation record successfully deleted.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          '${AppLocalization.isIndonesian ? "Gagal menghapus pelanggaran" : "Failed to delete violation"}: $e',
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
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
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
                      AppLocalization.isIndonesian ? 'Riwayat Pelanggaran Murid' : 'Student Violations History',
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
                              hintText: AppLocalization.isIndonesian ? 'Cari nama murid...' : 'Search student name...',
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
                                    child: Text(opt == 'Semua Kelas' ? (AppLocalization.isIndonesian ? 'Semua Kelas' : 'All Classes') : opt),
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
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: inputFillColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedTab = 0;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 0
                                            ? const Color(0xFF8B5CF6)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          AppLocalization.isIndonesian ? 'Riwayat Pelanggaran' : 'Violations History',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTab == 0
                                                ? Colors.white
                                                : textColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedTab = 1;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 1
                                            ? const Color(0xFF8B5CF6)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          AppLocalization.isIndonesian ? 'Poin Tertinggi' : 'Highest Points',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedTab == 1
                                                ? Colors.white
                                                : textColor.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                  _selectedTab == 0
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.emoji_events_outlined,
                                  size: 64,
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedTab == 0
                                      ? (AppLocalization.isIndonesian ? 'Tidak ada catatan pelanggaran murid.' : 'No student violation records.')
                                      : (AppLocalization.isIndonesian ? 'Tidak ada peringkat poin pelanggaran.' : 'No violation points ranking.'),
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

                      if (_selectedTab == 1) {
                        final Map<String, _StudentPoints> studentPointsMap = {};
                        for (final doc in filteredDocs) {
                          final data = doc.data();
                          final studentId = data['studentId'] as String? ?? '';
                          final studentName = data['studentName'] as String? ?? 'Murid';
                          final className = data['className'] as String? ?? 'Kelas';
                          final poin = data['poin'] as int? ?? 0;
                          
                          if (studentId.isNotEmpty) {
                            if (studentPointsMap.containsKey(studentId)) {
                              final existing = studentPointsMap[studentId]!;
                              studentPointsMap[studentId] = _StudentPoints(
                                studentId: studentId,
                                studentName: existing.studentName,
                                className: existing.className,
                                totalPoints: existing.totalPoints + poin,
                              );
                            } else {
                              studentPointsMap[studentId] = _StudentPoints(
                                studentId: studentId,
                                studentName: studentName,
                                className: className,
                                totalPoints: poin,
                              );
                            }
                          }
                        }

                        final leaderboard = studentPointsMap.values.toList()
                          ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = leaderboard[index];
                                final rank = index + 1;
                                final Color rankColor;
                                if (rank == 1) {
                                  rankColor = const Color(0xFFF59E0B);
                                } else if (rank == 2) {
                                  rankColor = const Color(0xFF94A3B8);
                                } else if (rank == 3) {
                                  rankColor = const Color(0xFFB45309);
                                } else {
                                  rankColor = textColor.withValues(alpha: 0.6);
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: rank <= 3
                                              ? rankColor.withValues(alpha: 0.15)
                                              : Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$rank',
                                            style: TextStyle(
                                              color: rankColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.studentName,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              '${AppLocalization.isIndonesian ? "Kelas" : "Class"}: ${item.className}',
                                              style: TextStyle(
                                                color: subTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '-${item.totalPoints} ${AppLocalization.isIndonesian ? "Poin" : "Points"}',
                                          style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: leaderboard.length,
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
                                          '-$poin ${AppLocalization.isIndonesian ? "Poin" : "Points"}',
                                          style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${AppLocalization.isIndonesian ? "Kelas" : "Class"}: $className',
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
                                    if (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty) ...[
                                       const SizedBox(height: 12),
                                       GestureDetector(
                                         onTap: () {
                                           showDialog(
                                             context: context,
                                             builder: (ctx) => Dialog(
                                               backgroundColor: Colors.transparent,
                                               child: Column(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   Align(
                                                     alignment: Alignment.topRight,
                                                     child: IconButton(
                                                       icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                                                       onPressed: () => Navigator.pop(ctx),
                                                     ),
                                                   ),
                                                   InteractiveViewer(
                                                     child: Image.network(
                                                       data['imageUrl'] as String,
                                                       fit: BoxFit.contain,
                                                       loadingBuilder: (context, child, loadingProgress) {
                                                         if (loadingProgress == null) return child;
                                                         return const Center(child: CircularProgressIndicator(color: Colors.white));
                                                       },
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ),
                                           );
                                         },
                                         child: ClipRRect(
                                           borderRadius: BorderRadius.circular(12),
                                           child: Image.network(
                                             data['imageUrl'] as String,
                                             height: 120,
                                             width: double.infinity,
                                             fit: BoxFit.cover,
                                             loadingBuilder: (context, child, loadingProgress) {
                                               if (loadingProgress == null) return child;
                                               return Container(
                                                 height: 120,
                                                 color: cardBorderColor.withValues(alpha: 0.1),
                                                 child: const Center(
                                                   child: CircularProgressIndicator(strokeWidth: 2),
                                                 ),
                                               );
                                             },
                                             errorBuilder: (context, error, stackTrace) {
                                               return Container(
                                                 height: 120,
                                                 color: Colors.red.withValues(alpha: 0.1),
                                                 child: Row(
                                                   mainAxisAlignment: MainAxisAlignment.center,
                                                   children: [
                                                     const Icon(Icons.broken_image_rounded, color: Colors.red),
                                                     const SizedBox(width: 8),
                                                     Text(
                                                       'Gagal memuat gambar',
                                                       style: TextStyle(color: textColor, fontSize: 12),
                                                     ),
                                                   ],
                                                 ),
                                               );
                                             },
                                           ),
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
                                          '${AppLocalization.isIndonesian ? "Oleh" : "By"}: $recordedBy • $dateStr',
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
      },
    );
  }
}

class _StudentPoints {
  final String studentId;
  final String studentName;
  final String className;
  final int totalPoints;

  _StudentPoints({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.totalPoints,
  });
}
