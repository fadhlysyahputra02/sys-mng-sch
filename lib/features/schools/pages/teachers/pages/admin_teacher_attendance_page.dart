import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../../../officer/data/officer_repository.dart';
import '../data/teacher_service.dart';

class AdminTeacherAttendancePage extends StatefulWidget {
  const AdminTeacherAttendancePage({super.key});

  @override
  State<AdminTeacherAttendancePage> createState() => _AdminTeacherAttendancePageState();
}

class _AdminTeacherAttendancePageState extends State<AdminTeacherAttendancePage> {
  final _teacherService = TeacherService();
  final _repo = OfficerRepository();
  
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  String _selectedStatusFilter = 'Semua'; // 'Semua', 'Hadir', 'Terlambat', 'Sakit', 'Izin', 'Alfa'

  String _getDateStr(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getFormattedIndonesianDate(DateTime date) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '--:--';
    final date = timestamp.toDate().toLocal();
    return DateFormat('HH:mm').format(date);
  }

  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        final isDark = AuthBackground.isDarkMode.value;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1B4B),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF0F0C20),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF1E1B4B),
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status.toLowerCase()) {
      case 'hadir':
        color = const Color(0xFF10B981);
        label = 'Hadir';
        break;
      case 'terlambat':
        color = const Color(0xFFF59E0B);
        label = 'Terlambat';
        break;
      case 'sakit':
        color = const Color(0xFF3B82F6);
        label = 'Sakit';
        break;
      case 'izin':
        color = const Color(0xFF8B5CF6);
        label = 'Izin';
        break;
      case 'alfa':
        color = const Color(0xFFEF4444);
        label = 'Alfa';
        break;
      default:
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showEditAttendanceModal({
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required String nip,
    required Map<String, dynamic>? currentData,
  }) {
    final isDark = AuthBackground.isDarkMode.value;
    final textThemeColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final cardBg = isDark ? const Color(0xFF1A162B) : const Color(0xFFF8FAFC);
    
    String tempStatus = currentData != null ? (currentData['status'] ?? 'hadir') : 'alfa';
    DateTime? tempCheckIn = (currentData?['checkInTime'] as Timestamp?)?.toDate();
    DateTime? tempCheckOut = (currentData?['checkOutTime'] as Timestamp?)?.toDate();
    final reasonController = TextEditingController(text: currentData?['reason'] ?? '');

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setModalState) {
          final isCheckInEnabled = tempStatus == 'hadir' || tempStatus == 'terlambat';
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0C20) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Presensi Manual',
                              style: TextStyle(color: textThemeColor, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$teacherName (NIP: $nip)',
                              style: TextStyle(color: textThemeColor.withValues(alpha: 0.6), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: textThemeColor.withValues(alpha: 0.6)),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Status Dropdown
                  Text(
                    'Status Kehadiran',
                    style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempStatus.toLowerCase(),
                        dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                        style: TextStyle(color: textThemeColor, fontSize: 14, fontWeight: FontWeight.w600),
                        icon: Icon(Icons.arrow_drop_down_rounded, color: textThemeColor),
                        items: const [
                          DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                          DropdownMenuItem(value: 'terlambat', child: Text('Terlambat')),
                          DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                          DropdownMenuItem(value: 'izin', child: Text('Izin')),
                          DropdownMenuItem(value: 'alfa', child: Text('Alfa (Belum Absen)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              tempStatus = val;
                              if (val == 'hadir' || val == 'terlambat') {
                                tempCheckIn ??= DateTime(
                                  _selectedDate.year,
                                  _selectedDate.month,
                                  _selectedDate.day,
                                  7,
                                  0,
                                );
                              } else {
                                tempCheckIn = null;
                                tempCheckOut = null;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Jam Masuk & Pulang
                  if (isCheckInEnabled) ...[
                    Row(
                      children: [
                        // Jam Masuk Picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jam Masuk',
                                style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(tempCheckIn ?? DateTime.now()),
                                  );
                                  if (time != null) {
                                    setModalState(() {
                                      tempCheckIn = DateTime(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: textThemeColor.withValues(alpha: 0.6), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        tempCheckIn != null ? DateFormat('HH:mm').format(tempCheckIn!) : '--:--',
                                        style: TextStyle(color: textThemeColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Jam Pulang Picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jam Pulang',
                                style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(tempCheckOut ?? DateTime.now()),
                                  );
                                  if (time != null) {
                                    setModalState(() {
                                      tempCheckOut = DateTime(
                                        _selectedDate.year,
                                        _selectedDate.month,
                                        _selectedDate.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: textThemeColor.withValues(alpha: 0.6), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        tempCheckOut != null ? DateFormat('HH:mm').format(tempCheckOut!) : '--:--',
                                        style: TextStyle(color: textThemeColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Catatan / Keterangan
                  Text(
                    'Catatan / Alasan',
                    style: TextStyle(color: textThemeColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    style: TextStyle(color: textThemeColor),
                    decoration: InputDecoration(
                      hintText: 'Tulis keterangan (misal: Sakit Flu, Dispensasi)...',
                      hintStyle: TextStyle(color: textThemeColor.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDark ? BorderSide.none : const BorderSide(color: Colors.black12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Simpan Button
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final dateStr = _getDateStr(_selectedDate);
                        await _repo.markTeacherAttendanceManual(
                          schoolId: schoolId,
                          teacherId: teacherId,
                          teacherName: teacherName,
                          nip: nip,
                          dateStr: dateStr,
                          status: tempStatus,
                          checkInTime: tempCheckIn,
                          checkOutTime: tempCheckOut,
                        );

                        // Simpan reason ke document attendance jika ada reason
                        if (reasonController.text.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('schools')
                              .doc(schoolId)
                              .collection('teacher_daily_attendance')
                              .doc('${dateStr}_$teacherId')
                              .update({
                            'reason': reasonController.text,
                          });
                        }

                        Get.back();
                        Get.snackbar(
                          'Sukses',
                          'Presensi guru berhasil diperbarui.',
                          backgroundColor: const Color(0xFF10B981),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                          borderRadius: 12,
                        );
                      } catch (e) {
                        Get.snackbar(
                          'Gagal',
                          e.toString(),
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                          borderRadius: 12,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Simpan Perubahan',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;
    final dateStr = _getDateStr(_selectedDate);

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, child) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
        final shadowColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04);
        final searchBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9);

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B0914) : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
              onPressed: () => Get.back(),
            ),
            title: Text(
              'Absensi Harian Guru',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.calendar_month_rounded, color: textColor),
                onPressed: _showDatePicker,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // Selected Date Card Header
                GestureDetector(
                  onTap: _showDatePicker,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF8B5CF6), size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _getFormattedIndonesianDate(_selectedDate),
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Search & Filter Section
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: searchBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                        ),
                        child: TextField(
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cari nama guru...',
                            hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 18),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Filter Selector
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatusFilter,
                          dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                          icon: Icon(Icons.filter_list_rounded, color: textColor, size: 16),
                          items: const [
                            DropdownMenuItem(value: 'Semua', child: Text('Semua')),
                            DropdownMenuItem(value: 'Hadir', child: Text('Hadir')),
                            DropdownMenuItem(value: 'Terlambat', child: Text('Terlambat')),
                            DropdownMenuItem(value: 'Sakit', child: Text('Sakit')),
                            DropdownMenuItem(value: 'Izin', child: Text('Izin')),
                            DropdownMenuItem(value: 'Alfa', child: Text('Alfa')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedStatusFilter = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Streams for Teachers List and Daily Attendance Records
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _teacherService.getTeachers(schoolId),
                    builder: (context, teacherSnapshot) {
                      if (teacherSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                      }
                      if (!teacherSnapshot.hasData || teacherSnapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text('Belum ada data guru terdaftar.', style: TextStyle(color: subTextColor)),
                        );
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('schools')
                            .doc(schoolId)
                            .collection('teacher_daily_attendance')
                            .where('date', isEqualTo: dateStr)
                            .snapshots(),
                        builder: (context, attendanceSnapshot) {
                          if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                          }

                          // Mapping: teacherId -> attendanceDocData
                          final Map<String, Map<String, dynamic>> attMap = {};
                          if (attendanceSnapshot.hasData) {
                            for (var doc in attendanceSnapshot.data!.docs) {
                              final d = doc.data();
                              final tId = d['teacherId'] as String?;
                              if (tId != null) {
                                attMap[tId] = d;
                              }
                            }
                          }

                          final teachersList = teacherSnapshot.data!.docs;
                          final processedList = <Map<String, dynamic>>[];

                          // Hitung statistik
                          int countHadir = 0;
                          int countTerlambat = 0;
                          int countIzinSakit = 0;
                          int countAlfa = 0;

                          for (var doc in teachersList) {
                            final tData = doc.data();
                            final tId = doc.id;
                            final name = tData['nama'] ?? 'Guru';
                            final nip = tData['nip'] ?? '';
                            
                            final attendance = attMap[tId];
                            final status = attendance != null ? (attendance['status'] ?? 'hadir') : 'alfa';

                            if (status == 'hadir') countHadir++;
                            if (status == 'terlambat') countTerlambat++;
                            if (status == 'sakit' || status == 'izin') countIzinSakit++;
                            if (status == 'alfa') countAlfa++;

                            // Filter Pencarian Nama
                            if (_searchQuery.isNotEmpty &&
                                !name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                              continue;
                            }

                            // Filter Status
                            if (_selectedStatusFilter != 'Semua') {
                              if (_selectedStatusFilter == 'Hadir' && status != 'hadir') continue;
                              if (_selectedStatusFilter == 'Terlambat' && status != 'terlambat') continue;
                              if (_selectedStatusFilter == 'Sakit' && status != 'sakit') continue;
                              if (_selectedStatusFilter == 'Izin' && status != 'izin') continue;
                              if (_selectedStatusFilter == 'Alfa' && status != 'alfa') continue;
                            }

                            processedList.add({
                              'teacherId': tId,
                              'teacherName': name,
                              'nip': nip,
                              'status': status,
                              'attendance': attendance,
                            });
                          }

                          // Urutkan nama guru secara alfabetis
                          processedList.sort((a, b) => (a['teacherName'] as String).compareTo(b['teacherName'] as String));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Statistik Widget Row
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildStatTile('Hadir', '$countHadir', const Color(0xFF10B981), cardColor, cardBorder),
                                    const SizedBox(width: 10),
                                    _buildStatTile('Terlambat', '$countTerlambat', const Color(0xFFF59E0B), cardColor, cardBorder),
                                    const SizedBox(width: 10),
                                    _buildStatTile('Izin/Sakit', '$countIzinSakit', const Color(0xFF3B82F6), cardColor, cardBorder),
                                    const SizedBox(width: 10),
                                    _buildStatTile('Belum Absen', '$countAlfa', const Color(0xFFEF4444), cardColor, cardBorder),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Header list
                              Row(
                                children: [
                                  Icon(Icons.people_rounded, color: textColor.withValues(alpha: 0.8), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Daftar Kehadiran Guru (${processedList.length})',
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // List View
                              Expanded(
                                child: processedList.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Tidak ada data guru yang sesuai filter.',
                                          style: TextStyle(color: subTextColor, fontSize: 14),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: processedList.length,
                                        physics: const BouncingScrollPhysics(),
                                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final item = processedList[index];
                                          final tId = item['teacherId'] as String;
                                          final name = item['teacherName'] as String;
                                          final nip = item['nip'] as String;
                                          final status = item['status'] as String;
                                          final att = item['attendance'] as Map<String, dynamic>?;

                                          final checkInTime = att != null ? att['checkInTime'] as Timestamp? : null;
                                          final checkOutTime = att != null ? att['checkOutTime'] as Timestamp? : null;

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: cardBorder),
                                              boxShadow: [
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
                                                onTap: () => _showEditAttendanceModal(
                                                  schoolId: schoolId,
                                                  teacherId: tId,
                                                  teacherName: name,
                                                  nip: nip,
                                                  currentData: att,
                                                ),
                                                borderRadius: BorderRadius.circular(16),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              name,
                                                              style: TextStyle(
                                                                color: textColor,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'NIP: $nip',
                                                              style: TextStyle(color: subTextColor, fontSize: 12),
                                                            ),
                                                            if (checkInTime != null) ...[
                                                              const SizedBox(height: 6),
                                                              Row(
                                                                children: [
                                                                  Icon(Icons.login_rounded, color: const Color(0xFF10B981).withValues(alpha: 0.8), size: 12),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    _formatTime(checkInTime),
                                                                    style: TextStyle(color: subTextColor, fontSize: 12),
                                                                  ),
                                                                  const SizedBox(width: 12),
                                                                  Icon(Icons.logout_rounded, color: Colors.orange.withValues(alpha: 0.8), size: 12),
                                                                  const SizedBox(width: 4),
                                                                  Text(
                                                                    checkOutTime != null ? _formatTime(checkOutTime) : '--:--',
                                                                    style: TextStyle(color: subTextColor, fontSize: 12),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      _buildStatusBadge(status),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatTile(String label, String value, Color color, Color cardBg, Color cardBorder) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
