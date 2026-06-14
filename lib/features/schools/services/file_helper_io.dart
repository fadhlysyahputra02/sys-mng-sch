import 'dart:io';
import 'dart:typed_data';

Uint8List readBytes(String path) {
  return File(path).readAsBytesSync();
}

Future<void> writeBytes(String path, List<int> bytes) async {
  final file = File(path);
  await file.writeAsBytes(bytes);
}

bool isMobile() {
  return Platform.isAndroid || Platform.isIOS;
}
