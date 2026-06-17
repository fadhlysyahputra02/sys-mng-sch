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
      final email = SessionService.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_logged_in_email', email);
      }
    } catch (e) {
      debugPrint('Error saving email during logout: $e');
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
