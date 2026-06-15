import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Jadwal $className',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                  const Text('Terjadi kesalahan memuat jadwal.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Icon(Icons.calendar_today_rounded, size: 52, color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Belum ada jadwal',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap tombol "Tambah" untuk mulai mengisi.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: dayDocs.isEmpty
                            ? Colors.white.withValues(alpha: 0.04)
                            : primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: dayDocs.isEmpty
                              ? Colors.white.withValues(alpha: 0.07)
                              : primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            dayDocs.isEmpty ? Icons.remove_circle_outline : Icons.check_circle_rounded,
                            size: 16,
                            color: dayDocs.isEmpty ? Colors.white.withValues(alpha: 0.3) : primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            day,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: dayDocs.isEmpty ? Colors.white.withValues(alpha: 0.35) : Colors.white,
                            ),
                          ),
                          if (dayDocs.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${dayDocs.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
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
                            color: Colors.white.withValues(alpha: 0.3),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.04)),
                            headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.8)),
                            dataTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                            dividerThickness: 0.5,
                            horizontalMargin: 16,
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('Jam')),
                              DataColumn(label: Text('Mata Pelajaran')),
                              DataColumn(label: Text('Guru')),
                              DataColumn(label: Text('Aksi')),
                            ],
                            rows: dayDocs.map((doc) {
                              final data = doc.data();
                              final isIstirahat = data['jenisJadwal'] == 'istirahat';
                              final scheduleId = doc.id;

                              return DataRow(
                                color: WidgetStateProperty.all(
                                  isIstirahat
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                                      : Colors.transparent,
                                ),
                                cells: [
                                  DataCell(
                                    Text(
                                      '${data['jamMulai'] ?? ''} - ${data['jamSelesai'] ?? ''}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isIstirahat ? const Color(0xFFF59E0B) : primaryColor,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    isIstirahat
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                            ),
                                            child: const Text('Istirahat', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11)),
                                          )
                                        : Text(data['subjectName'] ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                  DataCell(Text(isIstirahat ? '-' : (data['teacherName'] ?? '-'))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                      onPressed: () => _deleteSchedule(context, scheduleId),
                                      tooltip: 'Hapus Jadwal',
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
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
      await _service.deleteSchedule(
        schoolId: SessionService.currentUser!.schoolId,
        scheduleId: scheduleId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal berhasil dihapus')),
        );
      }
    }
  }

  void _showAddScheduleDialog(BuildContext context) {
    String? hari;
    String jenisJadwal = 'pelajaran';
    String? selectedSubjectId;
    String? selectedTeacherId;
    String? selectedSubjectName;
    String? selectedTeacherName;
    String jamMulai = '';
    String jamSelesai = '';
    const primaryColor = Color(0xFFEC4899);

    Future<void> pickTime({
      required bool isStart,
      required void Function(void Function()) dialogSetState,
    }) async {
      final initialValue = isStart ? jamMulai : jamSelesai;
      final hasInitialValue = initialValue.isNotEmpty;
      final initialHour = hasInitialValue ? int.tryParse(initialValue.split(':').first) ?? 7 : 7;
      final initialMinute = hasInitialValue ? int.tryParse(initialValue.split(':').last) ?? 0 : 0;

      if (kIsWeb) {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
          initialEntryMode: TimePickerEntryMode.input,
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  onSurface: Color(0xFF1E1B4B),
                ),
                dialogTheme: const DialogThemeData(
                  backgroundColor: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          final formatted =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          dialogSetState(() {
            if (isStart) {
              jamMulai = formatted;
            } else {
              jamSelesai = formatted;
            }
          });
        }
        return;
      }

      int selectedHour = initialHour;
      int selectedMinute = initialMinute;

      await showCupertinoModalPopup<void>(
        context: context,
        builder: (pickerContext) {
          return CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
              primaryColor: Color(0xFFEC4899),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: 310,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0C20),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.08), width: 1.5),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              isStart ? 'Jam Mulai' : 'Jam Selesai',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEC4899).withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  ),
                                  onPressed: () {
                                    final formatted =
                                        '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
                                    dialogSetState(() {
                                      if (isStart) {
                                        jamMulai = formatted;
                                      } else {
                                        jamSelesai = formatted;
                                      }
                                    });
                                    Navigator.pop(pickerContext);
                                  },
                                  child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.white.withOpacity(0.08)),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(initialItem: initialHour),
                            itemExtent: 40,
                            onSelectedItemChanged: (value) => selectedHour = value,
                            children: List.generate(
                              24,
                              (index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                        VerticalDivider(width: 1, color: Colors.white.withOpacity(0.08)),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(initialItem: initialMinute),
                            itemExtent: 40,
                            onSelectedItemChanged: (value) => selectedMinute = value,
                            children: List.generate(
                              60,
                              (index) => Center(
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

    Widget buildTimeField({
      required String label,
      required String value,
      required VoidCallback onTap,
      required IconData icon,
    }) {
      final hasValue = value.isNotEmpty;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border.all(
              color: hasValue ? const Color(0xFFEC4899) : Colors.white.withOpacity(0.08),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: hasValue ? const Color(0xFFEC4899) : Colors.white.withOpacity(0.4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasValue ? value : 'Pilih $label',
                  style: TextStyle(
                    color: hasValue ? Colors.white : Colors.white.withOpacity(0.4),
                    fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: Colors.white.withOpacity(0.4), size: 20),
            ],
          ),
        ),
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
              title: const Row(
                children: [
                  Icon(Icons.schedule_rounded, color: Color(0xFFEC4899), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Tambah Jadwal',
                    style: TextStyle(
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
                      initialValue: hari,
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
                            return DropdownButtonFormField<String>(
                              initialValue: selectedSubjectId,
                              dropdownColor: const Color(0xFF0F0C20),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Mata Pelajaran',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                prefixIcon: const Icon(Icons.menu_book_rounded, color: Color(0xFFEC4899), size: 20),
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
                              items: docs.map((doc) {
                                final data = doc.data();
                                return DropdownMenuItem(
                                  value: doc.id,
                                  child: Text(data['namaMapel'] ?? '', style: const TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() {
                                selectedSubjectId = value;
                                selectedSubjectName = docs.firstWhere((e) => e.id == value).data()['namaMapel'];
                              }),
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
                            return DropdownButtonFormField<String>(
                              initialValue: selectedTeacherId,
                              dropdownColor: const Color(0xFF0F0C20),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: 'Guru Pengajar',
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFFEC4899), size: 20),
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
                              items: docs.map((doc) {
                                final teacher = doc.data();
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(teacher['nama'] ?? '', style: const TextStyle(color: Colors.white)),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() {
                                selectedTeacherId = value;
                                selectedTeacherName = docs.firstWhere((e) => e.id == value).data()['nama'];
                              }),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Time pickers
                    Row(
                      children: [
                        Expanded(
                          child: buildTimeField(
                            label: 'Jam Mulai',
                            value: jamMulai,
                            icon: Icons.play_arrow_rounded,
                            onTap: () async {
                              await pickTime(isStart: true, dialogSetState: setState);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: buildTimeField(
                            label: 'Jam Selesai',
                            value: jamSelesai,
                            icon: Icons.stop_rounded,
                            onTap: () async {
                              await pickTime(isStart: false, dialogSetState: setState);
                            },
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
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Jadwal berhasil ditambahkan')),
                                );
                              }
                            } catch (e) {
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceFirst('Exception: ', '')),
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
}

