import 'package:cloud_firestore/cloud_firestore.dart';

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
    required String senderRole, // 'teacher' atau 'student'
    required String message,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('chats')
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
        .collection('chats')
        .doc(chatRoomId)
        .set({
          'chatRoomId': chatRoomId,
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastSenderId': senderId,
          'lastSenderName': senderName,
        }, SetOptions(merge: true));
  }

  /// Stream pesan realtime
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages({
    required String schoolId,
    required String chatRoomId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('chats')
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
  }) async {
    final messages = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Hitung unread messages untuk satu chat room
  Stream<int> getUnreadCount({
    required String schoolId,
    required String chatRoomId,
    required String currentUserId,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: currentUserId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
