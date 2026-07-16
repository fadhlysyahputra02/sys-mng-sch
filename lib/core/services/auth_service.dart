import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _functions.httpsCallable('sendCustomResetPasswordEmail').call({
        'email': email,
      });
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Gagal mengirim email reset password.');
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  User? get currentUser => _auth.currentUser;
}
