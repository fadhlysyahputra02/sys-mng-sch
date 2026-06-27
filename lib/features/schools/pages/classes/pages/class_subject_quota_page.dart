import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../data/class_service.dart';

class ClassSubjectQuotaPage extends StatefulWidget {
  final String classId;
  final String className;
  final Map<String, int> initialQuotas;

  const ClassSubjectQuotaPage({
    super.key,
    required this.classId,
    required this.className,
    required this.initialQuotas,
  });

  @override
  State<ClassSubjectQuotaPage> createState() => _ClassSubjectQuotaPageState();
}

class _ClassSubjectQuotaPageState extends State<ClassSubjectQuotaPage> {
  final ClassService _classService = ClassService();
  final Map<String, int> _quotas = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _quotas.addAll(widget.initialQuotas);
  }

  Future<void> _saveQuotas() async {
    setState(() => _isSaving = true);
    try {
      await _classService.updateSubjectQuotas(
        classId: widget.classId,
        quotas: _quotas,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alokasi jam berhasil disimpan')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  int get _totalJpPerSeminggu {
    return _quotas.values.fold(0, (sum, element) => sum + element);
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = SessionService.currentUser!.schoolId;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.55);
        final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

        return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // ── AppBar ────────────────────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Alokasi Jam Pelajaran',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              Text(
                                '${widget.className} • Total: $_totalJpPerSeminggu JP / Minggu',
                                style: TextStyle(fontSize: 12, color: subTextColor),
                              ),
                            ],
                          ),
                        ),
                        if (_isSaving)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                          )
                        else
                          IconButton(
                            onPressed: _saveQuotas,
                            icon: const Icon(Icons.check_rounded, color: Colors.greenAccent),
                            tooltip: 'Simpan',
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Hint ──────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.08 : 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Atur berapa jam mata pelajaran ini diajarkan di kelas ${widget.className} dalam seminggu.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.75),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Content ────────────────────────────────────────────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(schoolId)
                        .collection('subjects')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book_outlined, size: 48, color: textColor.withValues(alpha: 0.35)),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada mata pelajaran',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final subject = docs[index].data() as Map<String, dynamic>;
                          final subjectId = subject['subjectId'] ?? docs[index].id;
                          final quota = _quotas[subjectId] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cardBorderColor),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: quota > 0
                                            ? [const Color(0xFF10B981), const Color(0xFF34D399)]
                                            : [const Color(0xFF6366F1).withValues(alpha: 0.5), const Color(0xFF8B5CF6).withValues(alpha: 0.5)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.book_rounded, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject['namaMapel'] ?? '-',
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subject['kodeMapel'] ?? '-',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      _buildCounterBtn(
                                        icon: Icons.remove_rounded,
                                        onTap: () {
                                          if (quota > 0) {
                                            setState(() => _quotas[subjectId] = quota - 1);
                                          }
                                        },
                                        enabled: quota > 0,
                                        isDark: isDark,
                                        textColor: textColor,
                                      ),
                                      Container(
                                        width: 36,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$quota',
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      _buildCounterBtn(
                                        icon: Icons.add_rounded,
                                        onTap: () {
                                          setState(() => _quotas[subjectId] = quota + 1);
                                        },
                                        enabled: true,
                                        isDark: isDark,
                                        textColor: textColor,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _saveQuotas,
            backgroundColor: const Color(0xFF6366F1),
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            label: Text(
              'Simpan Alokasi ($_totalJpPerSeminggu JP)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCounterBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
    required bool isDark,
    required Color textColor,
  }) {
    final bg = enabled
        ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;
    final border = enabled
        ? (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1))
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05));
    final iconColor = enabled
        ? textColor
        : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2));

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor,
        ),
      ),
    );
  }
}
