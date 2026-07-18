import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../../../teachers/pages/teacher_rapor_detail_page.dart';
import '../classes/data/class_service.dart';
import '../../../../core/localization/app_localization.dart';
import 'pages/admin_rapor_settings_page.dart';

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

  String _schoolName = '';
  String _activeSemester = 'Semester 1';
  String _tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
  bool _isLoadingSchool = true;

  StreamSubscription? _classesSubscription;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _classes = [];
  bool _isLoadingClasses = true;
  bool _isAccessChecking = false;
  bool _isAccessGranted = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _accessSubscription;
  bool _lockDialogShown = false;

  @override
  void initState() {
    super.initState();
    _listenToAccess();
  }

  void _listenToAccess() {
    final user = SessionService.currentUser;
    if (user?.role != 'school_admin' && user?.role != 'tu') {
      setState(() {
        _isAccessChecking = false;
        _isAccessGranted = true;
      });
      _loadSchoolConfig();
      _listenToClasses();
      return;
    }

    setState(() => _isAccessChecking = true);

    _accessSubscription = FirebaseFirestore.instance
        .collection('schools')
        .doc(user!.schoolId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final bool enabled = snap.data()?['enableERapor'] ?? false;

      if (!enabled) {
        setState(() {
          _isAccessChecking = false;
          _isAccessGranted = false;
        });
        if (!_lockDialogShown) {
          _lockDialogShown = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF151026),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(AppLocalization.isIndonesian ? 'Fitur Terkunci' : 'Feature Locked', style: const TextStyle(color: Colors.white)),
                ],
              ),
              content: Text(
                AppLocalization.isIndonesian
                    ? 'Fitur E-Rapor dinonaktifkan oleh Super Admin. Silakan hubungi Super Admin untuk mengaktifkan akses.'
                    : 'E-Report Card feature is disabled by Super Admin. Please contact Super Admin to enable access.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Get.back();
                  },
                  child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
          ).then((_) => _lockDialogShown = false);
        }
      } else {
        final wasBlocked = !_isAccessGranted;
        setState(() {
          _isAccessChecking = false;
          _isAccessGranted = true;
        });
        // Load data if: feature was previously blocked, or first time loading
        if (wasBlocked || _classes.isEmpty) {
          _loadSchoolConfig();
          _listenToClasses();
        }
      }
    }, onError: (e) {
      setState(() {
        _isAccessChecking = false;
        _isAccessGranted = true;
      });
      _loadSchoolConfig();
      _listenToClasses();
    });
  }

  void _listenToClasses() {
    final schoolId = SessionService.currentUser!.schoolId;
    _classesSubscription = _classService.getClasses(schoolId).listen((snapshot) {
      if (mounted) {
        setState(() {
          final sortedDocs = snapshot.docs.toList()..sort((a, b) {
            final aName = a.data()['namaKelas']?.toString().toLowerCase() ?? '';
            final bName = b.data()['namaKelas']?.toString().toLowerCase() ?? '';
            return aName.compareTo(bName);
          });
          _classes = sortedDocs;
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
          _schoolName = data['namaSekolah'] ?? data['name'] ?? data['nama'] ?? '';
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
    _accessSubscription?.cancel();
    _classesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAccessChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0B1E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }
    if (!_isAccessGranted) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0B1E),
        body: SizedBox.shrink(),
      );
    }

    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;

    return ValueListenableBuilder<String>(
      valueListenable: AppLocalization.currentLocale,
      builder: (context, locale, _) {
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
                          AppLocalization.isIndonesian ? 'E-Rapor Siswa (Admin)' : 'Student E-Report Card (Admin)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                        ),
                        actions: [
                          Container(
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.settings_suggest_rounded, size: 20),
                              onPressed: () {
                                Get.to(() => AdminRaporSettingsPage(
                                      schoolId: schoolId,
                                      defaultSchoolName: _schoolName,
                                    ));
                              },
                            ),
                          ),
                        ],
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
                                          AppLocalization.isIndonesian ? 'Filter Kelas & Rapor' : 'Class & Report Card Filter',
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
                                              labelText: AppLocalization.isIndonesian ? 'Pilih Kelas' : 'Select Class',
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
                                              labelText: AppLocalization.isIndonesian ? 'Tahun Ajaran' : 'Academic Year',
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
                                              labelText: AppLocalization.isIndonesian ? 'Semester' : 'Semester',
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
                                  hintText: AppLocalization.isIndonesian ? 'Cari nama atau NIS murid...' : 'Search student name or ID...',
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
                              AppLocalization.isIndonesian ? 'Silakan buat kelas terlebih dahulu di menu manajemen kelas.' : 'Please create a class first in the class management menu.',
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
                                        AppLocalization.isIndonesian
                                            ? (_searchQuery.isEmpty
                                                ? 'Belum ada murid terdaftar di kelas ini.'
                                                : 'Murid tidak ditemukan.')
                                            : (_searchQuery.isEmpty
                                                ? 'No students registered in this class yet.'
                                                : 'Student not found.'),
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
                                    final genderRaw = data['gender']?.toString().toLowerCase() ?? 'laki-laki';
                                    final gender = genderRaw.startsWith('p') ? 'P' : 'L';

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
                                        final statusText = hasReport 
                                            ? (AppLocalization.isIndonesian ? 'Sudah Diisi' : 'Filled') 
                                            : (AppLocalization.isIndonesian ? 'Belum Lengkap' : 'Incomplete');

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
      },
    );
  }
}
