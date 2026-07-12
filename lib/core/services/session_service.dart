import '../models/user_model.dart';
import 'semester_state_service.dart';

class SessionService {
  static UserModel? currentUser;
  static bool isTakingExam = false;

  static bool get isLoggedIn => currentUser != null;

  static void logout() {
    currentUser = null;
    isTakingExam = false;
    SemesterStateService.dispose();
  }
}
