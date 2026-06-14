import 'dart:typed_data';

Uint8List readBytes(String path) {
  throw UnsupportedError('Cannot read bytes from path on web.');
}

Future<void> writeBytes(String path, List<int> bytes) async {
  // On web, the browser's download/saving is handled by FilePicker.saveFile itself
}

bool isMobile() {
  return false;
}
