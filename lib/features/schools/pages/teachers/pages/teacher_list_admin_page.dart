import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sys_mng_school/core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../services/excel_import_service.dart';
import 'add_teacher_admin_page.dart';
import 'teacher_detail_admin_page.dart';

class TeacherListPage extends StatefulWidget {
  final String schoolId;
  final bool hideBackButton;

  const TeacherListPage({
    super.key,
    required this.schoolId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherListPage> createState() => _TeacherListPageState();
}

class _TeacherListPageState extends State<TeacherListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int? _selectedRowIndex;
  late Stream<QuerySnapshot> _teachersStream;

  String? _filterStatusGuru;
  String? _filterJabatan;
  String? _filterAgama;
  bool? _filterStatusRegister;
  String? _filterTempatLahir;
  String? _filterMapel;
  String? _filterPendidikanTerakhir;


  // Cache wali kelas: teacherId -> namaKelas
  Map<String, String> _waliKelasMap = {};
  // Cache mapel: teacherId -> joined subject names
  Map<String, String> _mapelMap = {};

  @override
  void initState() {
    super.initState();
    _teachersStream = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('teachers')
        .snapshots();
    _loadWaliKelasMap();
    _loadMapelMap();
  }

  Future<void> _loadWaliKelasMap() async {
    final classSnap = await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('classes')
        .get();
    final map = <String, String>{};
    for (final doc in classSnap.docs) {
      final data = doc.data();
      final teacherId = data['teacherId'] as String?;
      final namaKelas = data['namaKelas'] as String?;
      if (teacherId != null && namaKelas != null) {
        map[teacherId] = namaKelas;
      }
    }
    if (mounted) setState(() => _waliKelasMap = map);
  }

  Future<void> _loadMapelMap() async {
    final subjectSnap = await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('teacher_subjects')
        .get();
    final map = <String, List<String>>{};
    for (final doc in subjectSnap.docs) {
      final data = doc.data();
      final teacherId = data['teacherId'] as String?;
      final subjectName = data['subjectName'] as String?;
      if (teacherId != null && subjectName != null) {
        map.putIfAbsent(teacherId, () => []).add(subjectName);
      }
    }
    final joined = map.map((k, v) => MapEntry(k, v.join(', ')));
    if (mounted) setState(() => _mapelMap = joined);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToDetail(BuildContext context, Map<String, dynamic> guru) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeacherDetailPage(teacher: guru)),
    );
  }

  String _normalizeText(String? val) {
    if (val == null || val.trim().isEmpty || val == '-') return '-';
    return val.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '').join(' ');
  }

  DataCell _doubleTapCell(String text, VoidCallback onTap, VoidCallback onDoubleTap) {
    return DataCell(
      Text(text),
      onTap: onTap,
      onDoubleTap: onDoubleTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
            final mutedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
            final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
            final borderCol = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

            return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // AppBar Area
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        if (!widget.hideBackButton)
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalization.teacherDataTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _handleImport(context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.file_upload_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalization.importExcel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddTeacherPage(schoolId: widget.schoolId),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalization.teacherAddButton,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppLocalization.teacherSearchHint,
                      hintStyle: TextStyle(color: mutedColor, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: mutedColor, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: mutedColor, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),

                // Body
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _teachersStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalization.errorOccurred,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          ),
                        );
                      }

                      var docs = snapshot.data?.docs ?? [];

                      // --- Extract filter options from raw docs ---
                      List<String> statusGuruOptions = [];
                      List<String> jabatanOptions = [];
                      List<String> agamaOptions = [];
                      List<String> tempatLahirOptions = [];
                      List<String> mapelOptions = [];
                      List<String> pendidikanTerakhirOptions = [];

                      if (docs.isNotEmpty) {
                        statusGuruOptions = docs
                            .map((d) => _normalizeText((d.data() as Map<String, dynamic>)['statusGuru']?.toString()))
                            .where((e) => e != '-')
                            .toSet()
                            .toList()
                          ..sort();
                        jabatanOptions = docs
                            .map((d) => _normalizeText((d.data() as Map<String, dynamic>)['jabatan']?.toString()))
                            .where((e) => e != '-')
                            .toSet()
                            .toList()
                          ..sort();
                        agamaOptions = docs
                            .map((d) => _normalizeText((d.data() as Map<String, dynamic>)['agama']?.toString()))
                            .where((e) => e != '-')
                            .toSet()
                            .toList()
                          ..sort();
                        tempatLahirOptions = docs
                            .map((d) => _normalizeText((d.data() as Map<String, dynamic>)['tempatLahir']?.toString()))
                            .where((e) => e != '-')
                            .toSet()
                            .toList()
                          ..sort();
                        mapelOptions = _mapelMap.values
                            .expand((m) => m.split(', '))
                            .map((e) => _normalizeText(e))
                            .where((e) => e != '-')
                            .toSet()
                            .toList()
                          ..sort();
                        pendidikanTerakhirOptions = docs
                            .map((d) => _normalizeText((d.data() as Map<String, dynamic>)['pendidikanTerakhir']?.toString()))
                            .where((e) => e != '-')
                            .toSet()
                            .toList()
                          ..sort();
                      }

                      // --- Sorting ---
                      if (docs.isNotEmpty && _sortColumnIndex != null) {
                        docs = List.from(docs);
                        docs.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          dynamic valA, valB;
                          switch (_sortColumnIndex) {
                            case 0: valA = dataA['nama']; valB = dataB['nama']; break;
                            case 1: valA = dataA['nip']; valB = dataB['nip']; break;
                            case 2:
                              valA = _waliKelasMap[a.id] ?? '';
                              valB = _waliKelasMap[b.id] ?? '';
                              break;
                            case 3:
                              valA = _mapelMap[a.id] ?? '';
                              valB = _mapelMap[b.id] ?? '';
                              break;
                            case 4: valA = dataA['tempatLahir']; valB = dataB['tempatLahir']; break;
                            case 5: valA = dataA['tanggalLahir']; valB = dataB['tanggalLahir']; break;
                            case 6: valA = dataA['agama']; valB = dataB['agama']; break;
                            case 7: valA = dataA['statusGuru']; valB = dataB['statusGuru']; break;
                            case 8: valA = dataA['jabatan']; valB = dataB['jabatan']; break;
                            case 9: valA = dataA['tanggalBergabung']; valB = dataB['tanggalBergabung']; break;
                            case 10: valA = dataA['masaKerja']; valB = dataB['masaKerja']; break;
                            case 11: valA = dataA['pendidikanTerakhir']; valB = dataB['pendidikanTerakhir']; break;
                            case 12: valA = (dataA['sudahRegister'] ?? false) ? 'Register' : 'Belum'; valB = (dataB['sudahRegister'] ?? false) ? 'Register' : 'Belum'; break;
                            default: valA = dataA['nama']; valB = dataB['nama'];
                          }
                          final cmp = (valA ?? '').toString().compareTo((valB ?? '').toString());
                          return _sortAscending ? cmp : -cmp;
                        });
                      } else if (docs.isNotEmpty) {
                        docs = List.from(docs);
                        docs.sort((a, b) {
                          final nameA = ((a.data() as Map<String, dynamic>)['nama'] ?? '').toString().toLowerCase();
                          final nameB = ((b.data() as Map<String, dynamic>)['nama'] ?? '').toString().toLowerCase();
                          return nameA.compareTo(nameB);
                        });
                      }

                      // --- Search ---
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final nama = (data['nama'] ?? '').toString().toLowerCase();
                          final nip = (data['nip'] ?? '').toString().toLowerCase();
                          return nama.contains(_searchQuery) || nip.contains(_searchQuery);
                        }).toList();
                      }

                      // --- Filters ---
                      if (_filterStatusGuru != null) {
                        docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['statusGuru']?.toString())) == _filterStatusGuru).toList();
                      }
                      if (_filterJabatan != null) {
                        docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['jabatan']?.toString())) == _filterJabatan).toList();
                      }
                      if (_filterAgama != null) {
                        docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['agama']?.toString())) == _filterAgama).toList();
                      }
                      if (_filterStatusRegister != null) {
                        docs = docs.where((doc) => ((doc.data() as Map<String, dynamic>)['sudahRegister'] ?? false) == _filterStatusRegister).toList();
                      }
                      if (_filterTempatLahir != null) {
                        docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['tempatLahir']?.toString())) == _filterTempatLahir).toList();
                      }
                      if (_filterMapel != null) {
                        docs = docs.where((doc) {
                          final mapel = _mapelMap[doc.id] ?? '';
                          return mapel.split(', ').map((e) => _normalizeText(e)).contains(_filterMapel!);
                        }).toList();
                      }
                      if (_filterPendidikanTerakhir != null) {
                        docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['pendidikanTerakhir']?.toString())) == _filterPendidikanTerakhir).toList();
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderCol),
                                ),
                                child: Icon(Icons.person_off_rounded, size: 48, color: mutedColor),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                AppLocalization.noTeacherData,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalization.addTeacherGuide,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      void onSort(int columnIndex, bool ascending) {
                        setState(() {
                          _sortColumnIndex = columnIndex;
                          _sortAscending = ascending;
                        });
                      }

                      Widget buildSortIcon(int index) {
                        final isSorted = _sortColumnIndex == index;
                        return InkWell(
                          onTap: () => onSort(index, isSorted ? !_sortAscending : true),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Icon(
                              isSorted && !_sortAscending ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                              size: 20,
                              color: isSorted ? const Color(0xFF0EA5E9) : mutedColor,
                            ),
                          ),
                        );
                      }

                      Widget buildTextHeader(String title, int index) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            buildSortIcon(index),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderCol),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dataTableTheme: DataTableThemeData(
                                        headingTextStyle: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        dataTextStyle: TextStyle(color: textColor),
                                      ),
                                    ),
                                    child: DataTable(
                                      showCheckboxColumn: false,
                                      headingRowColor: WidgetStateProperty.all(
                                        isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                      ),
                                      columns: [
                                        DataColumn(label: buildTextHeader('Nama', 0)),
                                        DataColumn(label: buildTextHeader('NIP', 1)),
                                        DataColumn(label: buildTextHeader('Wali Kelas', 2)),
                                        DataColumn(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  hint: Text('Mapel', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                  value: _filterMapel,
                                                  dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                  icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                  items: [
                                                    const DropdownMenuItem(value: null, child: Text('Semua Mapel')),
                                                    ...mapelOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                  ],
                                                  onChanged: (val) => setState(() => _filterMapel = val),
                                                ),
                                              ),
                                              buildSortIcon(3),
                                            ],
                                          ),
                                        ),
                                        DataColumn(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  hint: Text('Tempat Lahir', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                  value: _filterTempatLahir,
                                                  dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                  icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                  items: [
                                                    const DropdownMenuItem(value: null, child: Text('Semua Tempat')),
                                                    ...tempatLahirOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                  ],
                                                  onChanged: (val) => setState(() => _filterTempatLahir = val),
                                                ),
                                              ),
                                              buildSortIcon(4),
                                            ],
                                          ),
                                        ),
                                        DataColumn(label: buildTextHeader('Tanggal Lahir', 5)),
                                        DataColumn(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  hint: Text('Agama', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                  value: _filterAgama,
                                                  dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                  icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                  items: [
                                                    const DropdownMenuItem(value: null, child: Text('Semua Agama')),
                                                    ...agamaOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                  ],
                                                  onChanged: (val) => setState(() => _filterAgama = val),
                                                ),
                                              ),
                                              buildSortIcon(6),
                                            ],
                                          ),
                                        ),
                                        DataColumn(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  hint: Text('Status Guru', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                  value: _filterStatusGuru,
                                                  dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                  icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                  items: [
                                                    const DropdownMenuItem(value: null, child: Text('Semua Status')),
                                                    ...statusGuruOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                  ],
                                                  onChanged: (val) => setState(() => _filterStatusGuru = val),
                                                ),
                                              ),
                                              buildSortIcon(7),
                                            ],
                                          ),
                                        ),
                                        DataColumn(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  hint: Text('Jabatan', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                  value: _filterJabatan,
                                                  dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                  icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                  items: [
                                                    const DropdownMenuItem(value: null, child: Text('Semua Jabatan')),
                                                    ...jabatanOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                  ],
                                                  onChanged: (val) => setState(() => _filterJabatan = val),
                                                ),
                                              ),
                                              buildSortIcon(8),
                                            ],
                                          ),
                                        ),
                                        DataColumn(label: buildTextHeader('Tgl Bergabung', 9)),
                                        DataColumn(label: buildTextHeader('Masa Kerja', 10)),
                                        DataColumn(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  hint: Text('Pendidikan', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                  value: _filterPendidikanTerakhir,
                                                  dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                  icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                  items: [
                                                    const DropdownMenuItem(value: null, child: Text('Semua Pendidikan')),
                                                    ...pendidikanTerakhirOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                  ],
                                                  onChanged: (val) => setState(() => _filterPendidikanTerakhir = val),
                                                ),
                                              ),
                                              buildSortIcon(11),
                                            ],
                                          ),
                                        ),
                                        DataColumn(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton<bool>(
                                                  hint: Text('Status Register', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                  value: _filterStatusRegister,
                                                  dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                  style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                  icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                  items: const [
                                                    DropdownMenuItem(value: null, child: Text('Semua Status')),
                                                    DropdownMenuItem(value: true, child: Text('Register')),
                                                    DropdownMenuItem(value: false, child: Text('Belum Register')),
                                                  ],
                                                  onChanged: (val) => setState(() => _filterStatusRegister = val),
                                                ),
                                              ),
                                              buildSortIcon(12),
                                            ],
                                          ),
                                        ),
                                        const DataColumn(label: Text('Aksi')),
                                      ],
                                      rows: List<DataRow>.generate(docs.length, (index) {
                                        final doc = docs[index];
                                        final guru = doc.data() as Map<String, dynamic>;
                                        final bool isRegistered = guru['sudahRegister'] ?? false;
                                        final isSelected = _selectedRowIndex == index;
                                        final waliKelas = _waliKelasMap[doc.id] ?? '-';

                                        return DataRow(
                                          selected: isSelected,
                                          onSelectChanged: (_) {
                                            setState(() => _selectedRowIndex = index);
                                          },
                                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                                            if (states.contains(WidgetState.selected)) {
                                              return const Color(0xFF8B5CF6).withValues(alpha: 0.15);
                                            }
                                            return null;
                                          }),
                                          cells: [
                                            _doubleTapCell(guru['nama'] ?? '-', () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(guru['nip'] ?? '-', () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(waliKelas, () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(_normalizeText(_mapelMap[doc.id]), () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(_normalizeText(guru['tempatLahir']?.toString()), () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(guru['tanggalLahir'] ?? '-', () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(_normalizeText(guru['agama']?.toString()), () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(_normalizeText(guru['statusGuru']?.toString()), () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(_normalizeText(guru['jabatan']?.toString()), () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(guru['tanggalBergabung'] ?? '-', () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(guru['masaKerja'] ?? '-', () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            _doubleTapCell(_normalizeText(guru['pendidikanTerakhir']?.toString()), () => setState(() => _selectedRowIndex = index), () { _navigateToDetail(context, guru); }),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isRegistered
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: isRegistered
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                                        : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                                  ),
                                                ),
                                                child: Text(
                                                  isRegistered ? AppLocalization.registeredStatus : AppLocalization.notRegisteredStatus,
                                                  style: TextStyle(
                                                    color: isRegistered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                                color: mutedColor,
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => TeacherDetailPage(teacher: guru),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                            child: Text(
                              _selectedRowIndex != null
                                  ? '${_selectedRowIndex! + 1}/${docs.length}'
                                  : '0/${docs.length}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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

  Future<void> _handleImport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
      ),
    );

    try {
      final user = SessionService.currentUser;
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();
          
      final schoolData = schoolDoc.data();
      final bool enableImportExcelTeacher = schoolData?['enableImportExcelTeacher'] ?? false;
      
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      if ((user?.role == 'school_admin' || user?.role == 'tu') && !enableImportExcelTeacher) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF151026),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(AppLocalization.featureLockedTitle, style: const TextStyle(color: Colors.white)),
                ],
              ),
              content: Text(
                AppLocalization.importDisabledBySuperAdmin,
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        _showImportGuide(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  void _showImportGuide(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorder, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF10B981), size: 36),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppLocalization.excelGuideTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalization.excelGuideSubtitle,
                style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildGuideItem('Format file: Excel (.xlsx). Jangan ubah format atau urutan kolom.', subtitleColor),
              _buildGuideItem('Baris 1-5 adalah judul & header. Isi data mulai dari BARIS 6.', subtitleColor),
              const SizedBox(height: 8),
              Text('Kolom WAJIB (35 kolom total):', style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildGuideItem('A: Nama Lengkap  |  B: NIP  |  G: Jenis Kelamin', subtitleColor),
              _buildGuideItem('H: Tempat Lahir  |  I: Tanggal Lahir (dd-MM-yyyy)', subtitleColor),
              _buildGuideItem('J: Agama  |  L: Kewarganegaraan', subtitleColor),
              _buildGuideItem('O: Nomor HP  |  Q: NIK  |  U: Nomor KK', subtitleColor),
              _buildGuideItem('AD: Pendidikan Terakhir', subtitleColor),
              const SizedBox(height: 6),
              Text('Kolom Dropdown (gunakan pilihan yang tersedia):', style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _buildGuideItem('G (Jenis Kelamin): Laki-laki / Perempuan', subtitleColor),
              _buildGuideItem('J (Agama): Islam / Kristen / Katolik / Hindu / Buddha / Konghucu', subtitleColor),
              _buildGuideItem('K (Status Pernikahan): Belum Menikah / Menikah / Duda/Janda', subtitleColor),
              _buildGuideItem('L (Kewarganegaraan): WNI / WNA', subtitleColor),
              _buildGuideItem('M (Golongan Darah): A, B, AB, O (dengan atau tanpa +/-)', subtitleColor),
              _buildGuideItem('X (Status Guru): Tetap / Honorer / PPPK / PNS / Kontrak', subtitleColor),
              _buildGuideItem('NIP duplikat (di file maupun database) akan ditolak otomatis.', subtitleColor),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Tutup guide dialog

                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (loadingContext) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        ),
                      ),
                    );

                    final success = await ExcelImportService().downloadTemplate('guru');
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Tutup loading dialog
                    }

                    if (success == true) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalization.excelTemplateSaved)),
                        );
                        _showImportGuide(context); // Buka kembali guide agar user bisa pilih file
                      }
                    } else if (success == false) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalization.excelTemplateSaveFailed)),
                        );
                        _showImportGuide(context);
                      }
                    } else {
                      // null = batal
                      if (context.mounted) {
                        _showImportGuide(context);
                      }
                    }
                  },
                  icon: const Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 18),
                  label: Text(AppLocalization.downloadExcelTemplate, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF1E1B4B).withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(AppLocalization.cancel, style: TextStyle(color: textColor)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _startImporting(context);
                        },
                        child: Text(AppLocalization.chooseFile, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideItem(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final mutedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorder, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalization.premiumFeatureTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalization.importTeacherPremiumMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalization.upgradePackageMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalization.close, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _startImporting(BuildContext context) async {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    String status = 'pilih_file';
    double progress = 0.0;
    String statusText = AppLocalization.readingExcelData;
    ExcelImportResult? importResult;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (status == 'pilih_file') {
              status = 'memproses';
              
              ExcelImportService().importTeachers(
                widget.schoolId,
                onFileSelected: () {
                  setModalState(() {
                    statusText = AppLocalization.readingExcelData;
                  });
                },
                onProgress: (current, total) {
                  setModalState(() {
                    statusText = AppLocalization.importProgressMsg(current, total);
                    progress = total > 0 ? current / total : 0.0;
                  });
                },
              ).then((result) {
                setModalState(() {
                  status = 'selesai';
                  importResult = result;
                });
              }).catchError((err) {
                setModalState(() {
                  status = 'selesai';
                  importResult = ExcelImportResult(
                    successCount: 0,
                    duplicateCount: 0,
                    failedCount: 1,
                    errors: ['${AppLocalization.failedProcessFile}: $err'],
                  );
                });
              });
            }

            if (status == 'memproses') {
              return AlertDialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: dialogBorder, width: 1.5),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    CircularProgressIndicator(
                      value: progress > 0.0 ? progress : null,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (progress > 0.0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              );
            }

            if (importResult == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) Navigator.pop(dialogContext);
              });
              return const SizedBox.shrink();
            }

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: dialogBorder, width: 1.5),
              ),
              title: Text(
                AppLocalization.importResultTitle,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              // SizedBox dengan lebar tertentu mencegah AlertDialog
              // mencoba mengukur intrinsic width secara rekursif
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultRow(Icons.check_circle_outline_rounded, Colors.green, AppLocalization.importSuccessCount(importResult!.successCount), textColor),
                    const SizedBox(height: 10),
                    _buildResultRow(Icons.error_outline_rounded, Colors.red, AppLocalization.importFailedCount(importResult!.failedCount), textColor),
                    if (importResult!.errors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        AppLocalization.errorDetailTitle,
                        style: TextStyle(color: subtitleColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        // maxHeight membatasi tinggi list — ListView bisa scroll di dalamnya
                        // tanpa perlu shrinkWrap (shrinkWrap di dalam Column(min) + AlertDialog
                        // menyebabkan viewport mencoba hitung intrinsic dimension → crash)
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF1E1B4B).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: importResult!.errors.length,
                          itemBuilder: (context, idx) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              importResult!.errors[idx],
                              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (ctx.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResultRow(IconData icon, Color color, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
