import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../authentication/widgets/auth_background.dart';
import '../services/grade_service.dart';
import '../../../core/localization/app_localization.dart';

class TeacherMyStudentsPage extends StatefulWidget {
  final String schoolId;
  final String teacherId;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> waliKelasClasses;

  final bool hideBackButton;

  const TeacherMyStudentsPage({
    super.key,
    required this.schoolId,
    required this.teacherId,
    required this.waliKelasClasses,
    this.hideBackButton = false,
  });

  @override
  State<TeacherMyStudentsPage> createState() => _TeacherMyStudentsPageState();
}

class _TeacherMyStudentsPageState extends State<TeacherMyStudentsPage> {
  final _gradeService = GradeService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedClassId;
  late String _selectedClassName;

  String _activeSemester = 'Semester 1';
  String _tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
  bool _isLoadingSchool = true;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.waliKelasClasses.isNotEmpty ? widget.waliKelasClasses.first.id : '';
    _selectedClassName = widget.waliKelasClasses.isNotEmpty 
        ? (widget.waliKelasClasses.first.data()['namaKelas'] ?? 'Kelas') 
        : 'Kelas';
    _loadSchoolConfig();
  }

  Future<void> _loadSchoolConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['semester'] != null) {
          setState(() {
            _activeSemester = data['semester'] as String;
          });
        }
        if (data['tahunAjaran'] != null) {
          setState(() {
            _tahunAjaran = data['tahunAjaran'] as String;
          });
        }
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            return Scaffold(
              body: AuthBackground(
                child: _isLoadingSchool || _selectedClassId.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                        ),
                      )
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // App Bar
                          SliverAppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            pinned: true,
                            automaticallyImplyLeading: false,
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
                              AppLocalization.isIndonesian ? 'Daftar Siswa Wali Kelas' : 'Homeroom Student List',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                            ),
                          ),

                          // Header & Search
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Dropdown if multiple classes, else text
                                  if (widget.waliKelasClasses.length > 1) ...[
                                    Text(
                                      AppLocalization.isIndonesian ? 'Pilih Kelas Wali' : 'Select Homeroom Class',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cardBgColor,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: cardBorderColor),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedClassId,
                                          dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                                          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: iconColor),
                                          items: widget.waliKelasClasses.map((cls) {
                                            final data = cls.data();
                                            final name = data['namaKelas'] ?? 'Kelas';
                                            return DropdownMenuItem<String>(
                                              value: cls.id,
                                              child: Text(name),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              final selectedDoc = widget.waliKelasClasses.firstWhere((c) => c.id == val);
                                              setState(() {
                                                _selectedClassId = val;
                                                _selectedClassName = selectedDoc.data()['namaKelas'] ?? 'Kelas';
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      '${AppLocalization.isIndonesian ? 'Kelas Wali' : 'Homeroom Class'}: $_selectedClassName',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _searchController,
                                    style: TextStyle(color: titleColor),
                                    onChanged: (val) {
                                      setState(() {
                                        _searchQuery = val.trim().toLowerCase();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: AppLocalization.isIndonesian ? 'Cari nama atau NIS siswa...' : 'Search student name or ID...',
                                      hintStyle: TextStyle(color: subTextColor),
                                      prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                                      filled: true,
                                      fillColor: cardBgColor,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide(color: cardBorderColor),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF8B5CF6)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Stream Builder list students
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _gradeService.getStudentsByClass(
                              widget.schoolId,
                              _selectedClassId,
                              tahunAjaran: _tahunAjaran,
                              semester: _activeSemester,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SliverFillRemaining(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (snapshot.hasError) {
                                return SliverFillRemaining(
                                  child: Center(
                                    child: Text(
                                      AppLocalization.isIndonesian ? 'Terjadi kesalahan memuat data murid' : 'An error occurred loading student data',
                                      style: TextStyle(color: titleColor),
                                    ),
                                  ),
                                );
                              }

                              final allStudents = snapshot.data?.docs ?? [];
                              
                              // Filter search query
                              var filteredStudents = allStudents.where((doc) {
                                final name = (doc.data()['nama'] ?? '').toString().toLowerCase();
                                final nis = (doc.data()['nis'] ?? '').toString().toLowerCase();
                                return name.contains(_searchQuery) || nis.contains(_searchQuery);
                              }).toList();

                              // Sort alphabet
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
                                        Icon(Icons.people_outline_rounded, size: 64, color: subTextColor),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isEmpty
                                              ? (AppLocalization.isIndonesian ? 'Belum ada murid di kelas ini' : 'No students in this class yet')
                                              : (AppLocalization.isIndonesian ? 'Murid tidak ditemukan' : 'Student not found'),
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
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
                                      if (index == 0) {
                                        // Stats Card (Only Total Students)
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: _buildStatCard(
                                            AppLocalization.isIndonesian ? 'Total Siswa' : 'Total Students',
                                            filteredStudents.length.toString(),
                                            Icons.groups_rounded,
                                            const Color(0xFF3B82F6),
                                            cardBgColor,
                                            cardBorderColor,
                                            titleColor,
                                            subTextColor,
                                          ),
                                        );
                                      }

                                      final studentIndex = index - 1;
                                      final studentDoc = filteredStudents[studentIndex];
                                      final studentData = studentDoc.data();
                                      final name = studentData['nama'] ?? 'Murid';
                                      final nis = studentData['nis'] ?? '-';
                                      final studentId = studentData['studentId'] ?? studentDoc.id;

                                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                        future: FirebaseFirestore.instance
                                            .collection('schools')
                                            .doc(widget.schoolId)
                                            .collection('students')
                                            .doc(studentId)
                                            .get(),
                                        builder: (context, studentSnap) {
                                          String gender = 'Laki-laki';
                                          if (studentSnap.hasData && studentSnap.data!.exists) {
                                            final sData = studentSnap.data!.data();
                                            if (sData != null) {
                                              gender = sData['gender'] ?? sData['jenisKelamin'] ?? 'Laki-laki';
                                            }
                                          }
                                          final genderUpper = gender.toUpperCase();
                                          final isFemale = genderUpper.startsWith('P') || genderUpper.startsWith('F');

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              color: cardBgColor,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: cardBorderColor),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              leading: CircleAvatar(
                                                radius: 24,
                                                backgroundColor: isFemale 
                                                    ? const Color(0xFFEC4899).withValues(alpha: 0.15)
                                                    : const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                                                child: Icon(
                                                  isFemale ? Icons.female_rounded : Icons.male_rounded,
                                                  color: isFemale ? const Color(0xFFEC4899) : const Color(0xFF0EA5E9),
                                                  size: 26,
                                                ),
                                              ),
                                              title: Text(
                                                name,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'NIS: $nis • ${isFemale ? (AppLocalization.isIndonesian ? 'Perempuan' : 'Female') : (AppLocalization.isIndonesian ? 'Laki-laki' : 'Male')}',
                                                  style: TextStyle(fontSize: 12, color: subTextColor),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                        childCount: filteredStudents.length + 1,
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

  Widget _buildStatCard(
    String label,
    String val,
    IconData icon,
    Color accentColor,
    Color bg,
    Color border,
    Color titleColor,
    Color subColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 8),
          Text(
            val,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
