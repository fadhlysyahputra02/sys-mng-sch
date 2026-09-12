import 'dart:math';

/// Utility function to generate a Firestore Document ID formatted as:
/// `<namalengkap>|<4 kode acak yang terdiri dari angka dan huruf campuran>`
String generateFormattedDocId(String namaLengkap) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random();
  final randomCode = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
  final cleanName = namaLengkap.trim().replaceAll('/', '-');
  return '$cleanName|$randomCode';
}
