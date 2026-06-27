import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../authentication/widgets/auth_background.dart';
import '../services/grade_service.dart';
import 'teacher_rapor_detail_page.dart';

class TeacherRaporPage extends StatefulWidget {
  final String schoolId;
  final String classId;
  final String className;
  final String teacherId;

  const TeacherRaporPage({
    super.key,
    required this.schoolId,
    required this.classId,
    required this.className,
    required this.teacherId,
  });

  @override
  State<TeacherRaporPage> createState() => _TeacherRaporPageState();
}

class _TeacherRaporPageState extends State<TeacherRaporPage> {
  final _gradeService = GradeService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeSemester = 'Semester 1';
  String _tahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
  bool _isLoadingSchool = true;

  @override
  void initState() {
    super.initState();
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
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: _isLoadingSchool
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                    ),
                  )
                : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar
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
                    'E-Rapor - ${widget.className}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                  ),
                ),

                // Search Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daftar Murid Kelas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pilih siswa di bawah untuk mengisi penilaian sikap, catatan wali kelas, dan mengunduh E-Rapor.',
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          style: TextStyle(color: titleColor),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Cari nama atau NIS murid...',
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

                // Stream List Murid
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _gradeService.getStudentsByClass(
                    widget.schoolId,
                    widget.classId,
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
                          child: Text('Terjadi kesalahan memuat data murid', style: TextStyle(color: titleColor)),
                        ),
                      );
                    }

                    final allStudents = snapshot.data?.docs ?? [];
                    
                    // Filter berdasarkan pencarian
                    var filteredStudents = allStudents.where((doc) {
                      final name = (doc.data()['nama'] ?? '').toString().toLowerCase();
                      final nis = (doc.data()['nis'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || nis.contains(_searchQuery);
                    }).toList();

                    // Urutkan A-Z berdasarkan nama
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
                                _searchQuery.isEmpty ? 'Belum ada murid di kelas ini' : 'Murid tidak ditemukan',
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
                            final studentDoc = filteredStudents[index];
                            final studentId = studentDoc.data()?['studentId'] ?? studentDoc.id;
                            final studentData = studentDoc.data();
                            final name = studentData['nama'] ?? 'Murid';
                            final nis = studentData['nis'] ?? '-';
                            final gender = studentData['jenisKelamin'] ?? 'L';

                            // Cek status rapor secara realtime dari Firestore student_reports subcollection
                            final cleanYear = _tahunAjaran.replaceAll('/', '-');
                            final reportDocId = '${studentId}_${cleanYear}_$_activeSemester';

                            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('schools')
                                  .doc(widget.schoolId)
                                  .collection('student_reports')
                                  .doc(reportDocId)
                                  .snapshots(),
                              builder: (context, reportSnap) {
                                final hasReport = reportSnap.hasData && reportSnap.data!.exists;
                                final statusColor = hasReport ? const Color(0xFF10B981) : Colors.amber;
                                final statusText = hasReport ? 'Sudah Diisi' : 'Belum Lengkap';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
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
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Get.to(() => TeacherRaporDetailPage(
                                              schoolId: widget.schoolId,
                                              classId: widget.classId,
                                              className: widget.className,
                                              teacherId: widget.teacherId,
                                              studentId: studentId,
                                              studentName: name,
                                              studentNis: nis,
                                            ));
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          children: [
                                            // Avatar Bulat
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: isDark 
                                                  ? Colors.white.withValues(alpha: 0.1) 
                                                  : const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                              child: Text(
                                                name.isNotEmpty ? name[0].toUpperCase() : 'M',
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            // Informasi Murid
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: TextStyle(
                                                      color: titleColor,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'NIS: $nis • Gender: $gender',
                                                    style: TextStyle(
                                                      color: subTextColor,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Badge Status Rapor
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: iconColor.withValues(alpha: 0.4),
                                              size: 14,
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
