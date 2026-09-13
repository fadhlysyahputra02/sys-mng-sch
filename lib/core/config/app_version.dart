import 'package:flutter/material.dart';

/// Konfigurasi dan Widget terpusat untuk menampilkan Versi Aplikasi.
/// 
/// Ketika versi aplikasi berubah, cukup perbarui nilai `version` di file ini,
/// maka seluruh halaman yang menampilkan versi akan diperbarui secara otomatis.
class AppVersion {
  AppVersion._();

  /// Nomor versi aplikasi utama
  static const String version = '1.20.21';

  /// Nomor build aplikasi
  static const String buildNumber = '1';

  /// Format versi sederhana dengan awalan 'v' (contoh: "v1.20.21")
  static String get displayVersion => 'v$version';

  /// Format versi lengkap dengan nomor build (contoh: "v1.20.21+1")
  static String get fullVersion => 'v$version+$buildNumber';
}

/// Widget terpusat untuk menampilkan Teks Versi Aplikasi di halaman mana pun.
class AppVersionText extends StatelessWidget {
  final TextStyle? style;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? letterSpacing;
  final bool showPrefix;
  final bool showBuildNumber;

  const AppVersionText({
    super.key,
    this.style,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.letterSpacing,
    this.showPrefix = true,
    this.showBuildNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    String text;
    if (showBuildNumber) {
      text = AppVersion.fullVersion;
    } else if (showPrefix) {
      text = AppVersion.displayVersion;
    } else {
      text = AppVersion.version;
    }

    final defaultStyle = TextStyle(
      fontSize: fontSize ?? 12,
      color: color ?? Colors.white70,
      letterSpacing: letterSpacing ?? 1.5,
      fontWeight: fontWeight ?? FontWeight.w500,
    );

    return Text(
      text,
      style: style != null ? defaultStyle.merge(style) : defaultStyle,
    );
  }
}
