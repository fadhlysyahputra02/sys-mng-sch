import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../authentication/widgets/auth_background.dart';

class TeacherPermitsPage extends StatefulWidget {
  final String? teacherDocId;
  final String? schoolId;
  final bool hideBackButton;

  const TeacherPermitsPage({
    super.key,
    this.teacherDocId,
    this.schoolId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherPermitsPage> createState() => _TeacherPermitsPageState();
}

class _TeacherPermitsPageState extends State<TeacherPermitsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _teacherDocId;
  late String _schoolId;
  bool _isArgumentsLoaded = false;

  Set<String> _teacherClassIds = {};
  Set<String> _scheduleClassIds = {};
  Set<String> _waliClassIds = {};
  bool _isLoadingInfo = true;
  StreamSubscription? _schedulesSub;
  StreamSubscription? _classesSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isArgumentsLoaded) {
      if (widget.teacherDocId != null && widget.schoolId != null) {
        _teacherDocId = widget.teacherDocId!;
        _schoolId = widget.schoolId!;
      } else {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        _teacherDocId = args['teacherDocId']?.toString() ?? '';
        _schoolId = args['schoolId']?.toString() ?? '';
      }
      _isArgumentsLoaded = true;
      _loadTeacherClassesInfo();
    }
  }

  void _loadTeacherClassesInfo() {
    _schedulesSub?.cancel();
    _schedulesSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(_schoolId)
        .collection('class_schedules')
        .where('teacherId', isEqualTo: _teacherDocId)
        .snapshots()
        .listen((schedulesSnap) {
      final scheduleClassIds = schedulesSnap.docs
          .map((d) => d.data()['classId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();

      if (mounted) {
        setState(() {
          _scheduleClassIds = scheduleClassIds;
          _teacherClassIds = {..._scheduleClassIds, ..._waliClassIds};
          _isLoadingInfo = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error loading schedules stream: $e');
    });

    _classesSub?.cancel();
    _classesSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(_schoolId)
        .collection('classes')
        .where('teacherId', isEqualTo: _teacherDocId)
        .snapshots()
        .listen((waliKelasSnap) {
      final waliClassIds = waliKelasSnap.docs.map((d) => d.id).toSet();

      if (mounted) {
        setState(() {
          _waliClassIds = waliClassIds;
          _teacherClassIds = {..._scheduleClassIds, ..._waliClassIds};
          _isLoadingInfo = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error loading classes stream: $e');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _schedulesSub?.cancel();
    _classesSub?.cancel();
    super.dispose();
  }

  Future<void> _processPermit({
    required String permitId,
    required Map<String, dynamic> permitData,
    required String targetStatus, // Disetujui / Ditolak
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      );

      final firestore = FirebaseFirestore.instance;

      // 1. Update status di dokumen permit
      await firestore
          .collection('schools')
          .doc(_schoolId)
          .collection('permits')
          .doc(permitId)
          .update({'status': targetStatus});

      // 2. Jika disetujui, tulis record kehadiran siswa secara otomatis
      if (targetStatus == 'Disetujui') {
        final studentId = permitData['studentId']?.toString() ?? '';
        final studentName = permitData['studentName']?.toString() ?? '';
        final classId = permitData['classId']?.toString() ?? '';
        final className = permitData['className']?.toString() ?? '';
        final jenis = permitData['jenis']?.toString() ?? 'Izin'; // Sakit / Izin
        final tglMulaiStr = permitData['tanggalMulai']?.toString() ?? '';
        final tglSelesaiStr = permitData['tanggalSelesai']?.toString() ?? '';

        if (studentId.isNotEmpty && tglMulaiStr.isNotEmpty && tglSelesaiStr.isNotEmpty) {
          // Ambil metadata tahun ajaran dan semester aktif dari settingan admin sekolah
          final schoolDoc = await firestore.collection('schools').doc(_schoolId).get();
          final tahunAjaran = schoolDoc.data()?['tahunAjaran']?.toString() ??
              '${DateTime.now().year}/${DateTime.now().year + 1}';
          final semester = schoolDoc.data()?['semester']?.toString() ?? 'Semester 1';

          final start = DateTime.parse(tglMulaiStr);
          final end = DateTime.parse(tglSelesaiStr);
          final daysCount = end.difference(start).inDays;

          // Ambil daftar jadwal pelajaran kelas murid
          final schedulesSnap = await firestore
              .collection('schools')
              .doc(_schoolId)
              .collection('class_schedules')
              .where('classId', isEqualTo: classId)
              .get();

          // Looping untuk menulis record kehadiran per hari
          for (int i = 0; i <= daysCount; i++) {
            final date = start.add(Duration(days: i));
            final dateStr = DateFormat('yyyy-MM-dd').format(date);

            // 1. Tulis ke koleksi attendance (untuk histori personal/kelas siswa)
            await firestore
                .collection('schools')
                .doc(_schoolId)
                .collection('attendance')
                .doc('${studentId}_$dateStr')
                .set({
              'studentId': studentId,
              'studentName': studentName,
              'classId': classId,
              'className': className,
              'date': dateStr,
              'timestamp': FieldValue.serverTimestamp(),
              'status': jenis, // Set status sesuai jenis izin: Sakit / Izin
              'tahunAjaran': tahunAjaran,
              'semester': semester,
            });

            // 2. Tulis ke koleksi daily_attendance (untuk rekap harian gerbang/petugas)
            await firestore
                .collection('schools')
                .doc(_schoolId)
                .collection('daily_attendance')
                .doc('${dateStr}_$studentId')
                .set({
              'studentId': studentId,
              'studentName': studentName,
              'classId': classId,
              'className': className,
              'date': dateStr,
              'timestamp': FieldValue.serverTimestamp(),
              'status': jenis.toLowerCase(), // Status berformat kecil: sakit / izin
              'method': 'surat_izin',
              'officerId': _teacherDocId,
              'tahunAjaran': tahunAjaran,
              'semester': semester,
              'expireAt': Timestamp.fromDate(
                DateTime.now().add(const Duration(days: 365 * 5)),
              ),
            }, SetOptions(merge: true));

            // 3. Tulis ke koleksi attendance mata pelajaran (untuk rekap per mapel)
            final daysIndo = {
              DateTime.monday: 'Senin',
              DateTime.tuesday: 'Selasa',
              DateTime.wednesday: 'Rabu',
              DateTime.thursday: 'Kamis',
              DateTime.friday: 'Jumat',
              DateTime.saturday: 'Sabtu',
              DateTime.sunday: 'Minggu',
            };
            final dayIndo = daysIndo[date.weekday] ?? '';

            final todaySchedules = schedulesSnap.docs.where((doc) {
              final data = doc.data();
              return data['hari']?.toString().toLowerCase() == dayIndo.toLowerCase();
            }).toList();

            for (final schedDoc in todaySchedules) {
              final schedData = schedDoc.data();
              final scheduleId = schedDoc.id;
              final subjectName = schedData['subjectName']?.toString() ?? '-';

              await firestore
                  .collection('schools')
                  .doc(_schoolId)
                  .collection('attendance')
                  .doc('${studentId}_${scheduleId}_$dateStr')
                  .set({
                'studentId': studentId,
                'studentName': studentName,
                'classId': classId,
                'className': className,
                'scheduleId': scheduleId,
                'subjectName': subjectName,
                'date': dateStr,
                'timestamp': FieldValue.serverTimestamp(),
                'status': jenis, // 'Sakit' or 'Izin'
                'tahunAjaran': tahunAjaran,
                'semester': semester,
                'method': 'surat_izin',
              });
            }
          }
        }
      }

      if (mounted) {
        Navigator.pop(context); // Tutup loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Surat izin berhasil ${targetStatus.toLowerCase()}.'),
            backgroundColor: targetStatus == 'Disetujui' ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading dialog
      Get.snackbar('Error', 'Gagal memproses surat izin: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  void _confirmProcessPermit(String permitId, Map<String, dynamic> permit, String status) {
    final isDark = AuthBackground.isDarkMode.value;
    final isApprove = status == 'Disetujui';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isApprove ? 'Setujui Surat Izin' : 'Tolak Surat Izin',
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1B4B)),
          ),
          content: Text(
            isApprove
                ? 'Apakah Anda yakin ingin menyetujui surat izin dari "${permit['studentName']}"?\n\nAbsensi siswa untuk tanggal tersebut otomatis akan tercatat sebagai "${permit['jenis']}".'
                : 'Apakah Anda yakin ingin menolak surat izin dari "${permit['studentName']}"?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                _processPermit(permitId: permitId, permitData: permit, targetStatus: status);
              },
              child: Text(isApprove ? 'Setujui' : 'Tolak'),
            ),
          ],
        );
      },
    );
  }

  void _showPermitDetail(Map<String, dynamic> permit) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final isPending = permit['status'] == 'Pending';
    final isApproved = permit['status'] == 'Disetujui';
    final statusColor = isApproved
        ? const Color(0xFF10B981)
        : (isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detail Surat Izin',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  permit['status'] ?? 'Pending',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Nama Siswa', permit['studentName'] ?? '-', textColor),
                _buildInfoRow('Kelas', permit['className'] ?? '-', textColor),
                _buildInfoRow('Pengirim', '${permit['parentName']} (Orang Tua)', textColor),
                _buildInfoRow('Jenis Izin', permit['jenis'] ?? '-', textColor),
                _buildInfoRow('Tanggal', '${permit['tanggalMulai']} s.d ${permit['tanggalSelesai']}', textColor),
                const Divider(height: 24),
                Text(
                  'Alasan / Keterangan:',
                  style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  permit['alasan'] ?? '-',
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                ),
                if (permit['buktiBase64'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Lampiran Bukti:',
                    style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        base64Decode(permit['buktiBase64']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String val, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Text(val, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermitList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, Color textColor, Color subTextColor, Color cardBgColor, Color cardBorderColor, bool isDark) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline_rounded, size: 48, color: textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              'Tidak ada surat izin.',
              style: TextStyle(color: subTextColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final permit = doc.data();
        final dateRange = permit['tanggalMulai'] == permit['tanggalSelesai']
            ? permit['tanggalMulai']
            : '${permit['tanggalMulai']} s.d ${permit['tanggalSelesai']}';
        final type = permit['jenis'] ?? 'Sakit';
        final isPending = permit['status'] == 'Pending';
        final isApproved = permit['status'] == 'Disetujui';
        final statusColor = isApproved
            ? const Color(0xFF10B981)
            : (isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorderColor),
          ),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (type == 'Sakit' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    type == 'Sakit' ? Icons.sick_rounded : Icons.info_rounded,
                    color: type == 'Sakit' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        permit['studentName'] ?? '-',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        permit['status'] ?? 'Pending',
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      'Jenis: $type • Kelas: ${permit['className']}',
                      style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tanggal: $dateRange',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Alasan: ${permit['alasan']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward_ios_rounded, color: textColor.withValues(alpha: 0.3), size: 16),
                onTap: () => _showPermitDetail(permit),
              ),
              if (isPending) ...[
                if (permit['teacherId'] == _teacherDocId) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _confirmProcessPermit(doc.id, permit, 'Ditolak'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Tolak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => _confirmProcessPermit(doc.id, permit, 'Disetujui'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            elevation: 0,
                          ),
                          child: const Text('Setujui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue.shade400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Hanya Wali Kelas (${permit['teacherName'] ?? '-'}) yang dapat memproses.',
                            style: TextStyle(
                              fontSize: 11,
                              color: textColor.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        if (!widget.hideBackButton) ...[
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daftar Surat Izin Siswa',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              Text(
                                'Kelola permohonan izin dari Wali Murid',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab Bar
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF6366F1),
                    unselectedLabelColor: subTextColor,
                    indicatorColor: const Color(0xFF6366F1),
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Perlu Diproses'),
                      Tab(text: 'Riwayat'),
                    ],
                  ),

                  // Tab View
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .doc(_schoolId)
                          .collection('permits')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting || _isLoadingInfo) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];

                        final filteredDocs = docs.where((doc) {
                          final data = doc.data();
                          final permitTeacherId = data['teacherId']?.toString() ?? '';
                          final permitClassId = data['classId']?.toString() ?? '';
                          return permitTeacherId == _teacherDocId || _teacherClassIds.contains(permitClassId);
                        }).toList();

                        final pendingDocs = filteredDocs.where((d) => d.data()['status'] == 'Pending').toList();
                        final historyDocs = filteredDocs.where((d) => d.data()['status'] != 'Pending').toList();

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPermitList(pendingDocs, textColor, subTextColor, cardBgColor, cardBorderColor, isDark),
                            _buildPermitList(historyDocs, textColor, subTextColor, cardBgColor, cardBorderColor, isDark),
                          ],
                        );
                      },
                    ),
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
