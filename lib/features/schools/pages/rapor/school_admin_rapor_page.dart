import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../../../teachers/pages/teacher_rapor_detail_page.dart';
import '../classes/data/class_service.dart';

class SchoolAdminRaporPage extends StatefulWidget {
  final bool hideBackButton;

  const SchoolAdminRaporPage({
    super.key,
    this.hideBackButton = false,
  });

  @override
  State<SchoolAdminRaporPage> createState() => _SchoolAdminRaporPageState();
}

class _SchoolAdminRaporPageState extends State<SchoolAdminRaporPage> {
  final _classService = ClassService();
  final _searchController = TextEditingController();
  
  String _searchQuery = '';
  String _selectedClassId = '';
  String _selectedClassName = '';
  String? _selectedClassTeacherId;

  String _activeSemester = 'Semester 1';
  String _tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
  bool _isLoadingSchool = true;

  StreamSubscription? _classesSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _classes = [];
  bool _isLoadingClasses = true;

  @override
  void initState() {
    super.initState();
    _loadSchoolConfig();
    _listenToClasses();
  }

  void _listenToClasses() {
    final schoolId = SessionService.currentUser!.schoolId;
    _classesSubscription = _classService.getClasses(schoolId).listen((snapshot) {
      if (mounted) {
        setState(() {
          _classes = snapshot.docs;
          _isLoadingClasses = false;
          
          if (_classes.isNotEmpty) {
            final exists = _classes.any((c) => c.id == _selectedClassId);
            if (!exists) {
              final firstClass = _classes.first;
              _selectedClassId = firstClass.id;
              _selectedClassName = firstClass.data()['namaKelas'] ?? '';
              _selectedClassTeacherId = firstClass.data()['teacherId'];
            }
          } else {
            _selectedClassId = '';
            _selectedClassName = '';
            _selectedClassTeacherId = null;
          }
        });
      }
    });
  }

  Future<void> _loadSchoolConfig() async {
    final user = SessionService.currentUser!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(user.schoolId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _activeSemester = data['semester'] as String? ?? 'Semester 1';
          _tahunAjaran = data['tahunAjaran'] as String? ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
        });
      }
    } catch (e) {
      debugPrint('Error loading school config: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSchool = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _classesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: _isLoadingSchool
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // AppBar
                      SliverAppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        pinned: true,
                        iconTheme: IconThemeData(color: iconColor),
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
                          'E-Rapor Siswa (Admin)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                        ),
                      ),

                      // Selection Header & Class Dropdown
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(24),
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
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.filter_alt_rounded, color: Color(0xFF8B5CF6), size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Filter Kelas & Rapor',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Dropdown Kelas
                                    _isLoadingClasses
                                        ? const Center(child: LinearProgressIndicator())
                                        : DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            value: _selectedClassId.isEmpty ? null : _selectedClassId,
                                            dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                            decoration: InputDecoration(
                                              labelText: 'Pilih Kelas',
                                              labelStyle: TextStyle(color: subTextColor, fontSize: 12),
                                              fillColor: inputFillColor,
                                              filled: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                            ),
                                            style: TextStyle(color: titleColor, fontSize: 14),
                                            items: _classes.map((doc) {
                                              final data = doc.data();
                                              final name = data['namaKelas'] ?? '';
                                              return DropdownMenuItem<String>(
                                                value: doc.id,
                                                child: Text(name),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                final selectedDoc = _classes.firstWhere((doc) => doc.id == val);
                                                setState(() {
                                                  _selectedClassId = val;
                                                  _selectedClassName = selectedDoc.data()['namaKelas'] ?? '';
                                                  _selectedClassTeacherId = selectedDoc.data()['teacherId'];
                                                });
                                              }
                                            },
                                          ),
                                    const SizedBox(height: 12),
                                    // Row filter semester & tahun ajaran
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            value: _tahunAjaran,
                                            dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                            decoration: InputDecoration(
                                              labelText: 'Tahun Ajaran',
                                              labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                              fillColor: inputFillColor,
                                              filled: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                            ),
                                            style: TextStyle(color: titleColor, fontSize: 13),
                                            items: [
                                              _tahunAjaran,
                                              '${DateTime.now().year - 1}/${DateTime.now().year}',
                                              '${DateTime.now().year}/${DateTime.now().year + 1}',
                                            ].toSet().map((tahun) {
                                              return DropdownMenuItem<String>(
                                                value: tahun,
                                                child: Text(tahun),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() => _tahunAjaran = val);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            value: _activeSemester,
                                            dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                            decoration: InputDecoration(
                                              labelText: 'Semester',
                                              labelStyle: TextStyle(color: subTextColor, fontSize: 11),
                                              fillColor: inputFillColor,
                                              filled: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                            ),
                                            style: TextStyle(color: titleColor, fontSize: 13),
                                            items: const [
                                              DropdownMenuItem<String>(value: 'Semester 1', child: Text('Semester 1')),
                                              DropdownMenuItem<String>(value: 'Semester 2', child: Text('Semester 2')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() => _activeSemester = val);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Search input
                              TextField(
                                controller: _searchController,
                                style: TextStyle(color: titleColor, fontSize: 14),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val.trim().toLowerCase();
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Cari nama atau NIS murid...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                  prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
                                  filled: true,
                                  fillColor: cardBgColor,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Stream list of students
                      if (_selectedClassId.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'Silakan buat kelas terlebih dahulu di menu manajemen kelas.',
                              style: TextStyle(color: subTextColor, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('students')
                              .where('classId', isEqualTo: _selectedClassId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SliverFillRemaining(
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final allStudents = snapshot.data?.docs ?? [];

                            // Filter search query
                            var filteredStudents = allStudents.where((doc) {
                              final data = doc.data();
                              final name = (data['nama'] ?? '').toString().toLowerCase();
                              final nis = (data['nis'] ?? '').toString().toLowerCase();
                              return name.contains(_searchQuery) || nis.contains(_searchQuery);
                            }).toList();

                            // Sort alphabetically
                            filteredStudents.sort((a, b) {
                              final nameA = (a.data()['nama'] ?? '').toString().toLowerCase();
                              final nameB = (b.data()['nama'] ?? '').toString().toLowerCase();
                              return nameA.compareTo(nameB);
                            });

                            if (filteredStudents.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.people_outline_rounded, size: 48, color: subTextColor),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isEmpty
                                            ? 'Belum ada murid terdaftar di kelas ini.'
                                            : 'Murid tidak ditemukan.',
                                        style: TextStyle(color: subTextColor, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final doc = filteredStudents[index];
                                    final studentId = doc.data()['studentId'] ?? doc.id;
                                    final data = doc.data();
                                    final name = data['nama'] ?? 'Murid';
                                    final nis = data['nis'] ?? '-';
                                    final gender = data['jenisKelamin'] ?? 'L';

                                    // Check report status
                                    final cleanYear = _tahunAjaran.replaceAll('/', '-');
                                    final reportDocId = '${studentId}_${cleanYear}_$_activeSemester';

                                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: FirebaseFirestore.instance
                                          .collection('schools')
                                          .doc(schoolId)
                                          .collection('student_reports')
                                          .doc(reportDocId)
                                          .snapshots(),
                                      builder: (context, reportSnap) {
                                        final hasReport = reportSnap.hasData && reportSnap.data!.exists;
                                        final statusColor = hasReport ? const Color(0xFF10B981) : Colors.amber;
                                        final statusText = hasReport ? 'Sudah Diisi' : 'Belum Lengkap';

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: cardBgColor,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(color: cardBorderColor),
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () {
                                                Get.to(() => TeacherRaporDetailPage(
                                                      schoolId: schoolId,
                                                      classId: _selectedClassId,
                                                      className: _selectedClassName,
                                                      teacherId: _selectedClassTeacherId ?? user.uid,
                                                      studentId: studentId,
                                                      studentName: name,
                                                      studentNis: nis,
                                                    ));
                                              },
                                              borderRadius: BorderRadius.circular(18),
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 20,
                                                      backgroundColor: isDark
                                                          ? Colors.white.withValues(alpha: 0.1)
                                                          : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                      child: Text(
                                                        name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            name,
                                                            style: TextStyle(
                                                              color: titleColor,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            'NIS: $nis • Gender: $gender',
                                                            style: TextStyle(color: subTextColor, fontSize: 11),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        statusText,
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 9,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Icon(
                                                      Icons.arrow_forward_ios_rounded,
                                                      color: iconColor.withValues(alpha: 0.3),
                                                      size: 12,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  childCount: filteredStudents.length,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
