import '../models/user_model.dart';

class SessionService {
  static UserModel? currentUser;

  static bool get isLoggedIn => currentUser != null;

  static void clear() {
    currentUser = null;
  }
}
