import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../authentication/widgets/auth_background.dart';
import '../../schools/pages/schedule/Service/class_schedule_service.dart';
import '../../chat/chat_room_page.dart';
import '../../chat/chat_service.dart';
import '../../../core/localization/app_localization.dart';

class _ClassTeacher {
  final String teacherId;
  final String teacherName;
  final String subject;

  const _ClassTeacher({
    required this.teacherId,
    required this.teacherName,
    required this.subject,
  });
}

class ParentChatListPage extends StatefulWidget {
  final String schoolId;
  final String parentDocId;
  final String parentName;
  final String studentName;
  final String className;

  const ParentChatListPage({
    super.key,
    required this.schoolId,
    required this.parentDocId,
    required this.parentName,
    required this.studentName,
    required this.className,
  });

  @override
  State<ParentChatListPage> createState() => _ParentChatListPageState();
}

class _ParentChatListPageState extends State<ParentChatListPage> {
  final _chatService = ChatService();
  final _scheduleService = ClassScheduleService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  StreamSubscription<DocumentSnapshot>? _schoolSub;
  bool _lockDialogShown = false;

  @override
  void initState() {
    super.initState();
    _listenToAccess();
  }

  void _listenToAccess() {
    _schoolSub = FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final bool enabled = data['enableChat'] ?? false;
        if (!enabled && !_lockDialogShown && mounted) {
          _lockDialogShown = true;
          _showPremiumDialogAndExit();
        }
      }
    });
  }

  void _showPremiumDialogAndExit() {
    final isDark = AuthBackground.isDarkMode.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                AppLocalization.isIndonesian ? 'Fitur Terkunci' : 'Feature Locked',
                style: const TextStyle(color: Colors.amber),
              ),
            ],
          ),
          content: Text(
            AppLocalization.isIndonesian
                ? 'Sekolah belum berlangganan untuk mengaktifkan fitur ini.'
                : 'The school has not subscribed to activate this feature.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                if (mounted) {
                  Get.offAllNamed('/parent'); // Exit to Dashboard
                }
              },
              child: Text(
                AppLocalization.isIndonesian ? 'Tutup' : 'Close',
                style: const TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _schoolSub?.cancel();
    super.dispose();
  }

  Future<void> _openChat({
    required String teacherId,
    required String teacherName,
  }) async {
    final chatRoomId = 'parent_${widget.parentDocId}_$teacherId';

    await FirebaseFirestore.instance
        .collection('schools')
        .doc(widget.schoolId)
        .collection('parent_chats')
        .doc(chatRoomId)
        .set({
          'chatRoomId': chatRoomId,
          'teacherId': teacherId,
          'teacherName': teacherName,
          'parentId': widget.parentDocId,
          'parentName': widget.parentName,
          'studentName': widget.studentName,
          'className': widget.className,
        }, SetOptions(merge: true));

    Get.to(
      () => ChatRoomPage(
        schoolId: widget.schoolId,
        chatRoomId: chatRoomId,
        currentUserId: widget.parentDocId,
        currentUserName: widget.parentName,
        currentUserRole: 'parent',
        otherUserName: teacherName,
        isParentChat: true,
      ),
    );
  }

  List<_ClassTeacher> _buildClassTeachers({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> scheduleDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> classDocs,
  }) {
    final Map<String, _ClassTeacher> teachers = {};

    for (final doc in scheduleDocs) {
      final data = doc.data();
      final teacherId = (data['teacherId'] ?? '').toString();
      final teacherName = (data['teacherName'] ?? '').toString();
      final subject = (data['subjectName'] ?? '').toString();
      final jenisJadwal = (data['jenisJadwal'] ?? '').toString();

      if (teacherId.isEmpty ||
          teacherId == '-' ||
          teacherName.isEmpty ||
          teacherName == '-' ||
          jenisJadwal == 'istirahat') {
        continue;
      }

      final existing = teachers[teacherId];
      if (existing == null) {
        teachers[teacherId] = _ClassTeacher(
          teacherId: teacherId,
          teacherName: teacherName,
          subject: subject,
        );
      } else if (subject.isNotEmpty && !existing.subject.contains(subject)) {
        teachers[teacherId] = _ClassTeacher(
          teacherId: teacherId,
          teacherName: teacherName,
          subject: '${existing.subject}, $subject',
        );
      }
    }

    for (final doc in classDocs) {
      final data = doc.data();
      final teacherId = (data['teacherId'] ?? '').toString();
      final teacherName = (data['teacherName'] ?? '').toString();

      if (teacherId.isEmpty || teacherName.isEmpty) continue;

      teachers.putIfAbsent(
        teacherId,
        () => _ClassTeacher(
          teacherId: teacherId,
          teacherName: teacherName,
          subject: AppLocalization.isIndonesian ? 'Wali Kelas' : 'Class Teacher',
        ),
      );
    }

    final list = teachers.values.toList()
      ..sort((a, b) => a.teacherName.compareTo(b.teacherName));

    if (_searchQuery.isEmpty) return list;

    return list
        .where(
          (t) =>
              t.teacherName.toLowerCase().contains(_searchQuery) ||
              t.subject.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final textColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1E1B4B).withValues(alpha: 0.5);
        final iconBgColor = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05);
        final cardBg = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white;
        final cardBorder = isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.08);
        final inputFill = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04);

        return Scaffold(
          body: AuthBackground(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  iconTheme: IconThemeData(color: textColor),
                  leading: Container(
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: textColor,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  title: Text(
                    AppLocalization.isIndonesian ? 'Chat Guru' : 'Teacher Chat',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase().trim()),
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: AppLocalization.isIndonesian
                            ? 'Cari guru di kelas ${widget.className}...'
                            : 'Search teacher in class ${widget.className}...',
                        hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: subTextColor,
                        ),
                        fillColor: inputFill,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (_searchQuery.isNotEmpty)
                  _buildSearchResults(
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                  )
                else
                  _buildChatHistory(
                    isDark: isDark,
                    textColor: textColor,
                    subTextColor: subTextColor,
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatHistory({
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('parent_chats')
          .where('parentId', isEqualTo: widget.parentDocId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : const Color(0xFF6366F1),
              ),
            ),
          );
        }

        final chats = (snapshot.data?.docs ?? [])
            .where((doc) {
              final lastMessage = (doc.data()['lastMessage'] ?? '').toString();
              return lastMessage.isNotEmpty;
            })
            .toList()
          ..sort((a, b) {
            final aTime = a.data()['lastMessageTime'] as Timestamp?;
            final bTime = b.data()['lastMessageTime'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

        if (chats.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: subTextColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalization.isIndonesian
                        ? 'Belum ada riwayat chat.\nCari guru pengajar anak Anda untuk memulai.'
                        : 'No chat history yet.\nSearch for your child\'s teacher to start.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final data = chats[index].data();
              final chatRoomId = data['chatRoomId'] ?? chats[index].id;
              final teacherName = data['teacherName'] ?? 'Guru';
              final lastMessage = data['lastMessage'] ?? '';
              final lastTime = data['lastMessageTime'] as Timestamp?;
              final timeStr =
                  lastTime != null ? _formatTime(lastTime.toDate()) : '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Get.to(
                        () => ChatRoomPage(
                          schoolId: widget.schoolId,
                          chatRoomId: chatRoomId,
                          currentUserId: widget.parentDocId,
                          currentUserName: widget.parentName,
                          currentUserRole: 'parent',
                          otherUserName: teacherName,
                          isParentChat: true,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.15),
                              border: Border.all(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF6366F1),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        teacherName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: subTextColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StreamBuilder<int>(
                            stream: _chatService.getUnreadCount(
                              schoolId: widget.schoolId,
                              chatRoomId: chatRoomId,
                              currentUserId: widget.parentDocId,
                              collectionName: 'parent_chats',
                            ),
                            builder: (context, unreadSnap) {
                              final count = unreadSnap.data ?? 0;
                              if (count == 0) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: chats.length),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults({
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
    required Color cardBg,
    required Color cardBorder,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _scheduleService.getSchedulesByClassName(
        widget.schoolId,
        widget.className,
      ),
      builder: (context, scheduleSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('schools')
              .doc(widget.schoolId)
              .collection('classes')
              .where('namaKelas', isEqualTo: widget.className)
              .snapshots(),
          builder: (context, classSnap) {
            if (scheduleSnap.connectionState == ConnectionState.waiting ||
                classSnap.connectionState == ConnectionState.waiting) {
              return SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: isDark ? Colors.white : const Color(0xFF6366F1),
                  ),
                ),
              );
            }

            final teachers = _buildClassTeachers(
              scheduleDocs: scheduleSnap.data?.docs ?? [],
              classDocs: classSnap.data?.docs ?? [],
            );

            if (teachers.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    AppLocalization.isIndonesian
                        ? 'Tidak ada guru ditemukan di kelas ${widget.className}.'
                        : 'No teachers found in class ${widget.className}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subTextColor, fontSize: 14),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final teacher = teachers[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openChat(
                          teacherId: teacher.teacherId,
                          teacherName: teacher.teacherName,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      teacher.teacherName,
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (teacher.subject.isNotEmpty)
                                      Text(
                                        teacher.subject,
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.6),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: teachers.length),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
