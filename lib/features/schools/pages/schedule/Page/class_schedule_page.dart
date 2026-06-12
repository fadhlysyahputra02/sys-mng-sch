import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
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
  ];

  ClassSchedulePage({
    super.key,
    required this.classId,
    required this.className,
  });

  final _service = ClassScheduleService();

  int _timeToMinutes(String value) {
    final parts = value.split(':');

    if (parts.length != 2) {
      return 0;
    }

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return (hours * 60) + minutes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jadwal $className')),
      body: StreamBuilder(
        stream: _service.getSchedulesByClass(classId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('Belum ada jadwal'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: _weekdays.map((day) {
              final dayDocs =
                  docs
                      .where((doc) => (doc.data()['hari'] ?? '') == day)
                      .toList()
                    ..sort((left, right) {
                      final leftStart = left.data()['jamMulai'] ?? '';
                      final rightStart = right.data()['jamMulai'] ?? '';

                      return _timeToMinutes(
                        leftStart.toString(),
                      ).compareTo(_timeToMinutes(rightStart.toString()));
                    });

              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (dayDocs.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Belum ada jadwal'),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('No')),
                            DataColumn(label: Text('Mata Pelajaran')),
                            DataColumn(label: Text('Jam')),
                            DataColumn(label: Text('Guru')),
                          ],
                          rows: dayDocs.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value.data();

                            return DataRow(
                              cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(Text(data['subjectName'] ?? '')),
                                DataCell(
                                  Text(
                                    '${data['jamMulai'] ?? ''} - ${data['jamSelesai'] ?? ''}',
                                  ),
                                ),
                                DataCell(Text(data['teacherName'] ?? '')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          _showAddScheduleDialog(context);
        },
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    String hari = 'Senin';
    String jenisJadwal = 'pelajaran';
    String? selectedSubjectId;
    String? selectedTeacherId;
    String? selectedSubjectName;
    String? selectedTeacherName;
    String jamMulai = '';
    String jamSelesai = '';

    Future<void> pickTime({
      required bool isStart,
      required void Function(void Function()) dialogSetState,
    }) async {
      final initialValue = isStart ? jamMulai : jamSelesai;
      final hasInitialValue = initialValue.isNotEmpty;
      final initialHour = hasInitialValue
          ? int.tryParse(initialValue.split(':').first) ?? 7
          : 7;
      final initialMinute = hasInitialValue
          ? int.tryParse(initialValue.split(':').last) ?? 0
          : 0;

      int selectedHour = initialHour;
      int selectedMinute = initialMinute;

      await showCupertinoModalPopup<void>(
        context: context,
        builder: (pickerContext) {
          return Container(
            height: 280,
            color: Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isStart ? 'Pilih Jam Mulai' : 'Pilih Jam Selesai',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
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
                        child: const Text('Simpan'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: initialHour,
                          ),
                          itemExtent: 36,
                          onSelectedItemChanged: (value) {
                            selectedHour = value;
                          },
                          children: List.generate(
                            24,
                            (index) => Center(
                              child: Text(index.toString().padLeft(2, '0')),
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: FixedExtentScrollController(
                            initialItem: initialMinute,
                          ),
                          itemExtent: 36,
                          onSelectedItemChanged: (value) {
                            selectedMinute = value;
                          },
                          children: List.generate(
                            60,
                            (index) => Center(
                              child: Text(index.toString().padLeft(2, '0')),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget buildTimeField({
      required String label,
      required String? value,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value ?? 'Tap untuk pilih jam'),
              const Icon(Icons.schedule),
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
              title: const Text('Tambah Jadwal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: jenisJadwal,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Jadwal',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'pelajaran',
                          child: Text('Jam Pelajaran'),
                        ),
                        DropdownMenuItem(
                          value: 'istirahat',
                          child: Text('Jam Istirahat'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          jenisJadwal = value!;

                          if (jenisJadwal == 'istirahat') {
                            selectedSubjectId = null;
                            selectedTeacherId = null;
                            selectedSubjectName = null;
                            selectedTeacherName = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: hari,
                      decoration: const InputDecoration(labelText: 'Hari'),
                      items: const [
                        DropdownMenuItem(value: 'Senin', child: Text('Senin')),
                        DropdownMenuItem(
                          value: 'Selasa',
                          child: Text('Selasa'),
                        ),
                        DropdownMenuItem(value: 'Rabu', child: Text('Rabu')),
                        DropdownMenuItem(value: 'Kamis', child: Text('Kamis')),
                        DropdownMenuItem(value: 'Jumat', child: Text('Jumat')),
                        DropdownMenuItem(value: 'Sabtu', child: Text('Sabtu')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          hari = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    AbsorbPointer(
                      absorbing: jenisJadwal == 'istirahat',
                      child: Opacity(
                        opacity: jenisJadwal == 'istirahat' ? 0.45 : 1,
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _subjectService.getSubjects(
                                SessionService.currentUser!.schoolId,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }

                                final docs = snapshot.data!.docs;

                                return DropdownButtonFormField<String>(
                                  initialValue: selectedSubjectId,
                                  decoration: const InputDecoration(
                                    labelText: 'Mata Pelajaran',
                                  ),
                                  items: docs.map((doc) {
                                    final data = doc.data();

                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(data['namaMapel'] ?? ''),
                                      onTap: () {},
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedSubjectId = value;

                                      final selectedDoc = docs.firstWhere(
                                        (e) => e.id == value,
                                      );

                                      selectedSubjectName = selectedDoc
                                          .data()['namaMapel'];
                                    });
                                  },
                                );
                              },
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    AbsorbPointer(
                      absorbing: jenisJadwal == 'istirahat',
                      child: Opacity(
                        opacity: jenisJadwal == 'istirahat' ? 0.45 : 1,
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _teacherService.getTeachers(
                                SessionService.currentUser!.schoolId,
                              ),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const CircularProgressIndicator();
                                }

                                final docs = snapshot.data!.docs;

                                return DropdownButtonFormField<String>(
                                  initialValue: selectedTeacherId,
                                  decoration: const InputDecoration(
                                    labelText: 'Guru Pengajar',
                                  ),
                                  items: docs.map((doc) {
                                    final teacher = doc.data();

                                    return DropdownMenuItem<String>(
                                      value: doc.id,
                                      onTap: () {},
                                      child: Text(teacher['nama'] ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTeacherId = value;

                                      final selectedDoc = docs.firstWhere(
                                        (e) => e.id == value,
                                      );

                                      selectedTeacherName = selectedDoc
                                          .data()['nama'];
                                    });
                                  },
                                );
                              },
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    buildTimeField(
                      label: 'Jam Mulai',
                      value: jamMulai,
                      onTap: () async {
                        await pickTime(isStart: true, dialogSetState: setState);
                      },
                    ),

                    const SizedBox(height: 12),

                    buildTimeField(
                      label: 'Jam Selesai',
                      value: jamSelesai,
                      onTap: () async {
                        await pickTime(
                          isStart: false,
                          dialogSetState: setState,
                        );
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Batal'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (jamMulai.isEmpty || jamSelesai.isEmpty) {
                      return;
                    }

                    if (jenisJadwal == 'pelajaran' &&
                        (selectedSubjectId == null ||
                            selectedTeacherId == null)) {
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

                        hari: hari,

                        jamMulai: jamMulai,

                        jamSelesai: jamSelesai,
                      );

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
