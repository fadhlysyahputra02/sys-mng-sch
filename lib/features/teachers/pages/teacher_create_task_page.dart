import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../tasks/services/task_service.dart';
import '../../../core/localization/app_localization.dart';

class TeacherCreateTaskPage extends StatefulWidget {
  final String teacherId;
  final Map<String, Map<String, dynamic>> classMap;
  final String tahunAjaran;
  final String semester;

  const TeacherCreateTaskPage({
    super.key,
    required this.teacherId,
    required this.classMap,
    required this.tahunAjaran,
    required this.semester,
  });

  @override
  State<TeacherCreateTaskPage> createState() => _TeacherCreateTaskPageState();
}

class _TeacherCreateTaskPageState extends State<TeacherCreateTaskPage> {
  final _taskService = TaskService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _attachmentLinkController = TextEditingController();

  String? _selectedClassId;
  String? _selectedSubjectId;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  bool _isSaving = false;
  bool _syncToGrades = false;

  @override
  void initState() {
    super.initState();
    // Default select first class if available
    if (widget.classMap.isNotEmpty) {
      _selectedClassId = widget.classMap.keys.first;
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E1B4B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDueDate = pickedDate;
      });
    }
  }

  Future<void> _pickDueTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedDueTime ?? const TimeOfDay(hour: 23, minute: 59),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E1B4B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedDueTime = pickedTime;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassId == null || _selectedSubjectId == null) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Peringatan' : 'Warning',
        AppLocalization.isIndonesian
            ? 'Pilih kelas dan mata pelajaran target'
            : 'Please select target class and subject',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    if (_selectedDueDate == null || _selectedDueTime == null) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Peringatan' : 'Warning',
        AppLocalization.isIndonesian
            ? 'Tentukan tenggat tanggal dan jam pengumpulan'
            : 'Please specify submission due date and time',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final user = SessionService.currentUser!;
    try {
      final finalDueDate = DateTime(
        _selectedDueDate!.year,
        _selectedDueDate!.month,
        _selectedDueDate!.day,
        _selectedDueTime!.hour,
        _selectedDueTime!.minute,
      );

      final className = widget.classMap[_selectedClassId!]?['className']?.toString() ?? 'Kelas';
      final subjects = widget.classMap[_selectedClassId!]?['subjects'] as Map<String, String>? ?? {};
      final subjectName = subjects[_selectedSubjectId!] ?? 'Mata Pelajaran';

      await _taskService.createTask(
        schoolId: user.schoolId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        subjectId: _selectedSubjectId!,
        subjectName: subjectName,
        classId: _selectedClassId!,
        className: className,
        teacherId: widget.teacherId,
        teacherName: user.nama,
        dueDate: finalDueDate,
        attachmentLink: _attachmentLinkController.text.trim().isNotEmpty
            ? _attachmentLinkController.text.trim()
            : null,
        tahunAjaran: widget.tahunAjaran,
        semester: widget.semester,
        syncToGrades: _syncToGrades,
      );

      Get.back();
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Sukses' : 'Success',
        AppLocalization.isIndonesian
            ? 'Tugas berhasil diterbitkan untuk kelas $className'
            : 'Task successfully published for class $className',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Gagal' : 'Failed',
        AppLocalization.isIndonesian ? 'Gagal menerbitkan tugas: $e' : 'Failed to publish task: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
        final shadowColor = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.04);

        // Subjects list matching the selected class
        Map<String, String> currentSubjectsList = {};
        if (_selectedClassId != null) {
          final classData = widget.classMap[_selectedClassId!];
          if (classData != null && classData['subjects'] != null) {
            currentSubjectsList = Map<String, String>.from(classData['subjects'] as Map);
          }
        }

        return Scaffold(
          body: AuthBackground(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: CustomScrollView(
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
                      AppLocalization.isIndonesian ? 'Buat Tugas Baru' : 'Create New Task',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cardBorderColor),
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Judul Tugas
                              Text(
                                AppLocalization.isIndonesian ? 'Judul Tugas' : 'Task Title',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _titleController,
                                style: TextStyle(color: titleColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: AppLocalization.isIndonesian ? 'Masukkan judul tugas...' : 'Enter task title...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                  fillColor: inputFillColor,
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return AppLocalization.isIndonesian ? 'Judul tugas wajib diisi' : 'Task title is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Deskripsi Tugas
                              Text(
                                AppLocalization.isIndonesian ? 'Instruksi / Deskripsi Tugas' : 'Task Instructions / Description',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 5,
                                style: TextStyle(color: titleColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: AppLocalization.isIndonesian
                                      ? 'Tulis instruksi pengerjaan tugas secara rinci...'
                                      : 'Write detailed task instructions...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                  fillColor: inputFillColor,
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return AppLocalization.isIndonesian ? 'Deskripsi wajib diisi' : 'Description is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Target Kelas & Mapel
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalization.isIndonesian ? 'Kelas' : 'Class',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          value: _selectedClassId,
                                          dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                          decoration: InputDecoration(
                                            fillColor: inputFillColor,
                                            filled: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                          ),
                                          style: TextStyle(color: titleColor, fontSize: 13),
                                          items: widget.classMap.keys.map((classId) {
                                            return DropdownMenuItem<String>(
                                              value: classId,
                                              child: Text(widget.classMap[classId]?['className']?.toString() ?? ''),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _selectedClassId = val;
                                              _selectedSubjectId = null; // reset mapel
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalization.subjectLabel,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButtonFormField<String>(
                                          isExpanded: true,
                                          value: _selectedSubjectId,
                                          dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                          decoration: InputDecoration(
                                            fillColor: inputFillColor,
                                            filled: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                          ),
                                          style: TextStyle(color: titleColor, fontSize: 13),
                                          items: currentSubjectsList.keys.map((subId) {
                                            return DropdownMenuItem<String>(
                                              value: subId,
                                              child: Text(currentSubjectsList[subId] ?? ''),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            setState(() {
                                              _selectedSubjectId = val;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Tenggat Waktu (DueDate)
                              Text(
                                AppLocalization.isIndonesian ? 'Tenggat Waktu Pengumpulan' : 'Submission Deadline',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Tanggal Button
                                  Expanded(
                                    child: ElevatedButton.styleFrom(
                                      backgroundColor: inputFillColor,
                                      foregroundColor: titleColor,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ).buttons(
                                      onPressed: _pickDueDate,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedDueDate == null
                                                ? (AppLocalization.isIndonesian ? 'Pilih Tanggal' : 'Select Date')
                                                : DateFormat('dd/MM/yyyy').format(_selectedDueDate!),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Jam Button
                                  Expanded(
                                    child: ElevatedButton.styleFrom(
                                      backgroundColor: inputFillColor,
                                      foregroundColor: titleColor,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ).buttons(
                                      onPressed: _pickDueTime,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 16),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedDueTime == null
                                                ? (AppLocalization.isIndonesian ? 'Pilih Jam' : 'Select Time')
                                                : '${_selectedDueTime!.hour.toString().padLeft(2, '0')}:${_selectedDueTime!.minute.toString().padLeft(2, '0')}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Link Lampiran (Opsional)
                              Text(
                                AppLocalization.isIndonesian ? 'Link Lampiran / Materi (Opsional)' : 'Attachment Link / Material (Optional)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _attachmentLinkController,
                                style: TextStyle(color: titleColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: AppLocalization.isIndonesian ? 'Contoh: https://drive.google.com/drive/...' : 'e.g. https://drive.google.com/drive/...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                  fillColor: inputFillColor,
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  prefixIcon: Icon(Icons.link_rounded, color: subTextColor, size: 20),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Sinkronisasi ke Buku Nilai
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalization.isIndonesian ? 'Sinkronisasi ke Buku Nilai' : 'Sync to Gradebook',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: titleColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          AppLocalization.isIndonesian
                                              ? 'Otomatis masukkan nilai tugas ini ke dalam rekapitulasi nilai akademik kelas.'
                                              : 'Automatically include this task score into class academic gradebook.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: subTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _syncToGrades,
                                    activeTrackColor: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                                    activeThumbColor: const Color(0xFF8B5CF6),
                                    onChanged: (val) {
                                      setState(() {
                                        _syncToGrades = val;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Submit Button
                              ElevatedButton(
                                onPressed: _isSaving ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        AppLocalization.isIndonesian ? 'Terbitkan Tugas' : 'Publish Task',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                              ),
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
        );
      },
    );
  }
}

// Extension to avoid custom button builder conflicts
extension _ElevatedButtonsExtension on ButtonStyle {
  Widget buttons({required VoidCallback onPressed, required Widget child}) {
    return ElevatedButton(
      style: this,
      onPressed: onPressed,
      child: child,
    );
  }
}
