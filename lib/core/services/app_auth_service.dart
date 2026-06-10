import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import 'auth_service.dart';
import 'session_service.dart';

class AppAuthService {
  static Future<void> logout() async {
    await AuthService().logout();

    SessionService.logout();

    Get.offAllNamed(AppRoutes.login);
  }
}
