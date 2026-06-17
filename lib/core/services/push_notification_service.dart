import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import 'session_service.dart';
import 'package:sys_mng_school/features/students/data/student_service.dart';
import 'package:sys_mng_school/features/schools/pages/teachers/data/teacher_service.dart';

// Helper platform-safe: gunakan defaultTargetPlatform (tidak pakai dart:io Platform)
// sehingga aman dijalankan di Flutter Web.
bool _platformIsIOS() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS;
}

bool _platformIsAndroid() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // 1. Inisialisasi local notifications untuk foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        Get.toNamed(AppRoutes.notifications);
      },
    );

    // 2. Setup Android Notification Channel dengan importance tinggi
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 3. Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM Foreground message received: ${message.messageId}');
      
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && !kIsWeb) {
        _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
    });

    // 4. Handle clicks ketika aplikasi di background/terbuka dari push
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM Notification clicked: ${message.messageId}');
      Get.toNamed(AppRoutes.notifications);
    });

    // 5. Handle clicks ketika aplikasi mati (terminated)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM App opened from terminated state by notification click: ${initialMessage.messageId}');
      Future.delayed(const Duration(milliseconds: 1000), () {
        Get.toNamed(AppRoutes.notifications);
      });
    }

    _initialized = true;
  }

  Future<void> registerUserDevice() async {
    if (kIsWeb) return;
    final user = SessionService.currentUser;
    if (user == null) return;

    // iOS Simulator tidak mendukung APNS/push notification asli.
    // Skip registrasi token agar tidak terjadi error berulang.
    if (_platformIsIOS() && kDebugMode) {
      try {
        // Coba dapatkan APNS token dulu, kalau null berarti ini simulator
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('PushNotificationService: Berjalan di iOS Simulator, skip registrasi FCM token.');
          // Tetap minta izin notifikasi agar tidak error
          await _firebaseMessaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );
          return;
        }
      } catch (_) {
        debugPrint('PushNotificationService: iOS Simulator terdeteksi, skip registrasi FCM token.');
        return;
      }
    }

    try {
      // 1. Meminta izin notifikasi (diperlukan untuk iOS dan Android 13+)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notifications permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('User granted provisional notifications permission');
      } else {
        debugPrint('User declined notifications permission');
        return;
      }

      // 2. Dapatkan token perangkat
      //    Pada iOS fisik, tunggu sebentar agar APNS token tersedia
      String? token;
      if (_platformIsIOS()) {
        await Future.delayed(const Duration(seconds: 3));
        token = await _firebaseMessaging.getToken();
      } else {
        token = await _firebaseMessaging.getToken();
      }

      if (token != null) {
        debugPrint('FCM Token: $token');
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .doc(token)
            .set({
          'token': token,
          'platform': kIsWeb ? 'Web' : (_platformIsAndroid() ? 'Android' : (_platformIsIOS() ? 'iOS' : 'Unknown')),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 3. Subscribe ke Topik Umum
        final schoolId = user.schoolId;
        await _firebaseMessaging.subscribeToTopic('school_${schoolId}_umum');
        await _firebaseMessaging.subscribeToTopic('school_${schoolId}_role_${user.role}');

        // 4. Subscribe ke Topik Spesifik
        if (user.role == 'student') {
          final studentDoc = await StudentService().getStudentDocByUid(schoolId, user.uid);
          if (studentDoc != null && studentDoc.exists) {
            final classId = studentDoc.data()?['classId'] as String?;
            if (classId != null && classId.isNotEmpty) {
              await _firebaseMessaging.subscribeToTopic('school_${schoolId}_class_$classId');
            }
          }
        } else if (user.role == 'teacher') {
          final teacherDoc = await TeacherService().getTeacherByUid(schoolId, user.uid);
          if (teacherDoc != null) {
            final teacherId = teacherDoc.data()['teacherId'] ?? teacherDoc.id;
            
            // Ambil daftar kelas yang diajar oleh guru ini
            final schedulesSnap = await FirebaseFirestore.instance
                .collection('schools')
                .doc(schoolId)
                .collection('class_schedules')
                .where('teacherId', isEqualTo: teacherId)
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
                .where('teacherId', isEqualTo: teacherId)
                .get();
            final waliClassIds = waliKelasSnap.docs.map((d) => d.id).toSet();

            final allClassIds = {...scheduleClassIds, ...waliClassIds};
            for (final classId in allClassIds) {
              await _firebaseMessaging.subscribeToTopic('school_${schoolId}_class_$classId');
            }
          }
        }
        
        debugPrint('PushNotificationService: Sukses mendaftar token & topic.');
      } else {
        debugPrint('PushNotificationService: FCM token null, skip registrasi.');
      }
    } catch (e) {
      debugPrint('PushNotificationService: Error registering device: $e');
    }
  }

  Future<void> unregisterUserDevice() async {
    if (kIsWeb) return;
    final user = SessionService.currentUser;
    if (user == null) return;

    // iOS Simulator tidak punya token, skip
    if (_platformIsIOS() && kDebugMode) {
      try {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('PushNotificationService: iOS Simulator, skip unregister.');
          return;
        }
      } catch (_) {
        return;
      }
    }

    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .doc(token)
            .delete();
        
        final schoolId = user.schoolId;
        await _firebaseMessaging.unsubscribeFromTopic('school_${schoolId}_umum');
        await _firebaseMessaging.unsubscribeFromTopic('school_${schoolId}_role_${user.role}');
        
        if (user.role == 'student') {
          final studentDoc = await StudentService().getStudentDocByUid(schoolId, user.uid);
          if (studentDoc != null && studentDoc.exists) {
            final classId = studentDoc.data()?['classId'] as String?;
            if (classId != null && classId.isNotEmpty) {
              await _firebaseMessaging.unsubscribeFromTopic('school_${schoolId}_class_$classId');
            }
          }
        }
        
        debugPrint('PushNotificationService: Sukses unregister token & topic.');
      }
    } catch (e) {
      debugPrint('PushNotificationService: Error unregistering device: $e');
    }
  }
}
