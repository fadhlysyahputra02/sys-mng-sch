import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/services/task_service.dart';

class StudentSubmitTaskPage extends StatefulWidget {
  final String studentDocId;
  final String studentName;
  final Task task;

  const StudentSubmitTaskPage({
    super.key,
    required this.studentDocId,
    required this.studentName,
    required this.task,
  });

  @override
  State<StudentSubmitTaskPage> createState() => _StudentSubmitTaskPageState();
}

class _StudentSubmitTaskPageState extends State<StudentSubmitTaskPage> {
  final _taskService = TaskService();
  final _formKey = GlobalKey<FormState>();

  final _notesController = TextEditingController();
  final _linkController = TextEditingController();
  bool _isSaving = false;

  String _formatDateTime(DateTime dateTime) {
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${days[dateTime.weekday % 7]}, ${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} - ${DateFormat('HH:mm').format(dateTime.toLocal())} WIB';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notes = _notesController.text.trim();
    final link = _linkController.text.trim();

    // Verify at least one is filled
    if (notes.isEmpty && link.isEmpty) {
      Get.snackbar(
        'Peringatan',
        'Tolong isi catatan jawaban atau tautan file jawaban Anda.',
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
    final isLate = DateTime.now().isAfter(widget.task.dueDate);

    try {
      await _taskService.submitTask(
        schoolId: user.schoolId,
        taskId: widget.task.id,
        studentId: widget.studentDocId,
        studentName: widget.studentName,
        studentNotes: notes.isNotEmpty ? notes : null,
        answerLink: link.isNotEmpty ? link : null,
        isLate: isLate,
      );

      Get.back(); // Back to tasks list
      Get.snackbar(
        'Sukses',
        isLate
            ? 'Tugas berhasil dikumpulkan (Terlambat)'
            : 'Tugas berhasil dikumpulkan tepat waktu!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: isLate ? Colors.orange : const Color(0xFF10B981),
        colorText: Colors.white,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      Get.snackbar(
        'Gagal',
        'Gagal mengumpulkan tugas: $e',
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
    final isLate = DateTime.now().isAfter(widget.task.dueDate);

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
                      'Kumpulkan Tugas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverToBoxAdapter(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Task Summary Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.task.subjectName,
                                        style: const TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isLate)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Terlambat',
                                            style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.task.title,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Guru: ${widget.task.teacherName}',
                                    style: TextStyle(fontSize: 12, color: subTextColor),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tenggat: ${_formatDateTime(widget.task.dueDate)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isLate ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Submit Form Card
                            Container(
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
                                  // Jawaban Teks
                                  Text(
                                    'Jawaban / Catatan Anda (Opsional)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _notesController,
                                    maxLines: 4,
                                    style: TextStyle(color: titleColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Ketik jawaban esai atau catatan pengerjaan di sini...',
                                      hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Tautan Jawaban
                                  Text(
                                    'Link File Jawaban (Opsional)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _linkController,
                                    style: TextStyle(color: titleColor, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Contoh: https://drive.google.com/file/...',
                                      hintStyle: TextStyle(color: subTextColor, fontSize: 13),
                                      fillColor: inputFillColor,
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      prefixIcon: Icon(Icons.link_rounded, color: subTextColor, size: 20),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '*Anda harus mengisi minimal salah satu bidang (Catatan atau Link) sebelum mengumpulkan.',
                                    style: TextStyle(fontSize: 10, color: subTextColor, fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 32),

                                  // Submit Button
                                  ElevatedButton(
                                    onPressed: _isSaving ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isLate ? Colors.orange : const Color(0xFF8B5CF6),
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
                                            isLate ? 'Kumpulkan Terlambat' : 'Kumpulkan Sekarang',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
