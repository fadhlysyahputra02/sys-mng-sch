import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_model.dart';
import '../services/exam_service.dart';

class StudentTakeExamPage extends StatefulWidget {
  final Exam exam;

  const StudentTakeExamPage({super.key, required this.exam});

  @override
  State<StudentTakeExamPage> createState() => _StudentTakeExamPageState();
}

class _StudentTakeExamPageState extends State<StudentTakeExamPage> {
  final _examService = ExamService();

  bool _hasStarted = false;
  int _currentQuestionIndex = 0;
  final Map<String, int> _selectedAnswers = {}; // Map questionId -> optionIndex

  int _secondsRemaining = 0;
  Timer? _timer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.exam.durationMinutes * 60;
  }

  void _startExam() {
    setState(() {
      _hasStarted = true;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _autoSubmit();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final String hoursStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');

    return '$hoursStr$minutesStr:$secondsStr';
  }

  Future<void> _autoSubmit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    _timer?.cancel();

    final user = SessionService.currentUser!;
    try {
      await _examService.submitExam(
        schoolId: user.schoolId,
        exam: widget.exam,
        studentId: user.uid,
        studentName: user.nama,
        answers: _selectedAnswers,
      );

      Get.back();
      Get.snackbar(
        'Waktu Habis',
        'Waktu ujian telah berakhir. Jawaban Anda berhasil dikumpulkan secara otomatis.',
        backgroundColor: Colors.amber,
        colorText: Colors.black,
        duration: const Duration(seconds: 5),
      );
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'Gagal menyerahkan ujian otomatis: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> _submitExamManual() async {
    final unansweredCount = widget.exam.questions.length - _selectedAnswers.length;
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          title: Text('Kumpulkan Ujian', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          content: Text(
            unansweredCount > 0
                ? 'Anda masih memiliki $unansweredCount soal yang belum dijawab. Apakah Anda yakin ingin mengumpulkan ujian sekarang?'
                : 'Apakah Anda yakin ingin menyerahkan jawaban Anda sekarang?',
            style: TextStyle(color: titleColor.withValues(alpha: 0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6)),
              child: const Text('Kumpulkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        _isSubmitting = true;
      });
      _timer?.cancel();

      final user = SessionService.currentUser!;
      try {
        await _examService.submitExam(
          schoolId: user.schoolId,
          exam: widget.exam,
          studentId: user.uid,
          studentName: user.nama,
          answers: _selectedAnswers,
        );

        Get.back();
        Get.snackbar(
          'Sukses',
          'Ujian berhasil diserahkan. Nilai Anda telah dihitung.',
          backgroundColor: const Color(0xFF10B981),
          colorText: Colors.white,
        );
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        Get.snackbar('Gagal', 'Gagal menyerahkan ujian: $e',
            backgroundColor: Colors.redAccent, colorText: Colors.white);
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasStarted) return true;
    final isDark = AuthBackground.isDarkMode.value;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);

    final bool? exit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          title: Text('Keluar Ujian', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
          content: const Text(
            'Anda sedang berada di tengah ujian. Jika Anda keluar sekarang, jawaban Anda saat ini akan langsung diserahkan otomatis.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Lanjutkan Ujian', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Keluar & Serahkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (exit == true) {
      await _autoSubmit();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasStarted,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: AuthBackground.isDarkMode,
        builder: (context, isDark, _) {
          final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
          final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
          final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
          final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

          if (!_hasStarted) {
            return _buildInstructionScreen(isDark, titleColor, subTextColor, cardBgColor, cardBorderColor);
          }

          final totalQuestions = widget.exam.questions.length;
          final currentQuestion = widget.exam.questions[_currentQuestionIndex];
          final selectedOption = _selectedAnswers[currentQuestion.id];
          final progress = (widget.exam.questions.isEmpty)
              ? 0.0
              : (_currentQuestionIndex + 1) / totalQuestions;

          return Scaffold(
            body: AuthBackground(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Timer & Question Index
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Soal ${_currentQuestionIndex + 1} dari $totalQuestions',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: (_secondsRemaining < 120 ? Colors.redAccent : const Color(0xFF8B5CF6)).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: _secondsRemaining < 120 ? Colors.redAccent : const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTime(_secondsRemaining),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _secondsRemaining < 120 ? Colors.redAccent : const Color(0xFF8B5CF6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Linear Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: cardBorderColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Question Body
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: cardBorderColor),
                                ),
                                child: Text(
                                  currentQuestion.questionText,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor, height: 1.5),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Option Cards
                              ...List.generate(currentQuestion.options.length, (optIdx) {
                                final isSelected = selectedOption == optIdx;
                                final optionChar = String.fromCharCode(65 + optIdx); // A, B, C, D

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        setState(() {
                                          _selectedAnswers[currentQuestion.id] = optIdx;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                              : cardBgColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF8B5CF6) : cardBorderColor,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected ? const Color(0xFF8B5CF6) : cardBorderColor,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  optionChar,
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : titleColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Text(
                                                currentQuestion.options[optIdx],
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontSize: 14,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      // Navigation Control Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentQuestionIndex > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _currentQuestionIndex--;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: cardBorderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text('Sebelumnya', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                              ),
                            )
                          else
                            const Spacer(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_currentQuestionIndex < totalQuestions - 1) {
                                  setState(() {
                                    _currentQuestionIndex++;
                                  });
                                } else {
                                  _submitExamManual();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                _currentQuestionIndex < totalQuestions - 1 ? 'Berikutnya' : 'Kumpulkan',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionScreen(
      bool isDark, Color titleColor, Color subTextColor, Color cardBgColor, Color cardBorderColor) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.quiz_rounded, color: Color(0xFF8B5CF6), size: 48),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.exam.title,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.exam.subjectName,
                      style: TextStyle(fontSize: 13, color: const Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text('Aturan & Instruksi Ujian:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor)),
                    const SizedBox(height: 10),
                    _buildRuleItem(Icons.timer_rounded, 'Durasi pengerjaan adalah ${widget.exam.durationMinutes} menit.', titleColor),
                    _buildRuleItem(Icons.list_alt_rounded, 'Terdiri dari ${widget.exam.questions.length} soal pilihan ganda.', titleColor),
                    _buildRuleItem(Icons.warning_amber_rounded, 'Meninggalkan aplikasi saat ujian berjalan akan memicu penyerahan jawaban otomatis.', titleColor),
                    _buildRuleItem(Icons.verified_user_rounded, 'Pastikan koneksi internet stabil sebelum menekan tombol Mulai.', titleColor),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _startExam,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Mulai Ujian Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cardBorderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Kembali', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, String text, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: titleColor.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: titleColor.withValues(alpha: 0.8), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
