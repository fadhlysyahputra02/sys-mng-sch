import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../authentication/widgets/auth_background.dart';
import 'chat_room_page.dart';
import 'chat_service.dart';

class TeacherChatListPage extends StatefulWidget {
  final String schoolId;
  final String teacherDocId;
  final String teacherName;

  const TeacherChatListPage({
    super.key,
    required this.schoolId,
    required this.teacherDocId,
    required this.teacherName,
  });

  @override
  State<TeacherChatListPage> createState() => _TeacherChatListPageState();
}

class _TeacherChatListPageState extends State<TeacherChatListPage> {
  final _chatService = ChatService();

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
                    'Chat Murid',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatService.getTeacherChatRooms(
                    schoolId: widget.schoolId,
                    teacherId: widget.teacherDocId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF8B5CF6),
                          ),
                        ),
                      );
                    }

                    final chats = snapshot.data?.docs ?? [];

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
                                'Belum ada murid yang mengirim pesan.',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final data = chats[index].data();
                          final chatRoomId =
                              data['chatRoomId'] ?? chats[index].id;
                          final studentName = data['studentName'] ?? 'Murid';
                          final className = data['className'] ?? '';
                          final lastMessage = data['lastMessage'] ?? '';
                          final lastTime =
                              data['lastMessageTime'] as Timestamp?;
                          final timeStr = lastTime != null
                              ? _formatTime(lastTime.toDate())
                              : '';

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
                                      currentUserId: widget.teacherDocId,
                                      currentUserName: widget.teacherName,
                                      currentUserRole: 'teacher',
                                      otherUserName: studentName,
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
                                              color: Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
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
                                          color: const Color(
                                            0xFF10B981,
                                          ).withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF10B981),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  studentName,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
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
                                            if (className.isNotEmpty)
                                              Text(
                                                className,
                                                style: TextStyle(
                                                  color: subTextColor,
                                                  fontSize: 11,
                                                ),
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
                                      // Unread badge
                                      StreamBuilder<int>(
                                        stream: _chatService.getUnreadCount(
                                          schoolId: widget.schoolId,
                                          chatRoomId: chatRoomId,
                                          currentUserId: widget.teacherDocId,
                                        ),
                                        builder: (context, unreadSnap) {
                                          final count = unreadSnap.data ?? 0;
                                          if (count == 0) {
                                            return const SizedBox.shrink();
                                          }
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF8B5CF6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
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
