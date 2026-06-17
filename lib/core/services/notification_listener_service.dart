import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'session_service.dart';
import 'package:sys_mng_school/features/students/data/student_service.dart';
import 'package:sys_mng_school/features/schools/pages/teachers/data/teacher_service.dart';
import 'package:sys_mng_school/app/routes/app_routes.dart';

class NotificationListenerService {
  static final NotificationListenerService _instance = NotificationListenerService._internal();
  factory NotificationListenerService() => _instance;
  NotificationListenerService._internal();

  StreamSubscription? _subscription;
  DateTime? _listenerStartTime;
  final Set<String> _shownNotificationIds = {};

  // Info untuk filtering
  String? _teacherDocId;
  Set<String> _teacherClassIds = {};
  String? _studentClassId;
  String? _studentNama;

  Future<void> startListening() async {
    // 1. Hentikan listener yang ada jika sedang berjalan
    stopListening();

    final user = SessionService.currentUser;
    if (user == null) return;

    final schoolId = user.schoolId;
    _listenerStartTime = DateTime.now();

    debugPrint('NotificationListenerService: Mulai mendengarkan untuk UID: ${user.uid}, Role: ${user.role}');

    // 2. Ambil data pendukung filter sesuai role
    try {
      if (user.role == 'teacher') {
        final teacherDoc = await TeacherService().getTeacherByUid(schoolId, user.uid);
        if (teacherDoc != null) {
          _teacherDocId = teacherDoc.data()['teacherId'] ?? teacherDoc.id;

          // Ambil daftar kelas yang diajar oleh guru ini
          final schedulesSnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('class_schedules')
              .where('teacherId', isEqualTo: _teacherDocId)
              .get();
          final scheduleClassIds = schedulesSnap.docs
              .map((d) => d.data()['classId'] as String?)
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
              .toSet();

          // Ambil daftar kelas wali kelas
          final waliKelasSnap = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('classes')
              .where('teacherId', isEqualTo: _teacherDocId)
              .get();
          final waliClassIds = waliKelasSnap.docs.map((d) => d.id).toSet();

          _teacherClassIds = {...scheduleClassIds, ...waliClassIds};
        }
      } else if (user.role == 'student') {
        final studentDoc = await StudentService().getStudentDocByUid(schoolId, user.uid);
        if (studentDoc != null) {
          final data = studentDoc.data();
          if (data != null) {
            _studentClassId = data['classId'] as String?;
            _studentNama = data['nama'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationListenerService: Error loading filters: $e');
    }

    // 3. Mulai listen ke Firestore collection notifications
    _subscription = FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('notifications')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final doc = change.doc;
          final docId = doc.id;
          final data = doc.data();

          if (data == null) continue;
          if (_shownNotificationIds.contains(docId)) continue;

          // Check timestamp untuk memastikan itu notifikasi baru yang masuk
          // setelah listener berjalan
          final timestamp = (data['createdAt'] as Timestamp?)?.toDate();
          if (timestamp != null && _listenerStartTime != null) {
            if (timestamp.isBefore(_listenerStartTime!)) {
              // Notifikasi lama, abaikan
              continue;
            }
          }

          // Filter penerima
          final targetType = data['targetType'] ?? '';
          final targetId = data['targetId'] ?? '';
          final targetClassId = data['targetClassId'] ?? '';
          final targetName = data['targetName'] ?? '';
          final senderId = data['senderId'] ?? '';

          // Jangan tampilkan notifikasi yang dikirim oleh diri sendiri
          if (senderId == user.uid) {
            continue;
          }

          bool isRecipient = false;

          if (user.role == 'super_admin' || user.role == 'school_admin') {
            isRecipient = true;
          } else if (user.role == 'teacher') {
            if (targetType == 'umum') {
              isRecipient = true;
            } else if (targetType == 'kelas' && _teacherClassIds.contains(targetId)) {
              isRecipient = true;
            } else if (targetType == 'guru' && (targetId == '' || targetId == _teacherDocId)) {
              isRecipient = true;
            } else if (targetType == 'murid' && _teacherClassIds.contains(targetClassId)) {
              isRecipient = true;
            }
          } else if (user.role == 'student') {
            if (targetType == 'umum') {
              isRecipient = true;
            } else if (targetType == 'kelas' && _studentClassId != null && targetId == _studentClassId) {
              isRecipient = true;
            } else if (targetType == 'murid' && _studentNama != null && targetName == _studentNama) {
              isRecipient = true;
            }
          }

          if (isRecipient) {
            _shownNotificationIds.add(docId);
            _showNotificationBanner(
              docId: docId,
              title: data['title'] ?? 'Notifikasi Baru',
              content: data['content'] ?? '',
              senderName: data['senderName'] ?? 'Sistem',
              targetType: targetType,
            );
          }
        }
      }
    }, onError: (e) {
      debugPrint('NotificationListenerService: Firestore subscription error: $e');
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _listenerStartTime = null;
    _shownNotificationIds.clear();
    _teacherDocId = null;
    _teacherClassIds.clear();
    _studentClassId = null;
    _studentNama = null;
    debugPrint('NotificationListenerService: Berhenti mendengarkan');
  }

  void _showNotificationBanner({
    required String docId,
    required String title,
    required String content,
    required String senderName,
    required String targetType,
  }) {
    Color accentColor = const Color(0xFF8B5CF6); // Indigo untuk umum
    IconData iconData = Icons.campaign_rounded;

    if (targetType == 'kelas') {
      accentColor = const Color(0xFFF59E0B); // Amber
      iconData = Icons.class_rounded;
    } else if (targetType == 'guru') {
      accentColor = const Color(0xFF0EA5E9); // Sky
      iconData = Icons.person_rounded;
    } else if (targetType == 'murid') {
      accentColor = const Color(0xFF10B981); // Emerald
      iconData = Icons.school_rounded;
    }

    final context = Get.context;
    final isDark = context != null ? Theme.of(context).brightness == Brightness.dark : false;

    final bgColor = isDark 
        ? const Color(0xFF1E1B4B).withOpacity(0.9) 
        : Colors.white.withOpacity(0.9);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
    final contentColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.8);

    Get.snackbar(
      title,
      content,
      snackPosition: SnackPosition.TOP,
      backgroundColor: bgColor,
      colorText: titleColor,
      messageText: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: contentColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 12, color: accentColor),
              const SizedBox(width: 4),
              Text(
                'Dari: $senderName',
                style: TextStyle(
                  fontSize: 10,
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
      icon: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(iconData, color: accentColor, size: 22),
      ),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      borderColor: accentColor.withOpacity(0.3),
      borderWidth: 1.5,
      duration: const Duration(seconds: 5),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      barBlur: 20, // Premium glass effect
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) {
            Get.back();
          }
          Get.toNamed(AppRoutes.notifications);
        },
        child: Text(
          'LIHAT',
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
