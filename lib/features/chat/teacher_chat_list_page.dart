import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../authentication/widgets/auth_background.dart';
import '../../core/localization/app_localization.dart';
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
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  List<Map<String, dynamic>> _allStudents = [];
  bool _isLoadingStudents = false;
  
  StreamSubscription<DocumentSnapshot>? _schoolSub;
  bool _lockDialogShown = false;

  @override
  void initState() {
    super.initState();
    _loadAllStudents();
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
              Text(AppLocalization.isIndonesian ? 'Fitur Terkunci' : 'Feature Locked', style: const TextStyle(color: Colors.amber)),
            ],
          ),
          content: Text(
            AppLocalization.isIndonesian ? 'Sekolah belum berlangganan untuk mengaktifkan fitur ini.' : 'The school has not subscribed to enable this feature.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                if (mounted) {
                  Get.offAllNamed('/teacher'); // Exit to Dashboard
                }
              },
              child: Text(AppLocalization.isIndonesian ? 'Tutup' : 'Close', style: const TextStyle(color: Color(0xFF6366F1))),
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

  Future<void> _loadAllStudents() async {
    if (!mounted) return;
    setState(() => _isLoadingStudents = true);
    try {
      final query = await FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('students')
          .where('aktif', isEqualTo: true)
          .get();

      final list = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      list.sort((a, b) {
        final nameA = (a['nama'] ?? '').toString().toLowerCase();
        final nameB = (b['nama'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _allStudents = list;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  void _openChat(Map<String, dynamic> student) {
    final studentId = student['id'];
    final studentName = student['nama'] ?? 'Murid';
    final chatRoomId = _chatService.getChatRoomId(widget.teacherDocId, studentId);
    
    Get.to(
      () => ChatRoomPage(
        schoolId: widget.schoolId,
        chatRoomId: chatRoomId,
        currentUserId: widget.teacherDocId,
        currentUserName: widget.teacherName,
        currentUserRole: 'teacher',
        otherUserName: studentName,
        isParentChat: false,
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
                    AppLocalization.isIndonesian ? 'Chat Murid' : 'Student Chat',
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
                        hintText: AppLocalization.isIndonesian ? 'Cari nama murid untuk chat...' : 'Search student name to chat...',
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
                          borderSide: const BorderSide(color: Color(0xFF10B981)),
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
    if (_isLoadingStudents) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : const Color(0xFF10B981),
          ),
        ),
      );
    }

    final queryStr = _searchQuery.toLowerCase();
    final filtered = _allStudents.where((student) {
      final name = (student['nama'] ?? '').toString().toLowerCase();
      return name.contains(queryStr);
    }).toList();

    final limit = filtered.length > 50 ? 50 : filtered.length;
    final displayList = filtered.sublist(0, limit);

    if (displayList.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            AppLocalization.isIndonesian ? 'Tidak ada murid yang ditemukan' : 'No student found',
            style: TextStyle(color: subTextColor),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final student = displayList[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openChat(student),
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['nama'] ?? '-',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppLocalization.isIndonesian ? 'Kelas: ${student['className'] ?? '-'}' : 'Class: ${student['className'] ?? '-'}',
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chat_bubble_rounded, color: Color(0xFF10B981), size: 20),
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
      stream: _chatService.getTeacherChatRooms(
        schoolId: widget.schoolId,
        teacherId: widget.teacherDocId,
      ),
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
        
        // Sort by latest message manually
        chats.sort((a, b) {
          final aTime = (a.data()['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTime = (b.data()['lastMessageTime'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
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
                    AppLocalization.isIndonesian ? 'Belum ada chat.\nCari murid untuk memulai chat.' : 'No chat yet.\nSearch for a student to start chatting.',
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
              final studentName = data['studentName'] ?? 'Murid';
              final className = data['className'] ?? '';
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
                          otherUserName: studentName,
                          isParentChat: false,
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
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
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
