import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../data/officer_repository.dart';

class ManualAttendancePage extends StatefulWidget {
  const ManualAttendancePage({super.key});

  @override
  State<ManualAttendancePage> createState() => _ManualAttendancePageState();
}

class _ManualAttendancePageState extends State<ManualAttendancePage> {
  final OfficerRepository _repo = OfficerRepository();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  bool _isLoading = false;

  void _showAttendanceDialog(Map<String, dynamic> student, String studentId) {
    final statuses = ['hadir', 'terlambat', 'alpha', 'izin', 'sakit'];
    String selectedStatus = 'hadir';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final isDark = AuthBackground.isDarkMode.value;
          final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Absen Manual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Siswa: ${student['nama'] ?? '-'}',
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                  Text(
                    'Kelas: ${student['className'] ?? '-'}',
                    style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 24),
                  Text('Pilih Status:', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    dropdownColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: textColor.withValues(alpha: 0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    items: statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase(), style: TextStyle(color: textColor)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => selectedStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Batal'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          Get.back();
                          _submitManual(student, studentId, selectedStatus);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _submitManual(Map<String, dynamic> student, String studentId, String status) async {
    setState(() => _isLoading = true);
    try {
      final user = SessionService.currentUser!;
      
      final hasScanned = await _repo.hasStudentScannedToday(user.schoolId, studentId);
      if (hasScanned) {
        Get.snackbar(
          'Peringatan', 
          'Siswa ini sudah melakukan scan/absen hari ini.',
          backgroundColor: Colors.amber,
          colorText: Colors.black,
        );
        return;
      }

      await _repo.markManualAttendance(
        schoolId: user.schoolId,
        studentId: studentId,
        studentName: student['nama'] ?? '-',
        classId: student['classId'] ?? '',
        className: student['className'] ?? '-',
        officerId: user.uid,
        status: status,
      );

      Get.snackbar(
        'Berhasil', 
        'Absen manual berhasil disimpan.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );

    } catch (e) {
      Get.snackbar('Error', e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text(
              'Absensi Manual',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ),
          body: AuthBackground(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.toLowerCase());
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama siswa...',
                        hintStyle: TextStyle(color: subTextColor),
                        prefixIcon: Icon(Icons.search_rounded, color: subTextColor),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    if (_isLoading)
                      const LinearProgressIndicator(color: Color(0xFF6366F1)),
                      
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('schoolId', isEqualTo: user.schoolId)
                            .where('role', isEqualTo: 'student')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          var docs = snapshot.data?.docs ?? [];
                          
                          if (_searchQuery.isNotEmpty) {
                            docs = docs.where((doc) {
                              final name = (doc.data() as Map<String, dynamic>)['nama'].toString().toLowerCase();
                              return name.contains(_searchQuery);
                            }).toList();
                          }

                          if (docs.isEmpty) {
                            return Center(
                              child: Text('Tidak ada siswa yang ditemukan', style: TextStyle(color: subTextColor)),
                            );
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final docId = docs[index].id;
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                    child: const Icon(Icons.person, color: Color(0xFF8B5CF6)),
                                  ),
                                  title: Text(
                                    data['nama'] ?? '-',
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    'Kelas: ${data['className'] ?? '-'}',
                                    style: TextStyle(color: subTextColor, fontSize: 12),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _showAttendanceDialog(data, docId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: const Text('Absen', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
