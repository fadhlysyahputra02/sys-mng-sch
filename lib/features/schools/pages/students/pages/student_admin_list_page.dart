import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sys_mng_school/core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../services/excel_import_service.dart';
import 'add_student_admin_page.dart';
import 'student_admin_detail_page.dart';

class StudentListPage extends StatefulWidget {
  final String schoolId;
  final bool hideBackButton;

  const StudentListPage({
    super.key,
    required this.schoolId,
    this.hideBackButton = false,
  });

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _sortColumnIndex;
  bool _sortAscending = true;
  int? _selectedRowIndex;
  late Stream<QuerySnapshot> _studentsStream;

  String? _filterKelas;
  String? _filterAngkatan;
  String? _filterAgama;
  String? _filterJalurMasuk;
  bool? _filterStatusRegister;
  String? _filterTempatLahir;

  DateTime? _lastTapTime;
  int? _lastTapRowIndex;

  @override
  void initState() {
    super.initState();
    _studentsStream = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('students')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToDetail(BuildContext context, Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailPage(student: student)),
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
            final borderCol = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

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
                                AppLocalization.studentDataTitle,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
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
                                  colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
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
                                        builder: (_) => AddStudentPage(schoolId: widget.schoolId),
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
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                          hintText: AppLocalization.studentSearchHint,
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
                        stream: _studentsStream,
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
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                              ),
                            );
                          }

                          var docs = snapshot.data?.docs ?? [];
                          
                          List<String> kelasOptions = [];
                          List<String> angkatanOptions = [];
                          List<String> agamaOptions = [];
                          List<String> jalurMasukOptions = [];
                          List<String> tempatLahirOptions = [];

                          if (docs.isNotEmpty) {
                            kelasOptions = docs.map((d) => _normalizeText((d.data() as Map<String, dynamic>)['className']?.toString())).toSet().where((e) => e != '-').toList()..sort();
                            angkatanOptions = docs.map((d) => _normalizeText((d.data() as Map<String, dynamic>)['angkatan']?.toString())).toSet().where((e) => e != '-').toList()..sort();
                            agamaOptions = docs.map((d) => _normalizeText((d.data() as Map<String, dynamic>)['agama']?.toString())).toSet().where((e) => e != '-').toList()..sort();
                            jalurMasukOptions = docs.map((d) => _normalizeText((d.data() as Map<String, dynamic>)['jalurMasuk']?.toString())).toSet().where((e) => e != '-').toList()..sort();
                            tempatLahirOptions = docs.map((d) => _normalizeText((d.data() as Map<String, dynamic>)['tempatLahir']?.toString())).toSet().where((e) => e != '-').toList()..sort();

                            if (_searchQuery.isNotEmpty) {
                              docs = docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final nama = (data['nama'] ?? '').toString().toLowerCase();
                                final nis = (data['nis'] ?? '').toString().toLowerCase();
                                return nama.contains(_searchQuery) || nis.contains(_searchQuery);
                              }).toList();
                            }

                            if (_filterKelas != null) {
                              docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['className']?.toString())) == _filterKelas).toList();
                            }
                            if (_filterAngkatan != null) {
                              docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['angkatan']?.toString())) == _filterAngkatan).toList();
                            }
                            if (_filterAgama != null) {
                              docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['agama']?.toString())) == _filterAgama).toList();
                            }
                            if (_filterJalurMasuk != null) {
                              docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['jalurMasuk']?.toString())) == _filterJalurMasuk).toList();
                            }
                            if (_filterTempatLahir != null) {
                              docs = docs.where((doc) => _normalizeText(((doc.data() as Map<String, dynamic>)['tempatLahir']?.toString())) == _filterTempatLahir).toList();
                            }
                            if (_filterStatusRegister != null) {
                              docs = docs.where((doc) => ((doc.data() as Map<String, dynamic>)['sudahRegister'] ?? false) == _filterStatusRegister).toList();
                            }

                            docs.sort((a, b) {
                              final dataA = a.data() as Map<String, dynamic>;
                              final dataB = b.data() as Map<String, dynamic>;

                              dynamic valA;
                              dynamic valB;

                              switch (_sortColumnIndex) {
                                case 0: valA = dataA['nama']; valB = dataB['nama']; break;
                                case 1: valA = dataA['nis']; valB = dataB['nis']; break;
                                case 2: valA = dataA['className']; valB = dataB['className']; break;
                                case 3: valA = dataA['angkatan']; valB = dataB['angkatan']; break;
                                case 4: valA = dataA['agama']; valB = dataB['agama']; break;
                                case 5: valA = dataA['tempatLahir']; valB = dataB['tempatLahir']; break;
                                case 6: valA = dataA['tanggalLahir']; valB = dataB['tanggalLahir']; break;
                                case 7: valA = dataA['jalurMasuk']; valB = dataB['jalurMasuk']; break;
                                case 8: valA = dataA['sudahRegister']; valB = dataB['sudahRegister']; break;
                                default: valA = dataA['nama']; valB = dataB['nama']; break;
                              }

                              final strA = (valA ?? '').toString().toLowerCase();
                              final strB = (valB ?? '').toString().toLowerCase();

                              if (_sortColumnIndex == null || _sortColumnIndex == 0) {
                                final regExp = RegExp(r'(\d+|\D+)');
                                final aMatches = regExp.allMatches(strA).map((m) => m.group(0)!).toList();
                                final bMatches = regExp.allMatches(strB).map((m) => m.group(0)!).toList();

                                for (int i = 0; i < aMatches.length && i < bMatches.length; i++) {
                                  final aPart = aMatches[i];
                                  final bPart = bMatches[i];
                                  final aInt = int.tryParse(aPart);
                                  final bInt = int.tryParse(bPart);

                                  if (aInt != null && bInt != null) {
                                    if (aInt != bInt) return _sortAscending ? aInt.compareTo(bInt) : bInt.compareTo(aInt);
                                  } else {
                                    final comp = aPart.compareTo(bPart);
                                    if (comp != 0) return _sortAscending ? comp : -comp;
                                  }
                                }
                                return _sortAscending 
                                    ? aMatches.length.compareTo(bMatches.length)
                                    : bMatches.length.compareTo(aMatches.length);
                              } else {
                                return _sortAscending ? strA.compareTo(strB) : strB.compareTo(strA);
                              }
                            });
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
                                    AppLocalization.noStudentData,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textColor.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    AppLocalization.addStudentGuide,
                                    style: TextStyle(fontSize: 13, color: mutedColor),
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
                                            dataTextStyle: TextStyle(
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        child: DataTable(
                                          showCheckboxColumn: false,
                                          headingRowColor: WidgetStateProperty.all(
                                            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                          ),
                                          columns: [
                                            DataColumn(label: buildTextHeader('Nama', 0)),
                                            DataColumn(label: buildTextHeader('NIS', 1)),
                                            DataColumn(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  DropdownButtonHideUnderline(
                                                    child: DropdownButton<String>(
                                                      hint: Text('Kelas', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                      value: _filterKelas,
                                                      dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                      icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                      items: [
                                                        DropdownMenuItem(value: null, child: Text('Semua Kelas')),
                                                        ...kelasOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                      ],
                                                      onChanged: (val) => setState(() => _filterKelas = val),
                                                    ),
                                                  ),
                                                  buildSortIcon(2),
                                                ],
                                              ),
                                            ),
                                            DataColumn(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  DropdownButtonHideUnderline(
                                                    child: DropdownButton<String>(
                                                      hint: Text('Angkatan', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                      value: _filterAngkatan,
                                                      dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                      icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                      items: [
                                                        DropdownMenuItem(value: null, child: Text('Semua Angkatan')),
                                                        ...angkatanOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                      ],
                                                      onChanged: (val) => setState(() => _filterAngkatan = val),
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
                                                      hint: Text('Agama', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                      value: _filterAgama,
                                                      dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                      icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                      items: [
                                                        DropdownMenuItem(value: null, child: Text('Semua Agama')),
                                                        ...agamaOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                      ],
                                                      onChanged: (val) => setState(() => _filterAgama = val),
                                                    ),
                                                  ),
                                                  buildSortIcon(4),
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
                                                        DropdownMenuItem(value: null, child: Text('Semua Tempat')),
                                                        ...tempatLahirOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                      ],
                                                      onChanged: (val) => setState(() => _filterTempatLahir = val),
                                                    ),
                                                  ),
                                                  buildSortIcon(5),
                                                ],
                                              ),
                                            ),
                                            DataColumn(label: buildTextHeader('Tanggal Lahir', 6)),
                                            DataColumn(
                                              label: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  DropdownButtonHideUnderline(
                                                    child: DropdownButton<String>(
                                                      hint: Text('Jalur Masuk', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                                      value: _filterJalurMasuk,
                                                      dropdownColor: isDark ? const Color(0xFF151026) : Colors.white,
                                                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                                      icon: Icon(Icons.filter_list_rounded, size: 16, color: textColor),
                                                      items: [
                                                        DropdownMenuItem(value: null, child: Text('Semua Jalur')),
                                                        ...jalurMasukOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                                                      ],
                                                      onChanged: (val) => setState(() => _filterJalurMasuk = val),
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
                                                  buildSortIcon(8),
                                                ],
                                              ),
                                            ),
                                            const DataColumn(label: Text('Aksi')),
                                          ],
                                          rows: List<DataRow>.generate(docs.length, (index) {
                                            final doc = docs[index];
                                            final student = doc.data() as Map<String, dynamic>;
                                            final bool isRegistered = student['sudahRegister'] ?? false;
                                            final isSelected = _selectedRowIndex == index;

                                            return DataRow(
                                              selected: isSelected,
                                              onSelectChanged: (_) {
                                                final now = DateTime.now();
                                                if (_lastTapRowIndex == index && _lastTapTime != null) {
                                                  if (now.difference(_lastTapTime!) < const Duration(milliseconds: 400)) {
                                                    _lastTapTime = null;
                                                    setState(() => _selectedRowIndex = null);
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => StudentDetailPage(student: student),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                }
                                                _lastTapTime = now;
                                                _lastTapRowIndex = index;

                                                setState(() {
                                                  _selectedRowIndex = index;
                                                });
                                              },
                                              color: WidgetStateProperty.resolveWith<Color?>((states) {
                                                if (states.contains(WidgetState.selected)) {
                                                  return (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1);
                                                }
                                                return null;
                                              }),
                                              cells: [
                                                _doubleTapCell(student['nama'] ?? '-', () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                _doubleTapCell(student['nis'] ?? '-', () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                _doubleTapCell(_normalizeText(student['className']?.toString()), () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                _doubleTapCell(_normalizeText(student['angkatan']?.toString()), () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                _doubleTapCell(_normalizeText(student['agama']?.toString()), () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                _doubleTapCell(_normalizeText(student['tempatLahir']?.toString()), () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                _doubleTapCell(student['tanggalLahir'] ?? '-', () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                _doubleTapCell(_normalizeText(student['jalurMasuk']?.toString()), () => setState(() => _selectedRowIndex = index), () => _navigateToDetail(context, student)),
                                                DataCell(
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isRegistered
                                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(20),
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
                                                          builder: (_) => StudentDetailPage(student: student),
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
      final bool enableImportExcelStudent = schoolData?['enableImportExcelStudent'] ?? false;
      
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      if ((user?.role == 'school_admin' || user?.role == 'tu') && !enableImportExcelStudent) {
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
                'Panduan Pengisian Kolom',
                style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              _buildGuideItem('Format file harus .xlsx atau .xls.', subtitleColor),
              _buildGuideItem('Baris pertama adalah header, data diisi mulai dari baris berikutnya.', subtitleColor),
              const SizedBox(height: 8),
              _buildGuideChip('Kolom Wajib Diisi', const Color(0xFFEF4444), subtitleColor),
              const SizedBox(height: 4),
              _buildGuideItem('Nama Lengkap, NIS, Jenis Kelamin (L/P), Tempat Lahir, Tanggal Lahir (DD-MM-YYYY), Agama, Alamat, Tahun Angkatan.', subtitleColor),
              const SizedBox(height: 8),
              _buildGuideChip('Kolom Opsional', const Color(0xFF0EA5E9), subtitleColor),
              const SizedBox(height: 4),
              _buildGuideItem('NISN, Kewarganegaraan, Nomor HP, Jalur Masuk, Tanggal Diterima, serta seluruh data Ayah, Ibu, dan Wali.', subtitleColor),
              const SizedBox(height: 8),
              _buildGuideItem('NIS harus unik dan tidak boleh terdaftar dua kali dalam satu file maupun di database.', subtitleColor),
              _buildGuideItem('Gunakan tombol "Unduh Template" di bawah untuk mendapatkan format file yang benar.', subtitleColor),
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

                    final success = await ExcelImportService().downloadTemplate('siswa');
                    
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

  Widget _buildGuideChip(String label, Color color, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            color == const Color(0xFFEF4444) ? Icons.star_rounded : Icons.info_outline_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final mutedColor = isDark ? Colors.white : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
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
                AppLocalization.importStudentPremiumMsg,
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
              
              ExcelImportService().importStudents(
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
