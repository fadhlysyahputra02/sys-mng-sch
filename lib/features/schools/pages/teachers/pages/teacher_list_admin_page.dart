import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:sys_mng_school/core/services/session_service.dart';
import '../../../../authentication/widgets/auth_background.dart';
import 'package:sys_mng_school/core/localization/app_localization.dart';
import '../../../services/excel_import_service.dart';
import 'add_teacher_admin_page.dart';
import 'teacher_detail_admin_page.dart';

class TeacherListPage extends StatefulWidget {
  final String schoolId;
  final bool hideBackButton;

  const TeacherListPage({
    super.key,
    required this.schoolId,
    this.hideBackButton = false,
  });

  @override
  State<TeacherListPage> createState() => _TeacherListPageState();
}

class _TeacherListPageState extends State<TeacherListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocalization.currentLocale,
          builder: (context, locale, _) {
            final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
            final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
            final mutedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
            final cardBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
            final borderCol = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

            return Scaffold(
          body: AuthBackground(
            child: Column(
              children: [
                // AppBar Area
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        if (!widget.hideBackButton)
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
                          ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalization.teacherDataTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _handleImport(context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.file_upload_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalization.importExcel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddTeacherPage(schoolId: widget.schoolId),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppLocalization.teacherAddButton,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
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

                // Search Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppLocalization.teacherSearchHint,
                      hintStyle: TextStyle(color: mutedColor, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: mutedColor, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: mutedColor, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),

                // Body
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('schools')
                        .doc(widget.schoolId)
                        .collection('teachers')
                        .snapshots(),
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
                              Text(
                                AppLocalization.errorOccurred,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          ),
                        );
                      }

                      var docs = snapshot.data?.docs ?? [];
                      
                      if (docs.isNotEmpty) {
                        docs.sort((a, b) {
                          final dataA = a.data() as Map<String, dynamic>;
                          final dataB = b.data() as Map<String, dynamic>;
                          final nameA = (dataA['nama'] ?? '').toString().toLowerCase();
                          final nameB = (dataB['nama'] ?? '').toString().toLowerCase();
                          
                          // Natural sort comparison
                          final regExp = RegExp(r'(\d+|\D+)');
                          final aMatches = regExp.allMatches(nameA).map((m) => m.group(0)!).toList();
                          final bMatches = regExp.allMatches(nameB).map((m) => m.group(0)!).toList();

                          for (int i = 0; i < aMatches.length && i < bMatches.length; i++) {
                            final aPart = aMatches[i];
                            final bPart = bMatches[i];
                            final aInt = int.tryParse(aPart);
                            final bInt = int.tryParse(bPart);

                            if (aInt != null && bInt != null) {
                              if (aInt != bInt) return aInt.compareTo(bInt);
                            } else {
                              final comp = aPart.compareTo(bPart);
                              if (comp != 0) return comp;
                            }
                          }
                          return aMatches.length.compareTo(bMatches.length);
                        });
                        
                        if (_searchQuery.isNotEmpty) {
                          docs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final nama = (data['nama'] ?? '').toString().toLowerCase();
                            final nip = (data['nip'] ?? '').toString().toLowerCase();
                            return nama.contains(_searchQuery) || nip.contains(_searchQuery);
                          }).toList();
                        }
                      }

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: textColor.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderCol),
                                ),
                                child: Icon(Icons.person_off_rounded, size: 48, color: mutedColor),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                AppLocalization.noTeacherData,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalization.addTeacherGuide,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final guru = docs[index].data() as Map<String, dynamic>;
                          final bool isRegistered = guru['sudahRegister'] ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderCol),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TeacherDetailPage(teacher: guru),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              guru['nama'] ?? '-',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Icon(Icons.badge_outlined, size: 13, color: mutedColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${AppLocalization.nipLabel}${guru['nip'] ?? '-'}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: subtitleColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if ((guru['email'] ?? '').toString().isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Icon(Icons.mail_outline_rounded, size: 13, color: mutedColor),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      guru['email'],
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: subtitleColor.withValues(alpha: 0.8),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isRegistered
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: isRegistered
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                                ),
                                              ),
                                              child: Text(
                                                isRegistered ? AppLocalization.registeredStatus : AppLocalization.notRegisteredStatus,
                                                style: TextStyle(
                                                  color: isRegistered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 14,
                                        color: mutedColor,
                                      ),
                                    ],
                                  ),
                                ),
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
        );
          },
        );
      },
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
        ),
      ),
    );

    try {
      final user = SessionService.currentUser;
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .get();
          
      final schoolData = schoolDoc.data();
      final bool enableImportExcelTeacher = schoolData?['enableImportExcelTeacher'] ?? false;
      
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
      }

      if ((user?.role == 'school_admin' || user?.role == 'tu') && !enableImportExcelTeacher) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF151026),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(AppLocalization.featureLockedTitle, style: const TextStyle(color: Colors.white)),
                ],
              ),
              content: Text(
                AppLocalization.importDisabledBySuperAdmin,
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(color: Color(0xFF8B5CF6))),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        _showImportGuide(context);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  void _showImportGuide(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorder, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF10B981), size: 36),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppLocalization.excelGuideTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalization.excelGuideSubtitle,
                style: TextStyle(color: subtitleColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildGuideItem(AppLocalization.excelGuideFormat, subtitleColor),
              _buildGuideItem(AppLocalization.excelGuideHeader, subtitleColor),
              _buildGuideItem(AppLocalization.excelGuideColName, subtitleColor),
              _buildGuideItem(AppLocalization.excelGuideTeacherNip, subtitleColor),
              _buildGuideItem(AppLocalization.excelGuideTeacherNipUnique, subtitleColor),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext); // Tutup guide dialog

                    if (!context.mounted) return;

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (loadingContext) => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        ),
                      ),
                    );

                    final success = await ExcelImportService().downloadTemplate('guru');
                    
                    if (context.mounted) {
                      Navigator.pop(context); // Tutup loading dialog
                    }

                    if (success == true) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalization.excelTemplateSaved)),
                        );
                        _showImportGuide(context); // Buka kembali guide agar user bisa pilih file
                      }
                    } else if (success == false) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalization.excelTemplateSaveFailed)),
                        );
                        _showImportGuide(context);
                      }
                    } else {
                      // null = batal
                      if (context.mounted) {
                        _showImportGuide(context);
                      }
                    }
                  },
                  icon: const Icon(Icons.download_rounded, color: Color(0xFF10B981), size: 18),
                  label: Text(AppLocalization.downloadExcelTemplate, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF1E1B4B).withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(AppLocalization.cancel, style: TextStyle(color: textColor)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _startImporting(context);
                        },
                        child: Text(AppLocalization.chooseFile, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideItem(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final mutedColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorder, width: 1.5),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalization.premiumFeatureTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalization.importTeacherPremiumMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalization.upgradePackageMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: mutedColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalization.close, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _startImporting(BuildContext context) async {
    final isDark = AuthBackground.isDarkMode.value;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withValues(alpha: 0.7);
    final dialogBg = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.08);

    String status = 'pilih_file';
    double progress = 0.0;
    String statusText = AppLocalization.readingExcelData;
    ExcelImportResult? importResult;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (status == 'pilih_file') {
              status = 'memproses';
              
              ExcelImportService().importTeachers(
                widget.schoolId,
                onFileSelected: () {
                  setModalState(() {
                    statusText = AppLocalization.readingExcelData;
                  });
                },
                onProgress: (current, total) {
                  setModalState(() {
                    statusText = AppLocalization.importProgressMsg(current, total);
                    progress = total > 0 ? current / total : 0.0;
                  });
                },
              ).then((result) {
                setModalState(() {
                  status = 'selesai';
                  importResult = result;
                });
              }).catchError((err) {
                setModalState(() {
                  status = 'selesai';
                  importResult = ExcelImportResult(
                    successCount: 0,
                    duplicateCount: 0,
                    failedCount: 1,
                    errors: ['${AppLocalization.failedProcessFile}: $err'],
                  );
                });
              });
            }

            if (status == 'memproses') {
              return AlertDialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: dialogBorder, width: 1.5),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    CircularProgressIndicator(
                      value: progress > 0.0 ? progress : null,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1E1B4B).withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (progress > 0.0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              );
            }

            if (importResult == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) Navigator.pop(dialogContext);
              });
              return const SizedBox.shrink();
            }

            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: dialogBorder, width: 1.5),
              ),
              title: Text(
                AppLocalization.importResultTitle,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              // SizedBox dengan lebar tertentu mencegah AlertDialog
              // mencoba mengukur intrinsic width secara rekursif
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildResultRow(Icons.check_circle_outline_rounded, Colors.green, AppLocalization.importSuccessCount(importResult!.successCount), textColor),
                    const SizedBox(height: 10),
                    _buildResultRow(Icons.error_outline_rounded, Colors.red, AppLocalization.importFailedCount(importResult!.failedCount), textColor),
                    if (importResult!.errors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        AppLocalization.errorDetailTitle,
                        style: TextStyle(color: subtitleColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        // maxHeight membatasi tinggi list — ListView bisa scroll di dalamnya
                        // tanpa perlu shrinkWrap (shrinkWrap di dalam Column(min) + AlertDialog
                        // menyebabkan viewport mencoba hitung intrinsic dimension → crash)
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF1E1B4B).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: importResult!.errors.length,
                          itemBuilder: (context, idx) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              importResult!.errors[idx],
                              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (ctx.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResultRow(IconData icon, Color color, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
