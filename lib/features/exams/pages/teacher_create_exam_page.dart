import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_model.dart';
import '../services/exam_service.dart';


class TeacherCreateExamPage extends StatefulWidget {
  final String teacherId;
  final Map<String, Map<String, dynamic>> classMap;
  final String tahunAjaran;
  final String semester;

  const TeacherCreateExamPage({
    super.key,
    required this.teacherId,
    required this.classMap,
    required this.tahunAjaran,
    required this.semester,
  });

  @override
  State<TeacherCreateExamPage> createState() => _TeacherCreateExamPageState();
}

class _TeacherCreateExamPageState extends State<TeacherCreateExamPage> {
  final _examService = ExamService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '60');

  String? _selectedClassId;
  String? _selectedSubjectId;
  DateTime? _selectedDueDate;
  TimeOfDay? _selectedDueTime;
  bool _isSaving = false;
  bool _syncToGrades = false;
  String _gradeCategory = 'Kuis';

  // State List untuk menyimpan input pertanyaan dinamis
  final List<Map<String, dynamic>> _questionsData = [];

  @override
  void initState() {
    super.initState();
    if (widget.classMap.isNotEmpty) {
      _selectedClassId = widget.classMap.keys.first;
    }
    // Default tambahkan 1 soal kosong
    _addQuestion();
  }

  void _addQuestion() {
    setState(() {
      _questionsData.add({
        'questionController': TextEditingController(),
        'options': List.generate(4, (_) => TextEditingController()),
        'correctIndex': 0,
        'type': 'multiple_choice',
        'pointsController': TextEditingController(text: '10'),
      });
    });
  }

  void _addOption(int qIndex) {
    final q = _questionsData[qIndex];
    final opts = q['options'] as List<TextEditingController>;
    if (opts.length >= 10) {
      Get.snackbar('Batas Maksimal', 'Pilihan jawaban maksimal 10 opsi.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.amber,
          colorText: Colors.black);
      return;
    }
    setState(() {
      opts.add(TextEditingController());
    });
  }

  void _removeOption(int qIndex, int optIdx) {
    final q = _questionsData[qIndex];
    final opts = q['options'] as List<TextEditingController>;
    if (opts.length <= 2) {
      Get.snackbar('Batas Minimal', 'Pilihan jawaban minimal 2 opsi.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.amber,
          colorText: Colors.black);
      return;
    }
    setState(() {
      opts[optIdx].dispose();
      opts.removeAt(optIdx);
      // Clamp correctIndex jika melebihi jumlah opsi
      final currentCorrect = q['correctIndex'] as int;
      if (currentCorrect >= opts.length) {
        q['correctIndex'] = opts.length - 1;
      }
    });
  }

  void _removeQuestion(int index) {
    if (_questionsData.length <= 1) {
      Get.snackbar(
        'Info',
        'Ujian minimal harus memiliki 1 pertanyaan.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
      );
      return;
    }
    setState(() {
      final q = _questionsData.removeAt(index);
      q['questionController'].dispose();
      q['pointsController'].dispose();
      for (final ctrl in (q['options'] as List<TextEditingController>)) {
        ctrl.dispose();
      }
    });
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
        Get.snackbar('Peringatan', 'Pilih kelas dan mata pelajaran target',
            backgroundColor: Colors.amber, colorText: Colors.black);
        return;
      }

      if (_selectedDueDate == null || _selectedDueTime == null) {
        Get.snackbar('Peringatan', 'Tentukan tenggat tanggal dan jam ujian',
            backgroundColor: Colors.amber, colorText: Colors.black);
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

      // Parse list soal inputan menjadi ExamQuestion model
      final List<ExamQuestion> questionsList = [];
      for (int i = 0; i < _questionsData.length; i++) {
        final qMap = _questionsData[i];
        final qText = (qMap['questionController'] as TextEditingController).text.trim();
        final type = qMap['type'] as String? ?? 'multiple_choice';
        final points = int.tryParse((qMap['pointsController'] as TextEditingController).text.trim()) ?? 10;

        List<String> optList = [];
        int correctIdx = 0;

        if (type == 'multiple_choice') {
          optList = (qMap['options'] as List<TextEditingController>)
              .map((ctrl) => ctrl.text.trim())
              .toList();
          correctIdx = qMap['correctIndex'] as int;
        }

        questionsList.add(ExamQuestion(
          id: 'q_${i + 1}_${DateTime.now().millisecondsSinceEpoch}',
          questionText: qText,
          options: optList,
          correctOptionIndex: correctIdx,
          type: type,
          points: points,
        ));
      }

      final newExamId = await _examService.createExam(
        schoolId: user.schoolId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        classId: _selectedClassId!,
        className: className,
        subjectId: _selectedSubjectId!,
        subjectName: subjectName,
        teacherId: widget.teacherId,
        teacherName: user.nama,
        durationMinutes: int.tryParse(_durationController.text.trim()) ?? 60,
        syncToGrades: _syncToGrades,
        gradeCategory: _gradeCategory,
        tahunAjaran: widget.tahunAjaran,
        semester: widget.semester,
        dueDate: finalDueDate,
        questions: questionsList,
      );

      Get.back();
      Get.snackbar(
        'Sukses',
        'Ujian Online "$subjectName" berhasil diterbitkan untuk kelas $className',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal menerbitkan ujian: $e',
          backgroundColor: const Color(0xFFEF4444), colorText: Colors.white);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    for (final q in _questionsData) {
      q['questionController'].dispose();
      q['pointsController'].dispose();
      for (final ctrl in (q['options'] as List<TextEditingController>)) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        int totalExamPoints = 0;
        for (final q in _questionsData) {
          final ptsVal = (q['pointsController'] as TextEditingController).text.trim();
          final pts = int.tryParse(ptsVal) ?? 0;
          totalExamPoints += pts;
        }

        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

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
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    title: Text(
                      'Terbitkan Ujian Baru',
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
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                                // Kelas Dropdown
                                Text('Kelas Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedClassId,
                                  dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                  decoration: InputDecoration(
                                    fillColor: inputFillColor,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorderColor),
                                    ),
                                  ),
                                  style: TextStyle(color: titleColor, fontSize: 14),
                                  items: widget.classMap.keys.map((classId) {
                                    return DropdownMenuItem(
                                      value: classId,
                                      child: Text(widget.classMap[classId]?['className']?.toString() ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedClassId = val;
                                      _selectedSubjectId = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Mapel Dropdown
                                Text('Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _selectedSubjectId,
                                  dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                  decoration: InputDecoration(
                                    fillColor: inputFillColor,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorderColor),
                                    ),
                                  ),
                                  style: TextStyle(color: titleColor, fontSize: 14),
                                  items: currentSubjectsList.keys.map((subjectId) {
                                    return DropdownMenuItem(
                                      value: subjectId,
                                      child: Text(currentSubjectsList[subjectId] ?? ''),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedSubjectId = val;
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),

                              // Judul Ujian
                              Text('Judul Ujian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _titleController,
                                style: TextStyle(color: titleColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Masukkan judul ujian...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                  fillColor: inputFillColor,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Judul tidak boleh kosong' : null,
                              ),
                              const SizedBox(height: 20),

                              // Deskripsi Ujian
                              Text('Petunjuk / Deskripsi Ujian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 3,
                                style: TextStyle(color: titleColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Tulis petunjuk pengerjaan ujian...',
                                  hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                  fillColor: inputFillColor,
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: cardBorderColor),
                                  ),
                                ),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Deskripsi tidak boleh kosong' : null,
                              ),
                              const SizedBox(height: 20),

                              // Durasi Ujian & Batas Waktu
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Durasi Ujian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _durationController,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(color: titleColor, fontSize: 14),
                                          decoration: InputDecoration(
                                            suffixText: 'Menit',
                                            fillColor: inputFillColor,
                                            filled: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(color: cardBorderColor),
                                            ),
                                          ),
                                          validator: (val) {
                                            final d = int.tryParse(val ?? '');
                                            if (d == null || d <= 0) return 'Input salah';
                                            return null;
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
                                        Text('Batas Ujian Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: _pickDueDate,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: inputFillColor,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: cardBorderColor),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _selectedDueDate == null
                                                        ? 'Pilih Tanggal'
                                                        : DateFormat('dd MMM yyyy').format(_selectedDueDate!),
                                                    style: TextStyle(
                                                      color: _selectedDueDate == null ? subTextColor : titleColor,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Icon(Icons.calendar_today_rounded, size: 16, color: titleColor),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Jam Batas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: _pickDueTime,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: inputFillColor,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: cardBorderColor),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    _selectedDueTime == null
                                                        ? 'Pilih Jam'
                                                        : _selectedDueTime!.format(context),
                                                    style: TextStyle(
                                                      color: _selectedDueTime == null ? subTextColor : titleColor,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Icon(Icons.access_time_rounded, size: 16, color: titleColor),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Sinkronisasi Buku Nilai
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Sinkronisasi ke Buku Nilai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Otomatis masukkan nilai hasil ujian ke Buku Nilai akademik kelas.',
                                          style: TextStyle(fontSize: 11, color: subTextColor),
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
                              if (_syncToGrades) ...[
                                const SizedBox(height: 16),
                                Text('Kategori Buku Nilai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: _gradeCategory,
                                  dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                  decoration: InputDecoration(
                                    fillColor: inputFillColor,
                                    filled: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: cardBorderColor),
                                    ),
                                  ),
                                  style: TextStyle(color: titleColor, fontSize: 14),
                                  items: const [
                                    DropdownMenuItem(value: 'Kuis', child: Text('Kuis')),
                                    DropdownMenuItem(value: 'Ulangan Harian', child: Text('Ulangan Harian')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _gradeCategory = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                              const SizedBox(height: 24),
                              Divider(color: cardBorderColor),
                              const SizedBox(height: 16),

                              // LIST SOAL UJIAN
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Daftar Soal Ujian',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _questionsData.length,
                                itemBuilder: (context, index) {
                                  final qMap = _questionsData[index];
                                  final qCtrl = qMap['questionController'] as TextEditingController;
                                  final optCtrls = qMap['options'] as List<TextEditingController>;
                                  final qType = qMap['type'] as String? ?? 'multiple_choice';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: cardBorderColor),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Pertanyaan ${index + 1}',
                                              style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 13),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                              onPressed: () => _removeQuestion(index),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Input Tipe & Poin Soal
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Tipe Soal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: titleColor)),
                                                  const SizedBox(height: 6),
                                                  DropdownButtonFormField<String>(
                                                    value: qType,
                                                    dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                                                    decoration: InputDecoration(
                                                      fillColor: inputFillColor,
                                                      filled: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                        borderSide: BorderSide(color: cardBorderColor),
                                                      ),
                                                    ),
                                                    style: TextStyle(color: titleColor, fontSize: 13),
                                                    items: const [
                                                      DropdownMenuItem(value: 'multiple_choice', child: Text('Pilihan Ganda')),
                                                      DropdownMenuItem(value: 'essay', child: Text('Essay')),
                                                    ],
                                                    onChanged: (val) {
                                                      if (val != null) {
                                                        setState(() {
                                                          qMap['type'] = val;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 1,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Poin Soal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: titleColor)),
                                                  const SizedBox(height: 6),
                                                  TextFormField(
                                                    controller: qMap['pointsController'] as TextEditingController,
                                                    keyboardType: TextInputType.number,
                                                    style: TextStyle(color: titleColor, fontSize: 13),
                                                    decoration: InputDecoration(
                                                      fillColor: inputFillColor,
                                                      filled: true,
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(10),
                                                        borderSide: BorderSide(color: cardBorderColor),
                                                      ),
                                                    ),
                                                    onChanged: (val) {
                                                      setState(() {});
                                                    },
                                                    validator: (val) {
                                                      final p = int.tryParse(val ?? '');
                                                      if (p == null || p <= 0) return 'Invalid';
                                                      return null;
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        // Input Pertanyaan
                                        Text('Pertanyaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: titleColor)),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: qCtrl,
                                          maxLines: 2,
                                          style: TextStyle(color: titleColor, fontSize: 13),
                                          decoration: InputDecoration(
                                            hintText: 'Tulis pertanyaan...',
                                            hintStyle: TextStyle(color: subTextColor, fontSize: 12),
                                            fillColor: inputFillColor,
                                            filled: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide(color: cardBorderColor),
                                            ),
                                          ),
                                          validator: (val) => val == null || val.trim().isEmpty ? 'Soal tidak boleh kosong' : null,
                                        ),

                                        // Input Pilihan Jawaban (Hanya jika Pilihan Ganda)
                                        if (qType == 'multiple_choice') ...[
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Pilihan Jawaban (tandai jawaban benar)',
                                                style: TextStyle(fontWeight: FontWeight.w600, color: subTextColor, fontSize: 11),
                                              ),
                                              Row(
                                                children: [
                                                  // Tombol hapus opsi
                                                  if (optCtrls.length > 2)
                                                    GestureDetector(
                                                      onTap: () => _removeOption(index, optCtrls.length - 1),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.redAccent.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                                                        ),
                                                        child: const Icon(Icons.remove_rounded, size: 14, color: Colors.redAccent),
                                                      ),
                                                    ),
                                                  const SizedBox(width: 6),
                                                  // Tombol tambah opsi
                                                  if (optCtrls.length < 10)
                                                    GestureDetector(
                                                      onTap: () => _addOption(index),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                                        ),
                                                        child: const Icon(Icons.add_rounded, size: 14, color: Color(0xFF8B5CF6)),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          Column(
                                            children: List.generate(optCtrls.length, (optIdx) {
                                              final charLabel = String.fromCharCode(65 + optIdx); // A, B, C, D, E, ...
                                              final isCorrect = qMap['correctIndex'] == optIdx;

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8.0),
                                                child: Row(
                                                  children: [
                                                    Radio<int>(
                                                      value: optIdx,
                                                      groupValue: qMap['correctIndex'] as int,
                                                      activeColor: const Color(0xFF8B5CF6),
                                                      onChanged: (val) {
                                                        if (val != null) {
                                                          setState(() {
                                                            qMap['correctIndex'] = val;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                    Expanded(
                                                      child: TextFormField(
                                                        controller: optCtrls[optIdx],
                                                        style: TextStyle(
                                                          color: titleColor,
                                                          fontSize: 13,
                                                          fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                        decoration: InputDecoration(
                                                          hintText: 'Pilihan $charLabel',
                                                          hintStyle: TextStyle(color: subTextColor, fontSize: 12),
                                                          fillColor: isCorrect
                                                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.08)
                                                              : inputFillColor,
                                                          filled: true,
                                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                          enabledBorder: OutlineInputBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                            borderSide: BorderSide(
                                                              color: isCorrect ? const Color(0xFF8B5CF6) : cardBorderColor,
                                                            ),
                                                          ),
                                                        ),
                                                        validator: (val) => val == null || val.trim().isEmpty ? 'Pilihan tidak boleh kosong' : null,
                                                      ),
                                                    ),
                                                    // Tombol hapus opsi individual
                                                    if (optCtrls.length > 2)
                                                      IconButton(
                                                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                                        onPressed: () => _removeOption(index, optIdx),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Tombol Tambah Soal di bawah pertanyaan terakhir
                              Center(
                                child: OutlinedButton.icon(
                                  onPressed: _addQuestion,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF8B5CF6),
                                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                  label: const Text('Tambah Pertanyaan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(height: 32),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Poin Ujian:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: titleColor,
                                      ),
                                    ),
                                    Text(
                                      '$totalExamPoints Poin',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF8B5CF6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

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
                                    : const Text(
                                        'Terbitkan Ujian Online',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
