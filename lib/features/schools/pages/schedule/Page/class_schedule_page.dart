import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../subjects/data/subject_service.dart';
import '../../teachers/data/teacher_service.dart';
import '../Service/class_schedule_service.dart';

class ClassSchedulePage extends StatelessWidget {
  final String classId;
  final String className;
  final SubjectService _subjectService = SubjectService();
  final TeacherService _teacherService = TeacherService();
  static const List<String> _weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  ClassSchedulePage({
    super.key,
    required this.classId,
    required this.className,
  });

  final _service = ClassScheduleService();

  int _timeToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return (hours * 60) + minutes;
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC4899);

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final textMainColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

        return Scaffold(
          body: AuthBackground(
            child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: backButtonColor, size: 20),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Jadwal $className',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showDeleteByClassConfirmationDialog(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 18),
                                if (MediaQuery.of(context).size.width > 600) ...[
                                  const SizedBox(width: 6),
                                  const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
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
                          colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showAddScheduleDialog(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                if (MediaQuery.of(context).size.width > 600) ...[
                                  const SizedBox(width: 6),
                                  const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
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
            Expanded(
              child: StreamBuilder(
        stream: _service.getSchedulesByClass(
          SessionService.currentUser!.schoolId,
          classId,
        ),
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
                  Text('Terjadi kesalahan memuat jadwal.', style: TextStyle(color: textMainColor, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 52,
                      color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1E1B4B).withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Belum ada jadwal',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap tombol "Tambah" untuk mulai mengisi.',
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            children: _weekdays.map((day) {
              final dayDocs = docs
                  .where((doc) => (doc.data()['hari'] ?? '') == day)
                  .toList()
                ..sort((left, right) {
                  final leftStart = left.data()['jamMulai'] ?? '';
                  final rightStart = right.data()['jamMulai'] ?? '';
                  return _timeToMinutes(leftStart.toString())
                      .compareTo(_timeToMinutes(rightStart.toString()));
                });

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (dayDocs.isEmpty
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFEC4899).withValues(alpha: 0.1))
                            : (dayDocs.isEmpty
                                ? Colors.black.withValues(alpha: 0.03)
                                : const Color(0xFFEC4899).withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? (dayDocs.isEmpty
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFEC4899).withValues(alpha: 0.3))
                              : (dayDocs.isEmpty
                                  ? Colors.black.withValues(alpha: 0.08)
                                  : const Color(0xFFEC4899).withValues(alpha: 0.25)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: isDark
                                ? (dayDocs.isEmpty ? Colors.white54 : const Color(0xFFEC4899))
                                : (dayDocs.isEmpty ? const Color(0xFF1E1B4B).withValues(alpha: 0.5) : const Color(0xFFEC4899)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            day,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? (dayDocs.isEmpty ? Colors.white70 : Colors.white)
                                  : (dayDocs.isEmpty ? const Color(0xFF1E1B4B).withValues(alpha: 0.6) : const Color(0xFF1E1B4B)),
                            ),
                          ),
                          if (dayDocs.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showDeleteByDayConfirmationDialog(context, day),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 14),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (dayDocs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'Tidak ada jadwal pada hari ini',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF1E1B4B).withValues(alpha: 0.45),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 740,
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(160), // Jam (widened)
                                1: FlexColumnWidth(2.5),  // Mata Pelajaran
                                2: FlexColumnWidth(2.5),  // Guru
                                3: FixedColumnWidth(130),   // Aksi (widened)
                              },
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                            // Header Row
                            TableRow(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                              ),
                              children: [
                                _buildTableCell('Jam', isHeader: true, isDark: isDark),
                                _buildTableCell('Mata Pelajaran', isHeader: true, isDark: isDark),
                                _buildTableCell('Guru', isHeader: true, isDark: isDark),
                                _buildTableCell('Aksi', isHeader: true, isDark: isDark, isCenter: true),
                              ],
                            ),
                            // Data Rows
                            ...dayDocs.map((doc) {
                              final data = doc.data();
                              final isIstirahat = data['jenisJadwal'] == 'istirahat';
                              final scheduleId = doc.id;

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: isIstirahat
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                children: [
                                  // Jam Cell
                                  _buildTableCell(
                                    '${data['jamMulai'] ?? ''} - ${data['jamSelesai'] ?? ''}',
                                    isHeader: false,
                                    isDark: isDark,
                                    textStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isIstirahat ? const Color(0xFFF59E0B) : primaryColor,
                                    ),
                                  ),
                                  // Mata Pelajaran Cell
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: isIstirahat
                                        ? Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                              ),
                                              child: const Text(
                                                'Istirahat',
                                                style: TextStyle(
                                                  color: Color(0xFFF59E0B),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            data['subjectName'] ?? '-',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                  // Guru Cell
                                  _buildTableCell(
                                    isIstirahat ? '-' : (data['teacherName'] ?? '-'),
                                    isHeader: false,
                                    isDark: isDark,
                                  ),
                                  // Aksi Cell
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                                          onPressed: () => _showAddScheduleDialog(context, existingSchedule: data, scheduleId: scheduleId),
                                          tooltip: 'Edit Jadwal',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                          onPressed: () => _deleteSchedule(context, scheduleId),
                                          tooltip: 'Hapus Jadwal',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  )
                  ],
                ),
              );
            }).toList(),
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
  }

  Future<void> _deleteSchedule(BuildContext context, String scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0C20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hapus Jadwal',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'Apakah Anda yakin ingin menghapus jadwal ini?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    ) ?? false;

    if (confirm && context.mounted) {
      try {
        await _service.deleteSchedule(
          schoolId: SessionService.currentUser!.schoolId,
          scheduleId: scheduleId,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Jadwal berhasil dihapus')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _showAddScheduleDialog(BuildContext context, {Map<String, dynamic>? existingSchedule, String? scheduleId}) {
    String? hari = existingSchedule?['hari'];
    String jenisJadwal = existingSchedule?['jenisJadwal'] ?? 'pelajaran';
    String? selectedSubjectId = existingSchedule?['subjectId'];
    String? selectedTeacherId = existingSchedule?['teacherId'];
    String? selectedSubjectName = existingSchedule?['subjectName'];
    String? selectedTeacherName = existingSchedule?['teacherName'];
    String jamMulai = existingSchedule?['jamMulai'] ?? '';
    String jamSelesai = existingSchedule?['jamSelesai'] ?? '';


    Widget buildTimeInput({
      required String label,
      required String initialValue,
      required IconData icon,
      required ValueChanged<String> onChanged,
    }) {
      return TextFormField(
        initialValue: initialValue,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFFEC4899), size: 20),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          hintText: '00:00',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFEC4899), width: 1.5),
          ),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [TimeTextInputFormatter()],
        onChanged: onChanged,
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F0C20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              title: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Color(0xFFEC4899), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    scheduleId != null ? 'Edit Jadwal' : 'Tambah Jadwal',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Jenis jadwal toggle
                    Row(
                      children: ['pelajaran', 'istirahat'].map((jenis) {
                        final selected = jenisJadwal == jenis;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: jenis == 'pelajaran' ? 6 : 0),
                            child: GestureDetector(
                              onTap: () => setState(() {
                                jenisJadwal = jenis;
                                if (jenis == 'istirahat') {
                                  selectedSubjectId = null;
                                  selectedTeacherId = null;
                                  selectedSubjectName = null;
                                  selectedTeacherName = null;
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? const LinearGradient(
                                          colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                                        )
                                      : null,
                                  color: selected ? null : Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFEC4899).withOpacity(0.4)
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      jenis == 'pelajaran' ? Icons.menu_book_rounded : Icons.free_breakfast_rounded,
                                      size: 16,
                                      color: selected ? Colors.white : Colors.white.withOpacity(0.5),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      jenis == 'pelajaran' ? 'Pelajaran' : 'Istirahat',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: selected ? Colors.white : Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Hari dropdown
                    DropdownButtonFormField<String>(
                      value: hari,
                      dropdownColor: const Color(0xFF0F0C20),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Hari',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFFEC4899), size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFEC4899), width: 1.5),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Senin', child: Text('Senin', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Selasa', child: Text('Selasa', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Rabu', child: Text('Rabu', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Kamis', child: Text('Kamis', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Jumat', child: Text('Jumat', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Sabtu', child: Text('Sabtu', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(value: 'Minggu', child: Text('Minggu', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (value) => setState(() => hari = value),
                    ),

                    const SizedBox(height: 16),

                    // Mata Pelajaran
                    AbsorbPointer(
                      absorbing: jenisJadwal == 'istirahat',
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: jenisJadwal == 'istirahat' ? 0.4 : 1,
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _subjectService.getSubjects(SessionService.currentUser!.schoolId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const LinearProgressIndicator(color: Color(0xFFEC4899));
                            }
                            final docs = snapshot.data!.docs;
                            return InkWell(
                              onTap: () async {
                                List<Map<String, dynamic>> subjectItems = [];
                                if (selectedTeacherId != null) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(color: Color(0xFFEC4899)),
                                    ),
                                  );

                                  try {
                                    final schoolId = SessionService.currentUser!.schoolId;
                                    final assignedDocs = await FirebaseFirestore.instance
                                        .collection('schools')
                                        .doc(schoolId)
                                        .collection('teacher_subjects')
                                        .where('teacherId', isEqualTo: selectedTeacherId)
                                        .get();
                                    final assignedSubjectIds = assignedDocs.docs
                                        .map((doc) => doc.data()['subjectId'] as String)
                                        .toSet();

                                    subjectItems = docs.map((doc) => {
                                      'id': doc.id,
                                      'name': doc.data()['namaMapel']?.toString() ?? '',
                                    }).where((item) => assignedSubjectIds.contains(item['id'])).toList();
                                  } catch (e) {
                                    subjectItems = docs.map((doc) => {
                                      'id': doc.id,
                                      'name': doc.data()['namaMapel']?.toString() ?? '',
                                    }).toList();
                                  } finally {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                } else {
                                  subjectItems = docs.map((doc) => {
                                    'id': doc.id,
                                    'name': doc.data()['namaMapel']?.toString() ?? '',
                                  }).toList();
                                }

                                if (context.mounted) {
                                  _showSearchableSelectDialog(
                                    context: context,
                                    title: 'Pilih Mata Pelajaran',
                                    items: subjectItems,
                                    selectedValue: selectedSubjectId,
                                    onSelected: (id, name) {
                                      setState(() {
                                        if (id.isEmpty) {
                                          selectedSubjectId = null;
                                          selectedSubjectName = null;
                                        } else {
                                          selectedSubjectId = id;
                                          selectedSubjectName = name;
                                        }
                                      });
                                    },
                                  );
                                }
                              },
                              child: IgnorePointer(
                                child: TextFormField(
                                  key: ValueKey('subject_${selectedSubjectId ?? 'none'}'),
                                  initialValue: selectedSubjectName ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Mata Pelajaran',
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                    prefixIcon: const Icon(Icons.menu_book_rounded, color: Color(0xFFEC4899), size: 20),
                                    suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.03),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFEC4899), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Guru
                    AbsorbPointer(
                      absorbing: jenisJadwal == 'istirahat',
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: jenisJadwal == 'istirahat' ? 0.4 : 1,
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _teacherService.getTeachers(SessionService.currentUser!.schoolId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const LinearProgressIndicator(color: Color(0xFFEC4899));
                            }
                            final docs = snapshot.data!.docs;
                            return InkWell(
                              onTap: () async {
                                List<Map<String, dynamic>> teacherItems = [];
                                if (selectedSubjectId != null) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(color: Color(0xFFEC4899)),
                                    ),
                                  );

                                  try {
                                    final schoolId = SessionService.currentUser!.schoolId;
                                    final assignedDocs = await FirebaseFirestore.instance
                                        .collection('schools')
                                        .doc(schoolId)
                                        .collection('teacher_subjects')
                                        .where('subjectId', isEqualTo: selectedSubjectId)
                                        .get();
                                    final assignedTeacherIds = assignedDocs.docs
                                        .map((doc) => doc.data()['teacherId'] as String)
                                        .toSet();

                                    teacherItems = docs.map((doc) => {
                                      'id': doc.id,
                                      'name': doc.data()['nama']?.toString() ?? '',
                                    }).where((item) => assignedTeacherIds.contains(item['id'])).toList();
                                  } catch (e) {
                                    teacherItems = docs.map((doc) => {
                                      'id': doc.id,
                                      'name': doc.data()['nama']?.toString() ?? '',
                                    }).toList();
                                  } finally {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  }
                                } else {
                                  teacherItems = docs.map((doc) => {
                                    'id': doc.id,
                                    'name': doc.data()['nama']?.toString() ?? '',
                                  }).toList();
                                }

                                if (context.mounted) {
                                  _showSearchableSelectDialog(
                                    context: context,
                                    title: 'Pilih Guru Pengajar',
                                    items: teacherItems,
                                    selectedValue: selectedTeacherId,
                                    onSelected: (id, name) {
                                      setState(() {
                                        if (id.isEmpty) {
                                          selectedTeacherId = null;
                                          selectedTeacherName = null;
                                        } else {
                                          selectedTeacherId = id;
                                          selectedTeacherName = name;
                                        }
                                      });
                                    },
                                  );
                                }
                              },
                              child: IgnorePointer(
                                child: TextFormField(
                                  key: ValueKey('teacher_${selectedTeacherId ?? 'none'}'),
                                  initialValue: selectedTeacherName ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    labelText: 'Guru Pengajar',
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                    prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFFEC4899), size: 20),
                                    suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.03),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFEC4899), width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Time inputs
                    Row(
                      children: [
                        Expanded(
                          child: buildTimeInput(
                            label: 'Jam Mulai',
                            initialValue: jamMulai,
                            icon: Icons.play_arrow_rounded,
                            onChanged: (val) => setState(() => jamMulai = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: buildTimeInput(
                            label: 'Jam Selesai',
                            initialValue: jamSelesai,
                            icon: Icons.stop_rounded,
                            onChanged: (val) => setState(() => jamSelesai = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final selectedHari = hari;
                            if (selectedHari == null || selectedHari.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(content: Text('Silakan pilih hari terlebih dahulu')),
                              );
                              return;
                            }
                            if (jamMulai.isEmpty || jamSelesai.isEmpty) return;
                            if (jenisJadwal == 'pelajaran' &&
                                (selectedSubjectId == null || selectedTeacherId == null)) {
                              return;
                            }
                            try {
                              await _service.addSchedule(
                                schoolId: SessionService.currentUser!.schoolId,
                                classId: classId,
                                className: className,
                                jenisJadwal: jenisJadwal,
                                subjectId: selectedSubjectId ?? '',
                                subjectName: selectedSubjectName ?? '',
                                teacherId: selectedTeacherId ?? '',
                                teacherName: selectedTeacherName ?? '',
                                hari: selectedHari,
                                jamMulai: jamMulai,
                                jamSelesai: jamSelesai,
                                scheduleId: scheduleId,
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(scheduleId != null ? 'Jadwal berhasil diupdate' : 'Jadwal berhasil ditambahkan')),
                                );
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                showDialog(
                                  context: dialogContext,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF0F0C20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: BorderSide(color: Colors.red.withOpacity(0.5), width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.all(24),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          scheduleId != null ? 'Gagal Mengupdate Jadwal' : 'Gagal Menambahkan Jadwal',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          e.toString().replaceFirst('Exception: ', ''),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Simpan',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteByClassConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hapus Jadwal Kelas?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin menghapus seluruh jadwal untuk kelas $className?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                      );

                      try {
                        await _service.deleteSchedulesByClass(SessionService.currentUser!.schoolId, classId);
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Jadwal kelas berhasil dihapus.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal menghapus jadwal: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showDeleteByDayConfirmationDialog(BuildContext context, String hari) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0C20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'Hapus Jadwal $hari?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin menghapus jadwal $className pada hari $hari?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Batal', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        ),
                      );

                      try {
                        await _service.deleteSchedulesByClassAndDay(SessionService.currentUser!.schoolId, classId, hari);
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Jadwal $hari berhasil dihapus.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // close loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal menghapus jadwal: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableCell(
    String text, {
    required bool isHeader,
    required bool isDark,
    bool isCenter = false,
    TextStyle? textStyle,
  }) {
    final defaultStyle = isHeader
        ? TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF1E1B4B),
            fontSize: 13,
          )
        : TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF1E1B4B).withValues(alpha: 0.8),
            fontSize: 13,
          );

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Align(
          alignment: isCenter ? Alignment.center : Alignment.centerLeft,
          child: Text(
            text,
            style: textStyle ?? defaultStyle,
          ),
        ),
      ),
    );
  }

  void _showSearchableSelectDialog({
    required BuildContext context,
    required String title,
    required List<Map<String, dynamic>> items,
    required String? selectedValue,
    required Function(String id, String name) onSelected,
  }) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredItems = items
                .where((item) => item['name']!
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()))
                .toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF0F0C20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
              ),
              title: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cari...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFEC4899), size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFEC4899), width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: filteredItems.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Text(
                                'Tidak ditemukan',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final id = item['id']?.toString() ?? '';
                                final name = item['name']?.toString() ?? '';
                                final isSelected = id == selectedValue;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFEC4899).withOpacity(0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        color: isSelected ? const Color(0xFFEC4899) : Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFFEC4899), size: 20)
                                        : null,
                                    onTap: () {
                                      onSelected(id, name);
                                      Navigator.pop(dialogContext);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (selectedValue != null && selectedValue.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      onSelected('', '');
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Kosongkan Pilihan', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (newText.length > 4) newText = newText.substring(0, 4);

    String formattedText = newText;
    if (newText.length >= 3) {
      formattedText = '${newText.substring(0, 2)}:${newText.substring(2)}';
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
