import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/session_service.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../../../teachers/services/teaching_report_service.dart';
import '../../../../core/localization/app_localization.dart';

class AdminTeachingReportsPage extends StatefulWidget {
  const AdminTeachingReportsPage({super.key});

  @override
  State<AdminTeachingReportsPage> createState() => _AdminTeachingReportsPageState();
}

class _AdminTeachingReportsPageState extends State<AdminTeachingReportsPage> {
  final _reportService = TeachingReportService();
  String _searchQuery = '';
  
  String? _selectedTahunAjaran;
  String? _selectedSemester;
  String? _selectedTeacher;
  String? _selectedClass;

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser;
    if (user != null) {
      _reportService.deleteOldReports(user.schoolId);
    }
  }

  bool _isWithinThreeYears(String? tahunAjaran) {
    if (tahunAjaran == null || !tahunAjaran.contains('/')) return true;
    try {
      final startYear = int.parse(tahunAjaran.split('/')[0]);
      final currentYear = DateTime.now().year;
      return startYear >= currentYear - 3;
    } catch (_) {
      return true;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final month = parts[1];
        final day = parts[2];
        return '$day/$month/$year';
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);
        final searchBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  iconTheme: IconThemeData(color: iconColor),
                  leading: Container(
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
                    AppLocalization.isIndonesian ? 'Laporan Mengajar' : 'Teaching Reports',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: searchBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorderColor),
                          ),
                          child: TextField(
                            style: TextStyle(color: titleColor),
                            decoration: InputDecoration(
                              icon: Icon(Icons.search_rounded, color: subTextColor),
                              hintText: AppLocalization.isIndonesian
                                  ? 'Cari nama guru atau mata pelajaran...'
                                  : 'Search teacher name or subject...',
                              hintStyle: TextStyle(color: subTextColor),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.toLowerCase();
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Stream list
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _reportService.getReportsStream(user.schoolId),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(child: Text(AppLocalization.isIndonesian ? 'Terjadi kesalahan memuat data' : 'An error occurred loading data', style: const TextStyle(color: Colors.red)));
                            }
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                            }

                            final rawReports = snapshot.data?.docs.map((e) => e.data()).toList() ?? [];
                            final allReports = rawReports.where((r) => _isWithinThreeYears(r['tahunAjaran']?.toString())).toList();

                            // Extract dynamic filter options
                            final tahunAjaranSet = <String>{};
                            final semesterSet = <String>{};
                            final teacherSet = <String>{};
                            final classSet = <String>{};

                            for (var r in allReports) {
                              if (r['tahunAjaran'] != null) tahunAjaranSet.add(r['tahunAjaran'].toString());
                              if (r['semester'] != null) semesterSet.add(r['semester'].toString());
                              if (r['teacherName'] != null) teacherSet.add(r['teacherName'].toString());
                              if (r['className'] != null) classSet.add(r['className'].toString());
                            }

                            final tahunAjarans = tahunAjaranSet.toList()..sort((a, b) => b.compareTo(a));
                            final semesters = semesterSet.toList()..sort();
                            final teachers = teacherSet.toList()..sort();
                            final classes = classSet.toList()..sort();

                            // Set default values if null but data exists
                            if (_selectedTahunAjaran == null && tahunAjarans.isNotEmpty) {
                              _selectedTahunAjaran = tahunAjarans.first;
                            }
                            if (_selectedSemester == null && semesters.isNotEmpty) {
                              // Auto-select latest semester or leave as first
                              _selectedSemester = semesters.first;
                            }

                            // Filter logic
                            final filteredReports = allReports.where((r) {
                              // Multi-level Filters
                              if (_selectedTahunAjaran != null && _selectedTahunAjaran != 'Semua' && r['tahunAjaran'] != _selectedTahunAjaran) return false;
                              if (_selectedSemester != null && _selectedSemester != 'Semua' && r['semester'] != _selectedSemester) return false;
                              if (_selectedTeacher != null && _selectedTeacher != 'Semua Guru' && r['teacherName'] != _selectedTeacher) return false;
                              if (_selectedClass != null && _selectedClass != 'Semua Kelas' && r['className'] != _selectedClass) return false;

                              // Text Search Filter
                              final teacherName = (r['teacherName']?.toString() ?? '').toLowerCase();
                              final subjectName = (r['subjectName']?.toString() ?? '').toLowerCase();
                              final materi = (r['materi']?.toString() ?? '').toLowerCase();
                              if (_searchQuery.isNotEmpty &&
                                  !teacherName.contains(_searchQuery) &&
                                  !subjectName.contains(_searchQuery) &&
                                  !materi.contains(_searchQuery)) {
                                return false;
                              }
                              return true;
                            }).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Filter Bar 1: Tahun Ajaran & Semester
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        title: AppLocalization.isIndonesian ? 'Tahun Ajaran' : 'Academic Year',
                                        value: _selectedTahunAjaran,
                                        items: [AppLocalization.isIndonesian ? 'Semua' : 'All', ...tahunAjarans],
                                        onChanged: (val) => setState(() => _selectedTahunAjaran = val),
                                        searchBg: searchBg,
                                        titleColor: titleColor,
                                        subTextColor: subTextColor,
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdown(
                                        title: AppLocalization.isIndonesian ? 'Semester' : 'Semester',
                                        value: _selectedSemester,
                                        items: [AppLocalization.isIndonesian ? 'Semua' : 'All', ...semesters],
                                        onChanged: (val) => setState(() => _selectedSemester = val),
                                        searchBg: searchBg,
                                        titleColor: titleColor,
                                        subTextColor: subTextColor,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Filter Bar 2: Guru & Kelas
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdown(
                                        title: AppLocalization.isIndonesian ? 'Guru' : 'Teacher',
                                        value: _selectedTeacher ?? (AppLocalization.isIndonesian ? 'Semua Guru' : 'All Teachers'),
                                        items: [AppLocalization.isIndonesian ? 'Semua Guru' : 'All Teachers', ...teachers],
                                        onChanged: (val) => setState(() => _selectedTeacher = val),
                                        searchBg: searchBg,
                                        titleColor: titleColor,
                                        subTextColor: subTextColor,
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdown(
                                        title: AppLocalization.isIndonesian ? 'Kelas' : 'Class',
                                        value: _selectedClass ?? (AppLocalization.isIndonesian ? 'Semua Kelas' : 'All Classes'),
                                        items: [AppLocalization.isIndonesian ? 'Semua Kelas' : 'All Classes', ...classes],
                                        onChanged: (val) => setState(() => _selectedClass = val),
                                        searchBg: searchBg,
                                        titleColor: titleColor,
                                        subTextColor: subTextColor,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                if (filteredReports.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(40.0),
                                      child: Column(
                                        children: [
                                          Icon(Icons.edit_document, size: 64, color: subTextColor.withValues(alpha: 0.5)),
                                          const SizedBox(height: 16),
                                          Text(
                                            AppLocalization.isIndonesian
                                                ? 'Tidak ada laporan mengajar ditemukan'
                                                : 'No teaching reports found',
                                            style: TextStyle(color: subTextColor, fontSize: 14),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredReports.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final report = filteredReports[index];
                                final teacherName = report['teacherName'] ?? 'Guru';
                                final subjectName = report['subjectName'] ?? 'Mata Pelajaran';
                                final className = report['className'] ?? 'Kelas';
                                final dateStr = report['date'] ?? '-';
                                final materi = report['materi'] ?? '-';
                                final catatan = report['catatan'] ?? '';

                                return Container(
                                  padding: const EdgeInsets.all(20),
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
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                            child: const Icon(Icons.person_rounded, color: Color(0xFF8B5CF6)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  teacherName,
                                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$subjectName • Kelas $className',
                                                  style: TextStyle(fontSize: 13, color: const Color(0xFF10B981), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: searchBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _formatDate(dateStr),
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: cardBorderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalization.isIndonesian ? 'Materi Diajarkan:' : 'Materials Taught:',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              materi,
                                              style: TextStyle(fontSize: 14, color: titleColor),
                                            ),
                                            if (catatan.isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                AppLocalization.isIndonesian ? 'Catatan Tambahan:' : 'Additional Notes:',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                catatan,
                                                style: TextStyle(fontSize: 14, color: titleColor),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildDropdown({
    required String title,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required Color searchBg,
    required Color titleColor,
    required Color subTextColor,
    required bool isDark,
  }) {
    // Pastikan value ada di items (mencegah error jika data berubah)
    final safeValue = items.contains(value) ? value : items.first;
    final isSearchable = title == 'Guru' || title == 'Teacher' || title == 'Kelas' || title == 'Class';

    if (isSearchable) {
      return InkWell(
        onTap: () => _showSearchableListDialog(title, items, safeValue, onChanged, searchBg, titleColor, subTextColor, isDark),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: searchBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: subTextColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  safeValue ?? title,
                  style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.arrow_drop_down_rounded, color: subTextColor),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: searchBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: subTextColor.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
          icon: Icon(Icons.arrow_drop_down_rounded, color: subTextColor),
          style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w600),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _showSearchableListDialog(
    String title,
    List<String> items,
    String? currentValue,
    Function(String?) onChanged,
    Color searchBg,
    Color titleColor,
    Color subTextColor,
    bool isDark,
  ) {
    String searchQuery = '';
    final dialogBgColor = isDark ? const Color(0xFF1E1B4B) : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredItems = items.where((item) => item.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return AlertDialog(
              backgroundColor: dialogBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: subTextColor.withValues(alpha: 0.1)),
              ),
              title: Column(
                children: [
                  Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: subTextColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(AppLocalization.isIndonesian ? 'Pilih $title' : 'Select $title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor)),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: TextStyle(color: titleColor),
                      decoration: InputDecoration(
                        hintText: AppLocalization.isIndonesian ? 'Cari $title...' : 'Search $title...',
                        hintStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                        filled: true,
                        fillColor: searchBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredItems.length,
                        separatorBuilder: (context, index) => Divider(color: subTextColor.withValues(alpha: 0.1), height: 1),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = item == currentValue;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            title: Text(
                              item, 
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF8B5CF6) : titleColor,
                                fontSize: 14,
                              ),
                            ),
                            trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF8B5CF6)) : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onTap: () {
                              Navigator.pop(context);
                              onChanged(item);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLocalization.isIndonesian ? 'Tutup' : 'Close', style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
