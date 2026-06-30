import '../models/user_model.dart';
import 'semester_state_service.dart';

class SessionService {
  static UserModel? currentUser;

  static bool get isLoggedIn => currentUser != null;

  static void logout() {
    currentUser = null;
    SemesterStateService.dispose();
  }
}
