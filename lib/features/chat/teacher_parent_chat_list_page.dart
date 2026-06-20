import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../authentication/widgets/auth_background.dart';
import 'chat_room_page.dart';
import 'chat_service.dart';

class TeacherParentChatListPage extends StatefulWidget {
  final String schoolId;
  final String teacherDocId;
  final String teacherName;

  const TeacherParentChatListPage({
    super.key,
    required this.schoolId,
    required this.teacherDocId,
    required this.teacherName,
  });

  @override
  State<TeacherParentChatListPage> createState() =>
      _TeacherParentChatListPageState();
}

class _TeacherParentChatListPageState extends State<TeacherParentChatListPage> {
  final _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  List<Map<String, dynamic>> _allParents = [];
  bool _isLoadingParents = false;

  @override
  void initState() {
    super.initState();
    _loadAllParents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllParents() async {
    if (!mounted) return;
    setState(() => _isLoadingParents = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('parents')
          .get();

      final list = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      list.sort((a, b) {
        final nameA = (a['studentName'] ?? '').toString().toLowerCase();
        final nameB = (b['studentName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _allParents = list;
          _isLoadingParents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingParents = false);
      }
    }
  }

  void _openChat(Map<String, dynamic> parent) {
    final parentId = parent['id'];
    final parentName = parent['nama'] ?? 'Wali Murid';
    final studentName = parent['studentName'] ?? '';
    // Format ID: parent_{parentId}_{teacherId}
    final chatRoomId = 'parent_${parentId}_${widget.teacherDocId}';
    
    Get.to(
      () => ChatRoomPage(
        schoolId: widget.schoolId,
        chatRoomId: chatRoomId,
        currentUserId: widget.teacherDocId,
        currentUserName: widget.teacherName,
        currentUserRole: 'teacher',
        otherUserName: '$parentName (Wali $studentName)',
        isParentChat: true,
      ),
    );
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
                    'Chat Wali Murid',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: textColor,
                    ),
                  ),
                ),

                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama siswa dari wali murid...',
                        hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: subTextColor, size: 20),
                        filled: true,
                        fillColor: isDark 
                            ? Colors.white.withValues(alpha: 0.03) 
                            : Colors.black.withValues(alpha: 0.03),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFF97316)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),

                if (_searchQuery.isNotEmpty)
                  _buildSearchResults(isDark, textColor, subTextColor, cardBg, cardBorder)
                else
                  _buildChatList(isDark, textColor, subTextColor, cardBg, cardBorder),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardBg,
    Color cardBorder,
  ) {
    if (_isLoadingParents) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : const Color(0xFFF97316),
          ),
        ),
      );
    }

    final queryStr = _searchQuery.toLowerCase();
    final filtered = _allParents.where((parent) {
      final studentName = (parent['studentName'] ?? '').toString().toLowerCase();
      final parentName = (parent['nama'] ?? '').toString().toLowerCase();
      return studentName.contains(queryStr) || parentName.contains(queryStr);
    }).toList();

    final limit = filtered.length > 50 ? 50 : filtered.length;
    final displayList = filtered.sublist(0, limit);

    if (displayList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Tidak ada wali murid yang ditemukan',
            style: TextStyle(color: subTextColor),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final parent = displayList[index];
          final parentName = parent['nama'] ?? 'Wali Murid';
          final studentName = parent['studentName'] ?? '';
          final className = parent['className'] ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openChat(parent),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF97316).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFFF97316).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.family_restroom_rounded,
                          color: Color(0xFFF97316),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              parentName,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (studentName.isNotEmpty)
                              Text(
                                'Wali dari: $studentName ($className)',
                                style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chat_bubble_rounded, color: Color(0xFFF97316), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }, childCount: displayList.length),
      ),
    );
  }

  Widget _buildChatList(
    bool isDark,
    Color textColor,
    Color subTextColor,
    Color cardBg,
    Color cardBorder,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('parent_chats')
          .where('teacherId', isEqualTo: widget.teacherDocId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : const Color(0xFF8B5CF6),
              ),
            ),
          );
        }

        var chats = snapshot.data?.docs ?? [];

        // Sort manual: terbaru di atas
        chats.sort((a, b) {
          final aTime =
              (a.data()['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime =
              (b.data()['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
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
                    Icons.family_restroom_rounded,
                    size: 64,
                    color: subTextColor.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada wali murid yang mengirim pesan.\nCari wali murid untuk memulai chat.',
                    textAlign: TextAlign.center,
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
              final chatRoomId = data['chatRoomId'] ?? chats[index].id;
              final parentName = data['parentName'] ?? 'Wali Murid';
              final studentName = data['studentName'] ?? '';
              final lastMessage = data['lastMessage'] ?? '';
              final lastTime = data['lastMessageTime'] as Timestamp?;
              final timeStr = lastTime != null ? _formatTime(lastTime.toDate()) : '';

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
                          otherUserName: parentName,
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
                              color: const Color(0xFFF97316).withValues(alpha: 0.15),
                              border: Border.all(
                                color: const Color(0xFFF97316).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.family_restroom_rounded,
                              color: Color(0xFFF97316),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      parentName,
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
                                if (studentName.isNotEmpty)
                                  Text(
                                    'Wali dari: $studentName',
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
                                  color: const Color(0xFFF97316),
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
