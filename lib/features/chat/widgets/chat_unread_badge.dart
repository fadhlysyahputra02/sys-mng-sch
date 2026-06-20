import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../chat_service.dart';

class ChatUnreadBadge extends StatefulWidget {
  final String schoolId;
  final String userId;
  final String role; // 'teacher', 'student', 'parent'
  final Widget child;
  final double top;
  final double right;

  const ChatUnreadBadge({
    super.key,
    required this.schoolId,
    required this.userId,
    required this.role,
    required this.child,
    this.top = -5,
    this.right = -5,
  });

  @override
  State<ChatUnreadBadge> createState() => _ChatUnreadBadgeState();
}

class _ChatUnreadBadgeState extends State<ChatUnreadBadge> {
  final _chatService = ChatService();
  final List<StreamSubscription> _roomsSubs = [];
  final Map<String, StreamSubscription> _unreadSubs = {};
  final Map<String, int> _unreadCounts = {};
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    _listenToRooms();
  }

  @override
  void dispose() {
    for (var sub in _roomsSubs) {
      sub.cancel();
    }
    for (var sub in _unreadSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _listenToRooms() {
    if (widget.role == 'student') {
      _listenToQuery(_chatService.getStudentChatRooms(
        schoolId: widget.schoolId,
        studentId: widget.userId,
      ), 'chats');
    } else if (widget.role == 'parent') {
      _listenToQuery(FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('parent_chats')
          .where('parentId', isEqualTo: widget.userId)
          .snapshots(), 'parent_chats');
    } else if (widget.role == 'teacher') {
      _listenToQuery(_chatService.getTeacherChatRooms(
        schoolId: widget.schoolId,
        teacherId: widget.userId,
      ), 'chats');
      _listenToQuery(FirebaseFirestore.instance
          .collection('schools')
          .doc(widget.schoolId)
          .collection('parent_chats')
          .where('teacherId', isEqualTo: widget.userId)
          .snapshots(), 'parent_chats');
    }
  }

  void _listenToQuery(Stream<QuerySnapshot<Map<String, dynamic>>> stream, String collectionName) {
    final sub = stream.listen((snapshot) {
      final currentRoomIds = snapshot.docs.map((doc) => doc.id).toSet();
      
      // Remove subs for rooms that no longer exist
      final toRemove = _unreadSubs.keys.where((id) {
        if (!id.startsWith('${collectionName}_')) return false;
        final roomId = id.replaceFirst('${collectionName}_', '');
        return !currentRoomIds.contains(roomId);
      }).toList();

      for (var id in toRemove) {
        _unreadSubs[id]?.cancel();
        _unreadSubs.remove(id);
        _unreadCounts.remove(id);
      }

      for (var doc in snapshot.docs) {
        final roomId = doc.id;
        final subKey = '${collectionName}_$roomId';
        if (!_unreadSubs.containsKey(subKey)) {
          _unreadSubs[subKey] = _chatService.getUnreadCount(
            schoolId: widget.schoolId,
            chatRoomId: roomId,
            currentUserId: widget.userId,
            collectionName: collectionName,
          ).listen((count) {
            if (mounted) {
              setState(() {
                _unreadCounts[subKey] = count;
                _totalUnread = _unreadCounts.values.fold(0, (sum, val) => sum + val);
              });
            }
          });
        }
      }
    });
    _roomsSubs.add(sub);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (_totalUnread > 0)
          Positioned(
            top: widget.top,
            right: widget.right,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Center(
                child: Text(
                  _totalUnread > 99 ? '99+' : _totalUnread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
