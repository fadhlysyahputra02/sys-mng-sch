import 'dart:typed_data';
import 'file_helper_stub.dart'
    if (dart.library.io) 'file_helper_io.dart'
    if (dart.library.js_interop) 'file_helper_web.dart' as loader;

class FileHelper {
  static Uint8List readBytes(String path) {
    return loader.readBytes(path);
  }

  static Future<void> writeBytes(String path, List<int> bytes) async {
    await loader.writeBytes(path, bytes);
  }

  static bool isMobile() {
    return loader.isMobile();
  }
}
