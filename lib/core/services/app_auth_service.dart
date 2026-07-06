import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/routes/app_routes.dart';
import 'auth_service.dart';
import 'session_service.dart';
import 'notification_listener_service.dart';
import 'push_notification_service.dart';

class AppAuthService {
  static Future<void> logout() async {
    try {
      final user = SessionService.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        if (user.email.isNotEmpty) {
          await prefs.setString('last_logged_in_email', user.email);
        }
        if (user.schoolId.isNotEmpty) {
          await prefs.setString('last_school_id', user.schoolId);
          // Ambil nama sekolah dari Firestore untuk disimpan di cache
          try {
            final schoolDoc = await FirebaseFirestore.instance
                .collection('schools')
                .doc(user.schoolId)
                .get();
            if (schoolDoc.exists) {
              final schoolName = schoolDoc.data()?['namaSekolah'] as String?;
              if (schoolName != null && schoolName.isNotEmpty) {
                await prefs.setString('last_school_name', schoolName);
              }
            }
          } catch (se) {
            debugPrint('Error fetching school name during logout: $se');
          }
        } else {
          // Jika tidak ada schoolId (seperti super_admin), bersihkan cache sekolah
          await prefs.remove('last_school_id');
          await prefs.remove('last_school_name');
        }
      }
    } catch (e) {
      debugPrint('Error saving email/school during logout: $e');
    }

    // Hapus registrasi token push notification dari Firestore & topik
    await PushNotificationService().unregisterUserDevice();

    // Berhenti mendengarkan notifikasi real-time
    NotificationListenerService().stopListening();

    await AuthService().logout();

    SessionService.logout();

    Get.offAllNamed(AppRoutes.login);
  }
}
