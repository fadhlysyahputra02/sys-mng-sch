import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/services/session_service.dart';
import 'package:sys_mng_school/features/schools/pages/teachers/data/teacher_service.dart';
import 'package:sys_mng_school/features/students/data/student_service.dart';
import 'package:sys_mng_school/features/authentication/widgets/auth_background.dart';
import 'create_notification_page.dart';

class NotificationsPage extends StatefulWidget {
  final bool hideBackButton;
  const NotificationsPage({super.key, this.hideBackButton = false});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String? _teacherDocId;
  Set<String> _teacherClassIds = {};
  Set<String> _scheduleClassIds = {};
  Set<String> _waliClassIds = {};
  String? _studentNama;
  String? _studentClassName;
  String? _studentClassId;
  bool _isLoadingInfo = true;
  String? _errorMessage;

  StreamSubscription? _schedulesSub;
  StreamSubscription? _classesSub;

  @override
  void initState() {
    super.initState();
    _loadTeacherInfo();
  }

  @override
  void dispose() {
    _schedulesSub?.cancel();
    _classesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadTeacherInfo() async {
    final user = SessionService.currentUser!;
    if (user.role == 'teacher') {
      try {
        final schoolId = user.schoolId;
        final teacherDoc = await TeacherService().getTeacherByUid(schoolId, user.uid);
        if (teacherDoc != null) {
          _teacherDocId = teacherDoc.data()['teacherId'] ?? teacherDoc.id;

          // Listen to class schedules in real-time
          _schedulesSub?.cancel();
          _schedulesSub = FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('class_schedules')
              .where('teacherId', isEqualTo: _teacherDocId)
              .snapshots()
              .listen((schedulesSnap) {
            
            final scheduleClassIds = schedulesSnap.docs
                .map((d) => d.data()['classId'] as String?)
                .where((id) => id != null && id.isNotEmpty)
                .cast<String>()
                .toSet();

            if (mounted) {
              setState(() {
                _scheduleClassIds = scheduleClassIds;
                _teacherClassIds = {..._scheduleClassIds, ..._waliClassIds};
              });
            }
          }, onError: (e) {
            debugPrint('Error loading schedules stream: $e');
          });

          // Listen to classes where wali kelas in real-time
          _classesSub?.cancel();
          _classesSub = FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('classes')
              .where('teacherId', isEqualTo: _teacherDocId)
              .snapshots()
              .listen((waliKelasSnap) {
            
            final waliClassIds = waliKelasSnap.docs
                .map((d) => d.id)
                .toSet();

            if (mounted) {
              setState(() {
                _waliClassIds = waliClassIds;
                _teacherClassIds = {..._scheduleClassIds, ..._waliClassIds};
              });
            }
          }, onError: (e) {
            debugPrint('Error loading classes stream: $e');
          });

        } else {
          debugPrint('DEBUG NOTIF: Teacher doc not found for UID = ${user.uid}');
        }
      } catch (e) {
        debugPrint('Error loading teacher info: $e');
        _errorMessage = e.toString();
      }
    } else if (user.role == 'student') {
      try {
        final schoolId = user.schoolId;
        final studentDoc = await StudentService().getStudentDocByUid(schoolId, user.uid);
        if (studentDoc != null) {
          final data = studentDoc.data();
          if (data != null && mounted) {
            setState(() {
              _studentNama = data['nama'] as String?;
              _studentClassName = data['className'] as String?;
              _studentClassId = data['classId'] as String?;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading student info: $e');
        _errorMessage = e.toString();
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingInfo = false;
      });
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'school_admin':
      case 'tu':
        return 'Admin Sekolah';
      case 'teacher':
        return 'Guru';
      case 'student':
        return 'Siswa';
      default:
        return role;
    }
  }

  // Helper untuk format waktu
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam yang lalu';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}, ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  bool _canDeleteNotification(Map<String, dynamic> data) {
    final user = SessionService.currentUser!;
    if (user.role == 'super_admin' || user.role == 'school_admin' || user.role == 'tu') {
      return true;
    }
    if (user.role == 'teacher') {
      // Guru can only delete notifications they created
      return data['senderId'] == user.uid;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser!;
    final schoolId = user.schoolId;
    final role = user.role;

    final isStudent = role == 'student';
    final tabLength = 4;

    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final backButtonColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final indicatorColor = isDark ? const Color(0xFF8B5CF6) : const Color(0xFF8B5CF6);
        final unselectedLabelColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.4);

        if (_isLoadingInfo) {
          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : const Color(0xFF8B5CF6)),
                ),
              ),
            ),
          );
        }

        if (_errorMessage != null) {
          return Scaffold(
            body: AuthBackground(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal memuat info guru:\n$_errorMessage',
                        style: TextStyle(color: titleColor, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            _isLoadingInfo = true;
                            _errorMessage = null;
                          });
                          _loadTeacherInfo();
                        },
                        child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          body: AuthBackground(
            child: DefaultTabController(
              length: tabLength,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: !widget.hideBackButton,
                  iconTheme: IconThemeData(color: backButtonColor),
                  title: Text(
                    'Notifikasi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                  ),
                  bottom: TabBar(
                    isScrollable: true,
                    indicatorColor: indicatorColor,
                    indicatorWeight: 3,
                    labelColor: titleColor,
                    unselectedLabelColor: unselectedLabelColor,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                    tabs: const [
                      Tab(text: 'Semua (Umum)', icon: Icon(Icons.campaign_outlined, size: 20)),
                      Tab(text: 'Kelas', icon: Icon(Icons.class_outlined, size: 20)),
                      Tab(text: 'Guru', icon: Icon(Icons.person_outline, size: 20)),
                      Tab(text: 'Murid', icon: Icon(Icons.school_outlined, size: 20)),
                    ],
                  ),
                ),
                floatingActionButton: (role == 'super_admin' || role == 'school_admin' || role == 'tu' || role == 'teacher')
                    ? FloatingActionButton.extended(
                        onPressed: () {
                          Get.to(() => CreateNotificationPage(
                                teacherDocId: _teacherDocId,
                                teacherClassIds: _teacherClassIds,
                              ));
                        },
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.add_comment_rounded),
                        label: const Text('Buat Notifikasi', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    : null,
                body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('schools')
                      .doc(schoolId)
                      .collection('notifications')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(
                              'Terjadi kesalahan',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : const Color(0xFF8B5CF6)),
                        ),
                      );
                    }

                    final allDocs = snapshot.data?.docs ?? [];

                    // Filter documents based on teacher role and scope
                    final filteredDocs = allDocs.where((doc) {
                      final data = doc.data();
                      final targetType = data['targetType'] ?? '';
                      final targetId = data['targetId'] ?? '';
                      final senderId = data['senderId'] ?? '';

                      bool keep = false;

                      if (role == 'super_admin' || role == 'school_admin' || role == 'tu') {
                        keep = true;
                      } else if (role == 'teacher') {
                        if (senderId == user.uid) {
                          keep = true;
                        } else if (targetType == 'umum') {
                          keep = true;
                        } else if (targetType == 'kelas' && _teacherClassIds.contains(targetId)) {
                          keep = true;
                        } else if (targetType == 'guru' && (targetId == '' || targetId == _teacherDocId)) {
                          keep = true;
                        } else if (targetType == 'murid' && _waliClassIds.contains(data['targetClassId'] ?? '')) {
                          keep = true;
                        }
                      } else if (role == 'student') {
                        if (targetType == 'umum') {
                          keep = true;
                        } else if (targetType == 'kelas' &&
                            ((_studentClassId != null && targetId == _studentClassId) ||
                                (_studentClassName != null && data['targetName'] == _studentClassName))) {
                          keep = true;
                        } else if (targetType == 'murid' && _studentNama != null && data['targetName'] == _studentNama) {
                          keep = true;
                        }
                      }

                      return keep;
                    }).toList();

                    return TabBarView(
                      children: [
                        _buildNotificationList(
                          context,
                          filteredDocs.where((doc) => doc.data()['targetType'] == 'umum').toList(),
                          'umum',
                        ),
                        _buildNotificationList(
                          context,
                          filteredDocs.where((doc) => doc.data()['targetType'] == 'kelas').toList(),
                          'kelas',
                        ),
                        _buildNotificationList(
                          context,
                          isStudent
                              ? filteredDocs.where((doc) =>
                                  doc.data()['targetType'] == 'guru' ||
                                  (doc.data()['targetType'] == 'murid' && doc.data()['senderRole'] == 'teacher')).toList()
                              : filteredDocs.where((doc) => doc.data()['targetType'] == 'guru').toList(),
                          'guru',
                        ),
                        _buildNotificationList(
                          context,
                          isStudent
                              ? filteredDocs.where((doc) =>
                                  doc.data()['targetType'] == 'murid' && doc.data()['senderRole'] != 'teacher').toList()
                              : filteredDocs.where((doc) => doc.data()['targetType'] == 'murid').toList(),
                          'murid',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String type,
  ) {
    final isDark = AuthBackground.isDarkMode.value;
    final emptyIconColor = isDark ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF1E1B4B).withValues(alpha: 0.3);
    final emptyTextColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);

    final listTileBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final listTileBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final listTileShadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.03);

    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final textSecondaryColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF1E1B4B).withValues(alpha: 0.6);
    final textSubtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);

    final chipBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03);
    final chipBorder = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08);
    final chipTextColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF1E1B4B).withValues(alpha: 0.7);

    if (docs.isEmpty) {
      String message = 'Belum ada notifikasi umum';
      IconData icon = Icons.campaign_outlined;
      if (type == 'kelas') {
        message = 'Belum ada notifikasi kelas';
        icon = Icons.class_outlined;
      } else if (type == 'guru') {
        message = 'Belum ada notifikasi guru';
        icon = Icons.person_outline;
      } else if (type == 'murid') {
        message = 'Belum ada notifikasi murid';
        icon = Icons.school_outlined;
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: emptyIconColor),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: emptyTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 88, left: 16, right: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data();
        final title = data['title'] ?? '-';
        final content = data['content'] ?? '-';
        final targetName = data['targetName'];
        final senderName = data['senderName'] ?? '-';
        final senderRole = data['senderRole'] ?? '';
        final timestamp = (data['createdAt'] as Timestamp?)?.toDate();

        Color iconColor = const Color(0xFF8B5CF6);

        if (type == 'kelas') {
          iconColor = const Color(0xFFF59E0B);
        } else if (type == 'guru') {
          iconColor = const Color(0xFF0EA5E9);
        } else if (type == 'murid') {
          iconColor = const Color(0xFF10B981);
        }

        final showDelete = _canDeleteNotification(data);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: listTileBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: listTileBorder),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: listTileShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Type
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        type == 'umum'
                            ? Icons.campaign_rounded
                            : type == 'kelas'
                                ? Icons.class_rounded
                                : type == 'guru'
                                    ? Icons.person_rounded
                                    : Icons.school_rounded,
                        color: iconColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title and date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDateTime(timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Delete Button
                    if (showDelete)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                        onPressed: () => _confirmDeleteNotification(context, doc.reference),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Body content
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: textSubtitleColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: chipBorder, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_rounded,
                            size: 12,
                            color: chipTextColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pengirim: $senderName (${_formatRole(senderRole)})',
                            style: TextStyle(
                              color: chipTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (targetName != null && targetName.toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              type == 'kelas'
                                  ? Icons.class_rounded
                                  : type == 'guru'
                                      ? Icons.person_pin_rounded
                                      : Icons.portrait_rounded,
                              size: 12,
                              color: iconColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Penerima: $targetName',
                              style: TextStyle(
                                color: iconColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteNotification(
    BuildContext context,
    DocumentReference ref,
  ) async {
    final isDark = AuthBackground.isDarkMode.value;
    final dialogBgColor = isDark ? const Color(0xFF0F0C20) : Colors.white;
    final dialogBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);
    final titleTextColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final bodyTextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1E1B4B).withValues(alpha: 0.8);
    final cancelBtnColor = isDark ? Colors.white38 : const Color(0xFF1E1B4B).withValues(alpha: 0.5);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: dialogBorderColor, width: 1.5),
          ),
          title: Text('Hapus Notifikasi', style: TextStyle(fontWeight: FontWeight.bold, color: titleTextColor)),
          content: Text('Apakah Anda yakin ingin menghapus notifikasi ini? Tindakan ini tidak dapat dibatalkan.', style: TextStyle(color: bodyTextColor)),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('Batal', style: TextStyle(color: cancelBtnColor, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Get.back(result: true),
              child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await ref.delete();
        Get.snackbar(
          'Sukses',
          'Notifikasi berhasil dihapus',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        Get.snackbar(
          'Error',
          'Gagal menghapus notifikasi: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }
}
