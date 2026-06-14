import 'dart:typed_data';

Uint8List readBytes(String path) {
  throw UnsupportedError('Cannot read bytes on this platform.');
}

Future<void> writeBytes(String path, List<int> bytes) async {
  throw UnsupportedError('Cannot write bytes on this platform.');
}

bool isMobile() {
  return false;
}
