import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../authentication/widgets/auth_background.dart';
import 'chat_room_page.dart';
import 'chat_service.dart';

class StudentChatListPage extends StatefulWidget {
  final String schoolId;
  final String studentDocId;
  final String studentName;
  final String className;

  const StudentChatListPage({
    super.key,
    required this.schoolId,
    required this.studentDocId,
    required this.studentName,
    required this.className,
  });

  @override
  State<StudentChatListPage> createState() => _StudentChatListPageState();
}

class _StudentChatListPageState extends State<StudentChatListPage> {
  final _chatService = ChatService();
  final _searchController = TextEditingController();
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
                // AppBar
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
                    'Chat Guru',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),

                // Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cari nama guru...',
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
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Daftar Guru
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('schools')
                      .doc(widget.schoolId)
                      .collection('teachers')
                      .snapshots(),
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

                    final teachers = (snapshot.data?.docs ?? []).where((doc) {
                      final name = (doc.data()['nama'] ?? '')
                          .toString()
                          .toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();

                    if (teachers.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            'Tidak ada guru ditemukan.',
                            style: TextStyle(color: subTextColor),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final doc = teachers[index];
                          final data = doc.data();
                          final teacherId = doc.id;
                          final teacherName = data['nama'] ?? 'Guru';
                          final subject =
                              data['mataPelajaran'] ?? data['mapel'] ?? '';
                          final chatRoomId = _chatService.getChatRoomId(
                            teacherId,
                            widget.studentDocId,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  // Simpan metadata chat room dulu
                                  FirebaseFirestore.instance
                                      .collection('schools')
                                      .doc(widget.schoolId)
                                      .collection('chats')
                                      .doc(chatRoomId)
                                      .set({
                                        'chatRoomId': chatRoomId,
                                        'teacherId': teacherId,
                                        'teacherName': teacherName,
                                        'studentId': widget.studentDocId,
                                        'studentName': widget.studentName,
                                        'className': widget.className,
                                      }, SetOptions(merge: true));

                                  Get.to(
                                    () => ChatRoomPage(
                                      schoolId: widget.schoolId,
                                      chatRoomId: chatRoomId,
                                      currentUserId: widget.studentDocId,
                                      currentUserName: widget.studentName,
                                      currentUserRole: 'student',
                                      otherUserName: teacherName,
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
                                            0xFF8B5CF6,
                                          ).withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF8B5CF6,
                                            ).withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF8B5CF6),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              teacherName,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (subject.isNotEmpty)
                                              Text(
                                                subject,
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
                                        color: const Color(
                                          0xFF8B5CF6,
                                        ).withValues(alpha: 0.6),
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
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }
}
