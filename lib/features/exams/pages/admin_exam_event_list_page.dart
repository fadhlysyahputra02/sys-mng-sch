import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../core/services/session_service.dart';
import '../../authentication/widgets/auth_background.dart';
import '../models/exam_event_model.dart';
import '../services/exam_session_service.dart';
import 'admin_exam_generator_page.dart';
import 'admin_exam_schedule_view_page.dart';
import 'admin_archived_exam_events_page.dart';

// ─────────────────────────────────────────────────────────────
//  AdminExamEventListPage — Daftar event UTS/UAS
//  Titik masuk Admin untuk modul ujian semester
// ─────────────────────────────────────────────────────────────
class AdminExamEventListPage extends StatelessWidget {
  final bool hideBackButton;

  const AdminExamEventListPage({
    super.key,
    this.hideBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;
    final service = ExamSessionService();

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subtitleColor = isDark
            ? Colors.white.withValues(alpha: 0.55)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
        final cardColor =
            isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // AppBar
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        if (!hideBackButton) ...[
                          IconButton(
                            icon: Icon(Icons.arrow_back_rounded,
                                color: titleColor),
                            onPressed: () => Get.back(),
                          ),
                          const SizedBox(width: 4),
                        ] else
                          const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            AppLocalization.isIndonesian ? 'Ujian Semester' : 'Semester Exams',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Tombol Generate baru
                        ElevatedButton.icon(
                          onPressed: () =>
                              Get.to(() => const AdminExamGeneratorPage()),
                          label: Text(AppLocalization.isIndonesian ? 'Buat Baru' : 'Create New'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // List Event
                Expanded(
                  child: Column(
                    children: [
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('schools')
                            .doc(schoolId)
                            .collection('exam_drafts')
                            .doc('current')
                            .snapshots(),
                        builder: (context, draftSnap) {
                          if (draftSnap.hasData && draftSnap.data!.exists) {
                            final draftData = draftSnap.data!.data()!;
                            final title = draftData['title'] ?? (AppLocalization.isIndonesian ? 'Tanpa Nama' : 'Untitled');
                            final step = draftData['step'] ?? 0;
                            final updatedBy = draftData['updatedBy'] ?? '';
                            final updatedAt = draftData['updatedAt'] as Timestamp?;
                            final updatedTime = updatedAt != null
                                ? DateFormat('dd MMM, HH:mm').format(updatedAt.toDate())
                                : '';

                            return Container(
                              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2E2A4A) : const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                      : const Color(0xFFC7D2FE),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          AppLocalization.isIndonesian ? 'DRAF AKTIF' : 'ACTIVE DRAFT',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppLocalization.isIndonesian ? 'Langkah ${step + 1} dari 7' : 'Step ${step + 1} of 7',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (updatedTime.isNotEmpty)
                                        Text(
                                          AppLocalization.isIndonesian ? 'Diedit $updatedTime' : 'Edited $updatedTime',
                                          style: TextStyle(
                                            color: isDark ? Colors.white54 : Colors.black45,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    title.isEmpty ? (AppLocalization.isIndonesian ? '(Event Baru Sedang Dibuat)' : '(New Event in Progress)') : title,
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (updatedBy.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${AppLocalization.isIndonesian ? 'Terakhir diubah oleh' : 'Last edited by'}: $updatedBy',
                                      style: TextStyle(
                                        color: isDark ? Colors.white60 : Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                backgroundColor: isDark ? const Color(0xFF1A1730) : Colors.white,
                                                title: Text(
                                                  AppLocalization.isIndonesian ? 'Mulai Ulang?' : 'Restart?',
                                                  style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                                                ),
                                                content: Text(
                                                  AppLocalization.isIndonesian
                                                      ? 'Menghapus draf ini akan membatalkan semua kemajuan pembuatan ujian yang sedang berjalan.'
                                                      : 'Deleting this draft will discard all ongoing exam creation progress.',
                                                  style: TextStyle(color: subtitleColor),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Get.back(),
                                                    child: Text(AppLocalization.isIndonesian ? 'Batal' : 'Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      Get.back();
                                                      await FirebaseFirestore.instance
                                                          .collection('schools')
                                                          .doc(schoolId)
                                                          .collection('exam_drafts')
                                                          .doc('current')
                                                          .delete();
                                                    },
                                                    child: Text(
                                                      AppLocalization.isIndonesian ? 'Hapus Draf' : 'Delete Draft',
                                                      style: const TextStyle(color: Colors.redAccent),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            side: const BorderSide(color: Colors.redAccent),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: Text(AppLocalization.isIndonesian ? 'Hapus Draf' : 'Delete Draft', style: const TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Get.to(() => const AdminExamGeneratorPage(restoreFromFirestore: true));
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF6366F1),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: Text(AppLocalization.isIndonesian ? 'Lanjutkan Edit' : 'Continue Editing', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Expanded(
                        child: StreamBuilder<List<ExamEvent>>(
                          stream: service.getExamEvents(schoolId),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: isDark ? Colors.white : const Color(0xFF8B5CF6),
                                ),
                              );
                            }

                            final events = snapshot.data ?? [];

                            if (events.isEmpty) {
                              return _buildEmptyState(isDark, titleColor, subtitleColor);
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                              itemCount: events.length,
                              itemBuilder: (_, i) => _buildEventCard(
                                context,
                                events[i],
                                isDark,
                                cardColor,
                                cardBorder,
                                titleColor,
                                subtitleColor,
                                service,
                                schoolId,
                              ),
                            );
                          },
                        ),
                      ),
                      // TOmbol Arsip Event
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: OutlinedButton.icon(
                          onPressed: () => Get.to(() => const AdminArchivedExamEventsPage()),
                          icon: const Icon(Icons.archive_outlined, size: 18),
                          label: Text(AppLocalization.isIndonesian ? 'Lihat Arsip Event' : 'View Archived Events'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                            side: BorderSide(color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5)),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildEventCard(
    BuildContext context,
    ExamEvent event,
    bool isDark,
    Color cardColor,
    Color cardBorder,
    Color titleColor,
    Color subtitleColor,
    ExamSessionService service,
    String schoolId,
  ) {
    final statusData = _getStatusData(event.examStatus);
    final localeStr = AppLocalization.isIndonesian ? 'id' : 'en';
    final dateStr =
        '${DateFormat('dd MMM', localeStr).format(event.startDate)} – ${DateFormat('dd MMM yyyy', localeStr).format(event.endDate)}';

    final userRole = SessionService.currentUser?.role ?? '';
    final isAdmin = userRole == 'school_admin' || userRole == 'super_admin';

    return GestureDetector(
      onTap: () => Get.to(() => AdminExamScheduleViewPage(eventId: event.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorder),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header gradient strip
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: event.examType == 'UAS'
                      ? [const Color(0xFF8B5CF6), const Color(0xFFEC4899)]
                      : [const Color(0xFF3B82F6), const Color(0xFF06B6D4)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: event.examType == 'UAS'
                                ? [
                                    const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                    const Color(0xFFEC4899).withValues(alpha: 0.15)
                                  ]
                                : [
                                    const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                    const Color(0xFF06B6D4).withValues(alpha: 0.15)
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.examType,
                          style: TextStyle(
                            color: event.examType == 'UAS'
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF3B82F6),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusData['color']
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusData['icon'],
                                size: 12, color: statusData['color']),
                            const SizedBox(width: 4),
                            Text(
                              statusData['label'],
                              style: TextStyle(
                                color: statusData['color'],
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // More menu — hanya tampil untuk admin, berisi aksi sekunder
                      PopupMenuButton<String>(
                        onSelected: (val) =>
                            _onMenuAction(val, event, service, schoolId),
                        icon: Icon(Icons.more_vert_rounded,
                            color: subtitleColor, size: 20),
                        color: isDark ? const Color(0xFF1A1730) : Colors.white,
                        itemBuilder: (_) => [
                          if (event.examStatus == 'Active')
                            PopupMenuItem(
                              value: 'finish',
                              child: Text(AppLocalization.isIndonesian ? 'Selesaikan Event' : 'Finish Event',
                                  style: TextStyle(color: titleColor)),
                            ),
                          if (event.examStatus == 'Finished') ...[
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(AppLocalization.isIndonesian ? 'Arsipkan Event' : 'Archive Event',
                                  style: const TextStyle(color: Colors.orangeAccent)),
                            ),
                            if (isAdmin)
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(AppLocalization.isIndonesian ? 'Hapus Event' : 'Delete Event',
                                    style: const TextStyle(color: Color(0xFFEF4444))),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: subtitleColor),
                          const SizedBox(width: 6),
                          Text(dateStr,
                              style:
                                  TextStyle(color: subtitleColor, fontSize: 12)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 13, color: subtitleColor),
                          const SizedBox(width: 6),
                          Text(
                              AppLocalization.isIndonesian
                                  ? '${event.dailySlots.length} sesi/hari'
                                  : '${event.dailySlots.length} sessions/day',
                              style:
                                  TextStyle(color: subtitleColor, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 13, color: subtitleColor),
                      const SizedBox(width: 6),
                      Text(
                          AppLocalization.isIndonesian
                              ? '${event.subjectConfigs.length} Mata Pelajaran'
                              : '${event.subjectConfigs.length} Subjects',
                          style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            // ── Tombol Aktifkan Event (hanya muncul saat Planning) ──────────
            if (event.examStatus == 'Planning')
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cardBorder)),
                ),
                child: TextButton.icon(
                  onPressed: () => _onMenuAction('activate', event, service, schoolId),
                  icon: const Icon(Icons.play_circle_rounded, size: 18, color: Color(0xFF10B981)),
                  label: Text(
                    AppLocalization.isIndonesian ? 'Aktifkan Event' : 'Activate Event',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusData(String status) {
    switch (status) {
      case 'Active':
        return {
          'label': AppLocalization.isIndonesian ? 'Aktif' : 'Active',
          'color': const Color(0xFF10B981),
          'icon': Icons.play_circle_rounded,
        };
      case 'Finished':
        return {
          'label': AppLocalization.isIndonesian ? 'Selesai' : 'Finished',
          'color': const Color(0xFF64748B),
          'icon': Icons.check_circle_rounded,
        };
      default:
        return {
          'label': AppLocalization.isIndonesian ? 'Perencanaan' : 'Planning',
          'color': const Color(0xFFF59E0B),
          'icon': Icons.pending_rounded,
        };
    }
  }

  Future<void> _onMenuAction(
    String action,
    ExamEvent event,
    ExamSessionService service,
    String schoolId,
  ) async {
    switch (action) {
      case 'activate':
        Get.dialog(
          const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
          barrierDismissible: false,
        );
        try {
          await service.updateExamEventStatus(schoolId, event.id, 'Active');
          Get.back(); // close loading dialog
          Get.snackbar(
              AppLocalization.isIndonesian ? 'Berhasil' : 'Success',
              AppLocalization.isIndonesian ? 'Event "${event.title}" diaktifkan' : 'Event "${event.title}" activated',
              backgroundColor: const Color(0xFF10B981),
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              margin: const EdgeInsets.all(16));
        } catch (e) {
          Get.back(); // close loading dialog
          final errMsg = e.toString().replaceAll('Exception: ', '');
          Get.snackbar(
              AppLocalization.isIndonesian ? 'Gagal Mengaktifkan' : 'Failed to Activate',
              errMsg,
              backgroundColor: const Color(0xFFEF4444),
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 5),
              margin: const EdgeInsets.all(16));
        }
        break;
      case 'finish':
        await service.updateExamEventStatus(schoolId, event.id, 'Finished');
        Get.snackbar(
            AppLocalization.isIndonesian ? 'Selesai' : 'Success',
            AppLocalization.isIndonesian ? 'Event "${event.title}" ditandai selesai' : 'Event "${event.title}" marked as finished',
            backgroundColor: const Color(0xFF64748B),
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            margin: const EdgeInsets.all(16));
        break;
      case 'archive':
        await service.updateExamEventStatus(schoolId, event.id, 'Archived');
        Get.snackbar(
            AppLocalization.isIndonesian ? 'Diarsipkan' : 'Archived',
            AppLocalization.isIndonesian ? 'Event "${event.title}" berhasil diarsipkan dan disembunyikan.' : 'Event "${event.title}" has been archived and hidden.',
            backgroundColor: Colors.orangeAccent,
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            margin: const EdgeInsets.all(16));
        break;
      case 'delete':
        final isDark = AuthBackground.isDarkMode.value;
        final ctrl = TextEditingController();
        final confirm = await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1A1730) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_rounded, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  AppLocalization.isIndonesian ? 'Hapus Event' : 'Delete Event',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  AppLocalization.isIndonesian 
                      ? 'Apakah Anda yakin ingin menghapus "${event.title}"?\n\nPERINGATAN: Semua soal, jadwal, dan NILAI SISWA yang terkait dengan event ini akan TERHAPUS PERMANEN.' 
                      : 'Are you sure you want to delete "${event.title}"?\n\nWARNING: All questions, schedules, and STUDENT GRADES related to this event will be PERMANENTLY DELETED.',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  AppLocalization.isIndonesian 
                      ? 'Ketik nama event "${event.title}" untuk konfirmasi:' 
                      : 'Type the event name "${event.title}" to confirm:',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: event.title,
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.redAccent),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text(
                  AppLocalization.isIndonesian ? 'Batal' : 'Cancel',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final expectedStr = event.title;
                  if (ctrl.text.trim() == expectedStr) {
                    Get.back(result: true);
                  } else {
                    Get.snackbar(
                      'Error',
                      AppLocalization.isIndonesian ? 'Teks konfirmasi tidak sesuai.' : 'Confirmation text does not match.',
                      backgroundColor: Colors.redAccent,
                      colorText: Colors.white,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                child: Text(AppLocalization.isIndonesian ? 'Hapus' : 'Delete'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          Get.dialog(
            const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
            barrierDismissible: false,
          );
          try {
            await service.deleteExamEvent(schoolId, event.id);
            Get.back(); // close loading
            Get.snackbar(
                AppLocalization.isIndonesian ? 'Dihapus' : 'Deleted',
                AppLocalization.isIndonesian ? 'Event "${event.title}" dan nilainya telah dihapus.' : 'Event "${event.title}" and its grades have been deleted.',
                backgroundColor: const Color(0xFFEF4444),
                colorText: Colors.white,
                snackPosition: SnackPosition.TOP,
                margin: const EdgeInsets.all(16));
          } catch (e) {
            Get.back();
            Get.snackbar('Error', e.toString(), backgroundColor: Colors.redAccent, colorText: Colors.white);
          }
        }
        break;
    }
  }

  Widget _buildEmptyState(
      bool isDark, Color titleColor, Color subtitleColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_note_rounded,
                size: 36,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black26,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalization.isIndonesian ? 'Belum Ada Event Ujian' : 'No Exam Events Yet',
              style: TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalization.isIndonesian
                  ? 'Klik tombol "Buat Baru" untuk membuat jadwal UTS/UAS pertama.'
                  : 'Click "Create New" to schedule the first midterm/final exam.',
              style:
                  TextStyle(color: subtitleColor, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
