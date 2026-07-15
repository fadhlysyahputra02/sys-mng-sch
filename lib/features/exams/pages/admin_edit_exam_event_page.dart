import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import 'package:sys_mng_school/core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_event_model.dart';

// ─────────────────────────────────────────────────────────────
//  AdminEditExamEventPage — Edit info dasar event ujian (Planning)
// ─────────────────────────────────────────────────────────────
class AdminEditExamEventPage extends StatefulWidget {
  final ExamEvent event;

  const AdminEditExamEventPage({super.key, required this.event});

  @override
  State<AdminEditExamEventPage> createState() => _AdminEditExamEventPageState();
}

class _AdminEditExamEventPageState extends State<AdminEditExamEventPage> {
  late final TextEditingController _titleController;
  late String _examType;
  late DateTime? _startDate;
  late DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _examType  = widget.event.examType;
    _startDate = widget.event.startDate;
    _endDate   = widget.event.endDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────
  InputDecoration _inputDecoration(
    String hint,
    bool isDark,
    Color inputBg,
    Color cardBorder,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark
            ? Colors.white.withValues(alpha: 0.85)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.85),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildDatePickerButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required Color inputBg,
    required Color cardBorder,
    required Color titleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: titleColor, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────
  Future<void> _save() async {
    final newTitle = _titleController.text.trim();
    final schoolId = SessionService.currentUser!.schoolId;

    if (newTitle.isEmpty) {
      Get.snackbar(
        'Error',
        AppLocalization.isIndonesian
            ? 'Nama event tidak boleh kosong.'
            : 'Event name cannot be empty.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    if (_startDate == null || _endDate == null) {
      Get.snackbar(
        'Error',
        AppLocalization.isIndonesian
            ? 'Tanggal mulai dan selesai harus diisi.'
            : 'Start and end dates are required.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      Get.snackbar(
        'Error',
        AppLocalization.isIndonesian
            ? 'Tanggal selesai harus setelah tanggal mulai.'
            : 'End date must be after start date.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('exam_events')
          .doc(widget.event.id)
          .update({
        'title':     newTitle,
        'examType':  _examType,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate':   Timestamp.fromDate(_endDate!),
      });

      Get.back();
      Get.snackbar(
        AppLocalization.isIndonesian ? 'Berhasil Disimpan' : 'Saved',
        AppLocalization.isIndonesian
            ? 'Event berhasil diperbarui.'
            : 'Event updated successfully.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      setState(() => _saving = false);
      Get.snackbar('Error', e.toString(),
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final titleColor =
                isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subtitleColor = isDark
                ? Colors.white.withValues(alpha: 0.6)
                : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
            final cardColor = isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white;
            final cardBorder = isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08);
            final inputBg = isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03);

            return Scaffold(
              body: AuthBackground(
                child: Column(
                  children: [
                    // ── AppBar ───────────────────────────────────
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_rounded,
                                  color: titleColor),
                              onPressed: () => Get.back(),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                AppLocalization.isIndonesian
                                    ? 'Edit Jadwal Ujian'
                                    : 'Edit Exam Event',
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Form ─────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section title
                            Text(
                              AppLocalization.isIndonesian
                                  ? 'Informasi Dasar Event'
                                  : 'Basic Event Information',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppLocalization.isIndonesian
                                  ? 'Ubah detail event ujian semester ini'
                                  : 'Update the details for this semester exam event',
                              style: TextStyle(
                                  color: subtitleColor, fontSize: 13),
                            ),
                            const SizedBox(height: 24),

                            // ── Card ─────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black26
                                        : Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Nama Event
                                  _buildLabel(
                                    AppLocalization.isIndonesian
                                        ? 'Nama Event Ujian'
                                        : 'Exam Event Name',
                                    isDark,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _titleController,
                                    style: TextStyle(color: titleColor),
                                    decoration: _inputDecoration(
                                      AppLocalization.isIndonesian
                                          ? 'Contoh: UAS Semester 1 2025/2026'
                                          : 'e.g., UAS Semester 1 2025/2026',
                                      isDark,
                                      inputBg,
                                      cardBorder,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Tipe Ujian
                                  _buildLabel(
                                    AppLocalization.isIndonesian
                                        ? 'Tipe Ujian'
                                        : 'Exam Type',
                                    isDark,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: ['UTS', 'UAS'].map((type) {
                                      final isSelected = _examType == type;
                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () =>
                                              setState(() => _examType = type),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            margin: EdgeInsets.only(
                                                right: type == 'UTS' ? 8 : 0),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF8B5CF6)
                                                      .withValues(alpha: 0.15)
                                                  : inputBg,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF8B5CF6)
                                                    : cardBorder,
                                                width: isSelected ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                type,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isSelected
                                                      ? const Color(0xFF8B5CF6)
                                                      : subtitleColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),

                                  // Rentang Tanggal
                                  _buildLabel(
                                    AppLocalization.isIndonesian
                                        ? 'Rentang Tanggal Ujian'
                                        : 'Exam Date Range',
                                    isDark,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDatePickerButton(
                                          label: _startDate != null
                                              ? DateFormat(
                                                      'dd MMM yyyy',
                                                      AppLocalization
                                                              .isIndonesian
                                                          ? 'id'
                                                          : 'en')
                                                  .format(_startDate!)
                                              : (AppLocalization.isIndonesian
                                                  ? 'Mulai'
                                                  : 'Start'),
                                          icon: Icons.calendar_today_rounded,
                                          isDark: isDark,
                                          inputBg: inputBg,
                                          cardBorder: cardBorder,
                                          titleColor: titleColor,
                                          onTap: () async {
                                            final picked =
                                                await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  _startDate ?? DateTime.now(),
                                              firstDate: DateTime(2024),
                                              lastDate: DateTime(2030),
                                            );
                                            if (picked != null) {
                                              setState(
                                                  () => _startDate = picked);
                                            }
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Icon(
                                            Icons.arrow_forward_rounded,
                                            color: subtitleColor,
                                            size: 18),
                                      ),
                                      Expanded(
                                        child: _buildDatePickerButton(
                                          label: _endDate != null
                                              ? DateFormat(
                                                      'dd MMM yyyy',
                                                      AppLocalization
                                                              .isIndonesian
                                                          ? 'id'
                                                          : 'en')
                                                  .format(_endDate!)
                                              : (AppLocalization.isIndonesian
                                                  ? 'Selesai'
                                                  : 'End'),
                                          icon: Icons.event_rounded,
                                          isDark: isDark,
                                          inputBg: inputBg,
                                          cardBorder: cardBorder,
                                          titleColor: titleColor,
                                          onTap: () async {
                                            final picked =
                                                await showDatePicker(
                                              context: context,
                                              initialDate: _endDate ??
                                                  (_startDate ??
                                                      DateTime.now()),
                                              firstDate:
                                                  _startDate ?? DateTime(2024),
                                              lastDate: DateTime(2030),
                                            );
                                            if (picked != null) {
                                              setState(
                                                  () => _endDate = picked);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Date validation warning
                                  if (_startDate != null &&
                                      _endDate != null &&
                                      _endDate!.isBefore(_startDate!)) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFEF4444)
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_rounded,
                                              size: 14,
                                              color: Color(0xFFEF4444)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              AppLocalization.isIndonesian
                                                  ? 'Tanggal selesai harus setelah tanggal mulai.'
                                                  : 'End date must be after start date.',
                                              style: const TextStyle(
                                                  color: Color(0xFFEF4444),
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Bottom Save Button ──────────────────────
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 12, 24, 20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF8B5CF6)
                                  .withValues(alpha: 0.5),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    AppLocalization.isIndonesian
                                        ? 'Simpan Perubahan'
                                        : 'Save Changes',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
