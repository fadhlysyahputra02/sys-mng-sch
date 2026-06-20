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
