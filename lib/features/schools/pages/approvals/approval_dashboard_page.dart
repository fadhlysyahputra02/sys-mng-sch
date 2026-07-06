import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../authentication/widgets/auth_background.dart';
import '../../../../core/services/session_service.dart';
import '../../../tasks/services/task_service.dart';
import '../../../../core/localization/app_localization.dart';

// ─────────────────────────────────────────────
//  MODEL: Approval Category
// ─────────────────────────────────────────────
class _ApprovalCategory {
  final String label;
  final String subtitle;
  final String collection;
  final IconData icon;
  final Color color;

  const _ApprovalCategory({
    required this.label,
    required this.subtitle,
    required this.collection,
    required this.icon,
    required this.color,
  });
}

const _kCategories = [
  _ApprovalCategory(
    label: 'Persetujuan Koreksi Absensi',
    subtitle: 'Izin guru untuk mengedit data absensi kelas',
    collection: 'attendanceEditRequests',
    icon: Icons.edit_note_rounded,
    color: Color(0xFF8B5CF6),
  ),
  _ApprovalCategory(
    label: 'Persetujuan Penghapusan Tugas',
    subtitle: 'Pengajuan penghapusan tugas beserta jawaban murid',
    collection: 'taskDeleteRequests',
    icon: Icons.delete_sweep_rounded,
    color: Color(0xFFEF4444),
  ),
];

// ─────────────────────────────────────────────
//  PAGE 1: ApprovalDashboardPage (kategori)
// ─────────────────────────────────────────────
class ApprovalDashboardPage extends StatefulWidget {
  final bool hideBackButton;
  const ApprovalDashboardPage({super.key, this.hideBackButton = false});

  @override
  State<ApprovalDashboardPage> createState() => _ApprovalDashboardPageState();
}

class _ApprovalDashboardPageState extends State<ApprovalDashboardPage> {
  String get schoolId => SessionService.currentUser?.schoolId ?? '';

  /// Ambil jumlah pengajuan pending per koleksi
  Stream<int> _pendingCountStream(String collection) {
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection(collection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Hapus otomatis dokumen (approved/rejected/closed) yang lebih dari 7 hari
  Future<void> _cleanupOldRequests(String collection) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final cutoffTs = Timestamp.fromDate(cutoff);
    try {
      final old = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection(collection)
          .where('status', whereIn: ['approved', 'rejected', 'closed'])
          .where('reviewedAt', isLessThan: cutoffTs)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in old.docs) {
        batch.delete(doc.reference);
      }
      if (old.docs.isNotEmpty) await batch.commit();

      // Juga hapus request pending yang lebih dari 7 hari (diabaikan terlalu lama)
      final oldPending = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection(collection)
          .where('status', isEqualTo: 'pending')
          .where('requestedAt', isLessThan: cutoffTs)
          .get();

      if (oldPending.docs.isNotEmpty) {
        final batchPending = FirebaseFirestore.instance.batch();
        for (final doc in oldPending.docs) {
          batchPending.delete(doc.reference);
        }
        await batchPending.commit();
      }
    } catch (_) {
      // Cleanup is best-effort, do not throw
    }
  }

  @override
  void initState() {
    super.initState();
    // Jalankan cleanup saat halaman dibuka
    for (final cat in _kCategories) {
      _cleanupOldRequests(cat.collection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subColor = isDark ? Colors.white60 : Colors.black54;

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        if (!widget.hideBackButton) ...[
                          Container(
                            decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLocalization.isIndonesian ? 'Persetujuan' : 'Approvals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
                              Text(AppLocalization.isIndonesian ? 'Pilih kategori perizinan' : 'Select permission category', style: TextStyle(fontSize: 12, color: iconColor.withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Info chip: auto-cleanup ──────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.auto_delete_rounded, size: 13, color: subColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppLocalization.isIndonesian ? 'Data lebih dari 7 hari dihapus otomatis.' : 'Data older than 7 days is automatically deleted.',
                          style: TextStyle(fontSize: 11, color: subColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Category Cards ───────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: _kCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final cat = _kCategories[index];
                      return _buildCategoryCard(context, cat, isDark, titleColor, subColor);
                    },
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

  Widget _buildCategoryCard(
    BuildContext context,
    _ApprovalCategory cat,
    bool isDark,
    Color titleColor,
    Color subColor,
  ) {
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return StreamBuilder<int>(
      stream: _pendingCountStream(cat.collection),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? 0;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalDetailPage(category: cat),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 26),
                ),
                const SizedBox(width: 16),
                // Label & subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.collection == 'attendanceEditRequests'
                            ? (AppLocalization.isIndonesian ? 'Persetujuan Koreksi Absensi' : 'Attendance Correction Approval')
                            : (AppLocalization.isIndonesian ? 'Persetujuan Penghapusan Tugas' : 'Task Deletion Approval'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat.collection == 'attendanceEditRequests'
                            ? (AppLocalization.isIndonesian ? 'Izin guru untuk mengedit data absensi kelas' : 'Teacher permission to edit class attendance data')
                            : (AppLocalization.isIndonesian ? 'Pengajuan penghapusan tugas beserta jawaban murid' : 'Request to delete tasks and student answers'),
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Pending badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (pending > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$pending pending',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subColor),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  PAGE 2: ApprovalDetailPage (daftar pengajuan)
// ─────────────────────────────────────────────
class ApprovalDetailPage extends StatefulWidget {
  final _ApprovalCategory category;
  const ApprovalDetailPage({super.key, required this.category});

  @override
  State<ApprovalDetailPage> createState() => _ApprovalDetailPageState();
}

class _ApprovalDetailPageState extends State<ApprovalDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String get schoolId => SessionService.currentUser?.schoolId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getRequests(String status) {
    final col = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection(widget.category.collection);

    if (status == 'approved') {
      return col.where('status', whereIn: const ['approved', 'closed']).snapshots();
    }
    return col.where('status', isEqualTo: status).snapshots();
  }

  Future<void> _approveRequest(String requestId, String reviewerName, Map<String, dynamic> data) async {
    try {
      if (widget.category.collection == 'taskDeleteRequests') {
        final taskId = data['taskId'] as String;
        await TaskService().deleteTask(schoolId, taskId);
      }
      await FirebaseFirestore.instance
          .collection('schools').doc(schoolId)
          .collection(widget.category.collection).doc(requestId)
          .update({'status': 'approved', 'reviewedBy': reviewerName, 'reviewedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalization.isIndonesian ? 'Pengajuan disetujui' : 'Request approved'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalization.isIndonesian ? "Gagal menyetujui" : "Failed to approve"}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId, String reviewerName) async {
    try {
      await FirebaseFirestore.instance
          .collection('schools').doc(schoolId)
          .collection(widget.category.collection).doc(requestId)
          .update({'status': 'rejected', 'reviewedBy': reviewerName, 'reviewedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalization.isIndonesian ? 'Pengajuan ditolak' : 'Request rejected'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalization.isIndonesian ? "Gagal menolak" : "Failed to reject"}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required Color confirmColor,
    required String confirmLabel,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate().toLocal();
    final months = AppLocalization.isIndonesian
        ? ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des']
        : ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} ${AppLocalization.isIndonesian ? "WIB" : "local"}';
  }

  Widget _buildRequestCard(Map<String, dynamic> data, String requestId, bool isDark, bool isPending) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    final requestedByName = data['requestedByName'] as String? ?? '-';
    final requestedAt = data['requestedAt'] as Timestamp?;
    final reviewedBy = data['reviewedBy'] as String?;
    final reviewedAt = data['reviewedAt'] as Timestamp?;
    final reviewerName = SessionService.currentUser?.nama ?? 'Admin';
    final status = data['status'] as String? ?? 'pending';
    final isTaskDelete = widget.category.collection == 'taskDeleteRequests';

    // --- Card content differs per type ---
    Widget bodyContent;
    if (isTaskDelete) {
      final taskTitle = data['taskTitle'] as String? ?? '-';
      final className = data['className'] as String? ?? '-';
      final subjectName = data['subjectName'] as String? ?? '-';
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(taskTitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor)),
          const SizedBox(height: 2),
          Text('$className • $subjectName', style: TextStyle(fontSize: 12, color: subColor)),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 10),
          Text(AppLocalization.isIndonesian ? 'Guru mengajukan penghapusan tugas beserta seluruh jawaban murid.' : 'Teacher requests task deletion along with all student answers.', style: TextStyle(fontSize: 12, color: subColor, height: 1.4)),
        ],
      );
    } else {
      final className = data['className'] as String? ?? '-';
      final subjectName = data['subjectName'] as String? ?? '-';
      final dateStr = data['dateStr'] as String? ?? '-';
      final reason = data['reason'] as String? ?? '';
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(className, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor)),
                    Text(subjectName, style: TextStyle(fontSize: 12, color: subColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(dateStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(height: 10),
          Text(AppLocalization.isIndonesian ? 'Guru mengajukan izin untuk mengedit data absensi sesi kelas ini.' : 'Teacher requests permission to edit attendance data for this class session.', style: TextStyle(fontSize: 12, color: subColor, height: 1.4)),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded, size: 13, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(child: Text(reason, style: TextStyle(fontSize: 12, color: titleColor))),
                ],
              ),
            ),
          ],
          // Toggle switch for approved/closed absensi
          if (status == 'approved' || status == 'closed') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (status == 'approved' ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (status == 'approved' ? const Color(0xFF10B981) : Colors.grey).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'approved' ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 16,
                        color: status == 'approved' ? const Color(0xFF10B981) : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status == 'approved'
                            ? (AppLocalization.isIndonesian ? 'Izin Edit: AKTIF' : 'Edit Permit: ACTIVE')
                            : (AppLocalization.isIndonesian ? 'Izin Edit: NONAKTIF' : 'Edit Permit: INACTIVE'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: status == 'approved' ? const Color(0xFF10B981) : Colors.grey),
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: status == 'approved',
                      activeThumbColor: const Color(0xFF10B981),
                      activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                      onChanged: (val) async {
                        final newStatus = val ? 'approved' : 'closed';
                        await FirebaseFirestore.instance
                            .collection('schools').doc(schoolId)
                            .collection(widget.category.collection).doc(requestId)
                            .update({'status': newStatus, 'reviewedAt': FieldValue.serverTimestamp()});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + type badge header
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: widget.category.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(widget.category.icon, color: widget.category.color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.category.collection == 'attendanceEditRequests'
                      ? (AppLocalization.isIndonesian ? 'Persetujuan Koreksi Absensi' : 'Attendance Correction Approval')
                      : (AppLocalization.isIndonesian ? 'Persetujuan Penghapusan Tugas' : 'Task Deletion Approval'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.category.color),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(status))),
                ),
              ],
            ),
            const SizedBox(height: 14),
            bodyContent,
            const SizedBox(height: 12),
            // Footer: requestedBy + time
            Row(
              children: [
                Icon(Icons.person_pin_rounded, size: 13, color: subColor),
                const SizedBox(width: 4),
                Text('Guru: ', style: TextStyle(fontSize: 11, color: subColor)),
                Expanded(child: Text(requestedByName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor), overflow: TextOverflow.ellipsis)),
                Text(_formatTimestamp(requestedAt), style: TextStyle(fontSize: 10, color: subColor)),
              ],
            ),
            if (!isPending && reviewedBy != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 13, color: subColor),
                  const SizedBox(width: 4),
                  Text('Ditinjau: ', style: TextStyle(fontSize: 11, color: subColor)),
                  Expanded(child: Text(reviewedBy, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor), overflow: TextOverflow.ellipsis)),
                  Text(_formatTimestamp(reviewedAt), style: TextStyle(fontSize: 10, color: subColor)),
                ],
              ),
            ],
            // Action buttons (only pending)
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(AppLocalization.isIndonesian ? 'Tolak' : 'Reject', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _showConfirmDialog(
                        title: AppLocalization.isIndonesian ? 'Tolak Pengajuan' : 'Reject Request',
                        message: AppLocalization.isIndonesian ? 'Pengajuan izin akan ditolak.' : 'Permission request will be rejected.',
                        confirmColor: const Color(0xFFEF4444),
                        confirmLabel: AppLocalization.isIndonesian ? 'Tolak' : 'Reject',
                        onConfirm: () => _rejectRequest(requestId, reviewerName),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text(AppLocalization.isIndonesian ? 'Setujui' : 'Approve', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _showConfirmDialog(
                        title: AppLocalization.isIndonesian ? 'Setujui Pengajuan' : 'Approve Request',
                        message: AppLocalization.isIndonesian ? 'Menyetujui pengajuan izin ini.' : 'Approve this permission request.',
                        confirmColor: const Color(0xFF10B981),
                        confirmLabel: AppLocalization.isIndonesian ? 'Setujui' : 'Approve',
                        onConfirm: () => _approveRequest(requestId, reviewerName, data),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved': return const Color(0xFF10B981);
      case 'rejected': return const Color(0xFFEF4444);
      case 'closed':   return Colors.grey;
      default:         return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved': return AppLocalization.isIndonesian ? 'Disetujui' : 'Approved';
      case 'rejected': return AppLocalization.isIndonesian ? 'Ditolak' : 'Rejected';
      case 'closed':   return AppLocalization.isIndonesian ? 'Ditutup' : 'Closed';
      default:         return AppLocalization.isIndonesian ? 'Menunggu' : 'Pending';
    }
  }

  Widget _buildTabContent(String status, bool isDark) {
    final subColor = isDark ? Colors.white60 : Colors.black54;
    final isPending = status == 'pending';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getRequests(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        }
        final docs = snapshot.data?.docs ?? [];
        final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
          ..sort((a, b) {
            final ta = a.data()['requestedAt'] as Timestamp?;
            final tb = b.data()['requestedAt'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });

        if (sorted.isEmpty) {
          final String msg;
          final IconData ico;
          if (status == 'pending') { msg = AppLocalization.isIndonesian ? 'Tidak ada pengajuan menunggu' : 'No pending requests'; ico = Icons.inbox_rounded; }
          else if (status == 'approved') { msg = AppLocalization.isIndonesian ? 'Belum ada yang disetujui' : 'No approved requests'; ico = Icons.check_circle_outline_rounded; }
          else { msg = AppLocalization.isIndonesian ? 'Belum ada yang ditolak' : 'No rejected requests'; ico = Icons.cancel_outlined; }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ico, size: 56, color: subColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(msg, textAlign: TextAlign.center, style: TextStyle(color: subColor, fontSize: 14)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: sorted.length,
          itemBuilder: (context, i) => _buildRequestCard(sorted[i].data(), sorted[i].id, isDark, isPending),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
        final iconColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final tabBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor, size: 18),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: widget.category.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Icon(widget.category.icon, color: widget.category.color, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.category.collection == 'attendanceEditRequests'
                                    ? (AppLocalization.isIndonesian ? 'Persetujuan Koreksi Absensi' : 'Attendance Correction Approval')
                                    : (AppLocalization.isIndonesian ? 'Persetujuan Penghapusan Tugas' : 'Task Deletion Approval'),
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                              ),
                              Text(
                                widget.category.collection == 'attendanceEditRequests'
                                    ? (AppLocalization.isIndonesian ? 'Izin guru untuk mengedit data absensi kelas' : 'Teacher permission to edit class attendance data')
                                    : (AppLocalization.isIndonesian ? 'Pengajuan penghapusan tugas beserta jawaban murid' : 'Request to delete tasks and student answers'),
                                style: TextStyle(fontSize: 11, color: iconColor.withValues(alpha: 0.5)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('schools').doc(schoolId)
                              .collection(widget.category.collection)
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.docs.length ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                              ),
                              child: Text('$count ${AppLocalization.isIndonesian ? "menunggu" : "pending"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // ── TabBar ──────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  decoration: BoxDecoration(color: tabBgColor, borderRadius: BorderRadius.circular(14)),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(12)),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 12),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: AppLocalization.isIndonesian ? 'Menunggu' : 'Pending'),
                      Tab(text: AppLocalization.isIndonesian ? 'Disetujui' : 'Approved'),
                      Tab(text: AppLocalization.isIndonesian ? 'Ditolak' : 'Rejected'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabContent('pending', isDark),
                      _buildTabContent('approved', isDark),
                      _buildTabContent('rejected', isDark),
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
}
