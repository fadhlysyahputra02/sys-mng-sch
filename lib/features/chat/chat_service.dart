import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  final _firestore = FirebaseFirestore.instance;

  /// Generate consistent chatRoomId antara guru dan murid
  String getChatRoomId(String teacherId, String studentId) {
    return '${teacherId}_$studentId';
  }

  /// Kirim pesan
  Future<void> sendMessage({
    required String schoolId,
    required String chatRoomId,
    required String senderId,
    required String senderName,
    required String senderRole, // 'teacher' atau 'student' atau 'parent'
    required String message,
    String collectionName = 'chats',
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection(collectionName)
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': senderId,
          'senderName': senderName,
          'senderRole': senderRole,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

    // Update metadata chat room
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection(collectionName)
        .doc(chatRoomId)
        .set({
          'chatRoomId': chatRoomId,
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': senderId,
          'lastSenderName': senderName,
        }, SetOptions(merge: true));

    // Kirim push notification
    try {
      String? recipientUid;
      if (collectionName == 'chats') {
        String? teacherId;
        String? studentId;

        final chatRoomDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('chats')
            .doc(chatRoomId)
            .get();
        if (chatRoomDoc.exists) {
          final data = chatRoomDoc.data();
          if (data != null) {
            teacherId = data['teacherId'] as String?;
            studentId = data['studentId'] as String?;
          }
        }

        // Fallback: parse from chatRoomId (teacherDocId_studentDocId)
        if ((teacherId == null || studentId == null) && chatRoomId.contains('_')) {
          final parts = chatRoomId.split('_');
          if (parts.length >= 2) {
            teacherId = parts[0];
            studentId = parts[1];
          }
        }

        if (senderRole == 'teacher') {
          if (studentId != null) {
            final studentDoc = await _firestore
                .collection('schools')
                .doc(schoolId)
                .collection('students')
                .doc(studentId)
                .get();
            recipientUid = studentDoc.data()?['uid'] as String?;
          }
        } else {
          if (teacherId != null) {
            final teacherDoc = await _firestore
                .collection('schools')
                .doc(schoolId)
                .collection('teachers')
                .doc(teacherId)
                .get();
            recipientUid = teacherDoc.data()?['uid'] as String?;
          }
        }
      } else if (collectionName == 'parent_chats') {
        String? teacherId;
        String? parentId;

        final chatRoomDoc = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('parent_chats')
            .doc(chatRoomId)
            .get();
        if (chatRoomDoc.exists) {
          final data = chatRoomDoc.data();
          if (data != null) {
            teacherId = data['teacherId'] as String?;
            parentId = data['parentId'] as String?;
          }
        }

        // Fallback: parse from chatRoomId (parent_parentUid_teacherDocId)
        if ((teacherId == null || parentId == null) && chatRoomId.startsWith('parent_')) {
          final parts = chatRoomId.split('_');
          if (parts.length >= 3) {
            parentId = parts[1];
            teacherId = parts[2];
          }
        }

        if (senderRole == 'teacher') {
          recipientUid = parentId;
        } else {
          if (teacherId != null) {
            final teacherDoc = await _firestore
                .collection('schools')
                .doc(schoolId)
                .collection('teachers')
                .doc(teacherId)
                .get();
            recipientUid = teacherDoc.data()?['uid'] as String?;
          }
        }
      }

      if (recipientUid != null && recipientUid.isNotEmpty) {
        await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('notifications')
            .add({
          'title': senderName,
          'content': message,
          'targetType': 'personal',
          'targetId': recipientUid,
          'senderId': senderId,
          'senderName': senderName,
          'senderRole': senderRole,
          'category': 'chat',
          'chatRoomId': chatRoomId,
          'isParentChat': collectionName == 'parent_chats',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error sending chat push notification: $e');
    }
  }

  /// Stream pesan realtime
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages({
    required String schoolId,
    required String chatRoomId,
    String collectionName = 'chats',
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection(collectionName)
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Stream daftar chat room untuk guru (berdasarkan teacherId)
  Stream<QuerySnapshot<Map<String, dynamic>>> getTeacherChatRooms({
    required String schoolId,
    required String teacherId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('chats')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots(); // hapus orderBy
  }

  /// Tandai pesan sudah dibaca
  Future<void> markAsRead({
    required String schoolId,
    required String chatRoomId,
    required String currentUserId,
    String collectionName = 'chats',
  }) async {
    // Query hanya berdasarkan isRead (1 where clause = no composite index needed)
    // Filter senderId di client-side
    final messages = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection(collectionName)
        .doc(chatRoomId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final doc in messages.docs) {
      // Hanya tandai pesan dari orang lain
      if (doc.data()['senderId'] != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
        hasUpdates = true;
      }
    }
    if (hasUpdates) await batch.commit();
  }

  /// Hitung unread messages untuk satu chat room
  /// Query hanya isRead=false, filter senderId di client-side (no composite index)
  Stream<int> getUnreadCount({
    required String schoolId,
    required String chatRoomId,
    required String currentUserId,
    String collectionName = 'chats',
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection(collectionName)
        .doc(chatRoomId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => doc.data()['senderId'] != currentUserId)
            .length);
  }

  /// Stream daftar chat room untuk murid (berdasarkan studentId)
  Stream<QuerySnapshot<Map<String, dynamic>>> getStudentChatRooms({
    required String schoolId,
    required String studentId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('chats')
        .where('studentId', isEqualTo: studentId)
        .snapshots();
  }
}
