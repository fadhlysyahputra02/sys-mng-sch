import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBXTJ4_RwuWZD5zfx83giule2NJ_bG9hnA',
    appId: '1:585358866296:web:05e4946fdbdcf7fd983a8d',
    messagingSenderId: '585358866296',
    projectId: 'sys-mng-sch',
    authDomain: 'sys-mng-sch.firebaseapp.com',
    storageBucket: 'sys-mng-sch.firebasestorage.app',
    measurementId: 'G-SH8ZBDCSMF',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBVg8ELe9zzbndS6PoeDJZpK44zQcJKHMU',
    appId: '1:585358866296:android:6d23273e2e3a33ac983a8d',
    messagingSenderId: '585358866296',
    projectId: 'sys-mng-sch',
    storageBucket: 'sys-mng-sch.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAA9zLLIo99z-E7nawcrvAjKuXMPeLYzjo',
    appId: '1:585358866296:ios:56290014792d23ac983a8d',
    messagingSenderId: '585358866296',
    projectId: 'sys-mng-sch',
    storageBucket: 'sys-mng-sch.firebasestorage.app',
    iosBundleId: 'com.sysmngsch.sysMngSchool',
  );
}
