import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/localization/app_localization.dart';
import '../../../../authentication/widgets/auth_background.dart';
import '../../../../teachers/services/rapor_service.dart';
import '../models/rapor_pdf_settings.dart';

class AdminRaporSettingsPage extends StatefulWidget {
  final String schoolId;
  final String defaultSchoolName;

  const AdminRaporSettingsPage({
    super.key,
    required this.schoolId,
    required this.defaultSchoolName,
  });

  @override
  State<AdminRaporSettingsPage> createState() => _AdminRaporSettingsPageState();
}

class _AdminRaporSettingsPageState extends State<AdminRaporSettingsPage> {
  final _raporService = RaporService();
  bool _isLoading = true;
  bool _isSaving = false;

  late RaporPdfSettings _settings;
  String _schoolTahunAjaran = '';
  String _schoolSemester = '';

  Uint8List? get _logoLeftBytes {
    if (_settings.logoLeftBase64 == null) return null;
    if (_lastLogoLeftBase64 != _settings.logoLeftBase64) {
      _lastLogoLeftBase64 = _settings.logoLeftBase64;
      _logoLeftBytesCache = base64Decode(_settings.logoLeftBase64!);
    }
    return _logoLeftBytesCache;
  }
  Uint8List? _logoLeftBytesCache;
  String? _lastLogoLeftBase64;

  Uint8List? get _logoRightBytes {
    if (_settings.logoRightBase64 == null) return null;
    if (_lastLogoRightBase64 != _settings.logoRightBase64) {
      _lastLogoRightBase64 = _settings.logoRightBase64;
      _logoRightBytesCache = base64Decode(_settings.logoRightBase64!);
    }
    return _logoRightBytesCache;
  }
  Uint8List? _logoRightBytesCache;
  String? _lastLogoRightBase64;

  final GlobalKey _a4CanvasKey = GlobalKey();

  Offset? _dragStartPos;
  int? _dragStartGridX;
  int? _dragStartGridY;
  int? _dragStartGridW;

  double? _tempLeft;
  double? _tempTop;
  double? _tempWidth;

  String? _hoveredId;
  String? _draggingId;
  bool _isResizing = false;
  double _currentScale = 1.0;
  double _zoomFactor = 1.0;

  // Controllers
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _kepsekNameController = TextEditingController();
  final _kepsekNipController = TextEditingController();

  final List<Map<String, String>> _colorThemes = [
    {'name': 'Indigo (Default)', 'primary': '#1E1B4B', 'secondary': '#4B5563'},
    {'name': 'Teal Ocean', 'primary': '#0F766E', 'secondary': '#0D9488'},
    {'name': 'Emerald Forest', 'primary': '#065F46', 'secondary': '#10B981'},
    {'name': 'Slate Classic', 'primary': '#1E293B', 'secondary': '#64748B'},
    {'name': 'Royal Blue', 'primary': '#1E40AF', 'secondary': '#3B82F6'},
    {'name': 'Deep Crimson', 'primary': '#9F1239', 'secondary': '#F43F5E'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _schoolNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _kepsekNameController.dispose();
    _kepsekNipController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final snap = await _raporService.getRaporPdfSettings(widget.schoolId);
      if (snap.exists && snap.data() != null) {
        var loadedSettings = RaporPdfSettings.fromMap(snap.data()!, widget.defaultSchoolName);
        final positions = Map<String, List<int>>.from(loadedSettings.elementPositions);
        final int oldKopHeight = positions['kop'] != null ? positions['kop']![3] : 6;
        final int oldInfoStart = positions['info'] != null ? positions['info']![1] : 7;

        if (oldKopHeight < 8 || oldInfoStart < 9) {
          positions['kop'] = [0, 0, 12, 8];
          positions['info'] = [0, 9, 12, 3];
          positions['attitude'] = [0, 14, 12, 5];
          positions['academic'] = [0, 20, 12, 11];
          positions['legend'] = [0, 32, 5, 11];
          positions['attendance'] = [6, 32, 6, 5];
          positions['notes'] = [6, 38, 6, 5];
          positions['signatures'] = [0, 44, 12, 6];
          
          loadedSettings = loadedSettings.copyWith(elementPositions: positions);
        }
        _settings = loadedSettings;
      } else {
        _settings = RaporPdfSettings.defaultSettings(widget.defaultSchoolName);
      }

      // Fetch school info
      final schoolSnap = await FirebaseFirestore.instance.collection('schools').doc(widget.schoolId).get();
      if (schoolSnap.exists && schoolSnap.data() != null) {
        final schoolData = schoolSnap.data()!;
        _schoolTahunAjaran = schoolData['tahunAjaran']?.toString() ?? '${DateTime.now().year}/${DateTime.now().year + 1}';
        _schoolSemester = schoolData['semester']?.toString() ?? 'Semester 1';
      } else {
        _schoolTahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
        _schoolSemester = 'Semester 1';
      }

      // Initialize controllers
      _titleController.text = _settings.headerTitle;
      _subtitleController.text = _settings.headerSubtitle;
      _schoolNameController.text = _settings.schoolName;
      _addressController.text = _settings.schoolAddress;
      _phoneController.text = _settings.schoolPhone;
      _kepsekNameController.text = _settings.kepsekName;
      _kepsekNipController.text = _settings.kepsekNip;
    } catch (e) {
      _showSnack('Gagal memuat pengaturan: $e');
      _settings = RaporPdfSettings.defaultSettings(widget.defaultSchoolName);
      _schoolTahunAjaran = '${DateTime.now().year}/${DateTime.now().year + 1}';
      _schoolSemester = 'Semester 1';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickLogo({required bool isLeft}) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 75,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        setState(() {
          if (isLeft) {
            _settings = RaporPdfSettings(
              headerTitle: _titleController.text,
              headerSubtitle: _subtitleController.text,
              schoolName: _schoolNameController.text,
              schoolAddress: _addressController.text,
              schoolPhone: _phoneController.text,
              logoLeftBase64: base64String,
              logoRightBase64: _settings.logoRightBase64,
              showLogoLeft: _settings.showLogoLeft,
              showLogoRight: _settings.showLogoRight,
              showWatermark: _settings.showWatermark,
              showSpiritualAttitude: _settings.showSpiritualAttitude,
              showPredikat: _settings.showPredikat,
              showAttendance: _settings.showAttendance,
              showNotes: _settings.showNotes,
              kepsekName: _kepsekNameController.text,
              kepsekNip: _kepsekNipController.text,
              ttdKepsekPosition: _settings.ttdKepsekPosition,
              ttdWaliPosition: _settings.ttdWaliPosition,
              ttdOrtuPosition: _settings.ttdOrtuPosition,
              fontSize: _settings.fontSize,
              primaryColorHex: _settings.primaryColorHex,
              secondaryColorHex: _settings.secondaryColorHex,
            );
          } else {
            _settings = RaporPdfSettings(
              headerTitle: _titleController.text,
              headerSubtitle: _subtitleController.text,
              schoolName: _schoolNameController.text,
              schoolAddress: _addressController.text,
              schoolPhone: _phoneController.text,
              logoLeftBase64: _settings.logoLeftBase64,
              logoRightBase64: base64String,
              showLogoLeft: _settings.showLogoLeft,
              showLogoRight: _settings.showLogoRight,
              showWatermark: _settings.showWatermark,
              showSpiritualAttitude: _settings.showSpiritualAttitude,
              showPredikat: _settings.showPredikat,
              showAttendance: _settings.showAttendance,
              showNotes: _settings.showNotes,
              kepsekName: _kepsekNameController.text,
              kepsekNip: _kepsekNipController.text,
              ttdKepsekPosition: _settings.ttdKepsekPosition,
              ttdWaliPosition: _settings.ttdWaliPosition,
              ttdOrtuPosition: _settings.ttdOrtuPosition,
              fontSize: _settings.fontSize,
              primaryColorHex: _settings.primaryColorHex,
              secondaryColorHex: _settings.secondaryColorHex,
            );
          }
        });
      }
    } catch (e) {
      _showSnack('Gagal memilih logo: $e');
    }
  }

  void _removeLogo({required bool isLeft}) {
    setState(() {
      _settings = RaporPdfSettings(
        headerTitle: _titleController.text,
        headerSubtitle: _subtitleController.text,
        schoolName: _schoolNameController.text,
        schoolAddress: _addressController.text,
        schoolPhone: _phoneController.text,
        logoLeftBase64: isLeft ? null : _settings.logoLeftBase64,
        logoRightBase64: isLeft ? _settings.logoRightBase64 : null,
        showLogoLeft: _settings.showLogoLeft,
        showLogoRight: _settings.showLogoRight,
        showWatermark: _settings.showWatermark,
        showSpiritualAttitude: _settings.showSpiritualAttitude,
        showPredikat: _settings.showPredikat,
        showAttendance: _settings.showAttendance,
        showNotes: _settings.showNotes,
        kepsekName: _kepsekNameController.text,
        kepsekNip: _kepsekNipController.text,
        ttdKepsekPosition: _settings.ttdKepsekPosition,
        ttdWaliPosition: _settings.ttdWaliPosition,
        ttdOrtuPosition: _settings.ttdOrtuPosition,
        fontSize: _settings.fontSize,
        primaryColorHex: _settings.primaryColorHex,
        secondaryColorHex: _settings.secondaryColorHex,
      );
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final updatedSettings = _settings.copyWith(
        headerTitle: _titleController.text.trim(),
        headerSubtitle: _subtitleController.text.trim(),
        schoolName: _schoolNameController.text.trim(),
        schoolAddress: _addressController.text.trim(),
        schoolPhone: _phoneController.text.trim(),
        kepsekName: _kepsekNameController.text.trim(),
        kepsekNip: _kepsekNipController.text.trim(),
      );

      await _raporService.saveRaporPdfSettings(widget.schoolId, updatedSettings.toMap());
      _showSnack(AppLocalization.isIndonesian ? 'Pengaturan berhasil disimpan!' : 'Settings saved successfully!', isSuccess: true);
      Get.back();
    } catch (e) {
      _showSnack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _parseHexColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF1E1B4B); // Default
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthBackground.isDarkMode,
      builder: (context, isDark, _) {
        final titleColor = isDark ? Colors.white : const Color(0xFF1E1B4B);
        final subTextColor = isDark ? Colors.white70 : const Color(0xFF1E1B4B).withOpacity(0.7);
        final cardBgColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
        final cardBorderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);
        final inputFillColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);


        return Scaffold(
          body: AuthBackground(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                    child: Column(
                      children: [
                        // Appbar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          key: const Key('appbar_header'),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalization.isIndonesian ? 'Kustomisasi Template PDF' : 'PDF Template Customization',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor),
                                ),
                              ),
                              if (_isSaving)
                                const CircularProgressIndicator()
                              else
                                TextButton.icon(
                                  onPressed: _saveSettings,
                                  icon: const Icon(Icons.save_rounded, color: Colors.green),
                                  label: Text(
                                    AppLocalization.isIndonesian ? 'Simpan' : 'Save',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Main Content
                        Expanded(
                          child: SingleChildScrollView(
                            physics: _draggingId != null
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildPreviewSection(isDark, cardBgColor, cardBorderColor),
                                const SizedBox(height: 24),
                                _buildHeaderSection(isDark, cardBgColor, cardBorderColor, inputFillColor, titleColor, subTextColor),
                                const SizedBox(height: 20),
                                _buildLogoSection(isDark, cardBgColor, cardBorderColor, titleColor, subTextColor),
                                const SizedBox(height: 20),
                                _buildLayoutSection(isDark, cardBgColor, cardBorderColor, titleColor, subTextColor),
                                const SizedBox(height: 20),
                                _buildSignatureSection(isDark, cardBgColor, cardBorderColor, inputFillColor, titleColor, subTextColor),
                                const SizedBox(height: 20),
                                _buildStyleSection(isDark, cardBgColor, cardBorderColor, titleColor, subTextColor),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // 1. Live Layout Preview
  Widget _buildPreviewSection(bool isDark, Color cardBg, Color cardBorder) {
    final primaryColor = _parseHexColor(_settings.primaryColorHex);
    final secondaryColor = _parseHexColor(_settings.secondaryColorHex);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, color: Color(0xFF3B82F6), size: 16),
              const SizedBox(width: 8),
              Text(
                AppLocalization.isIndonesian
                    ? 'Preview Tata Letak Rapor (Miniatur A4)'
                    : 'Report Layout Preview (A4 Miniature)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const double a4W = 794.0;
              const double a4H = 1123.0;
              final double fitScale = constraints.maxWidth / a4W;
              final double scale = fitScale * _zoomFactor;
              final double scaledW = a4W * scale;
              final double scaledH = a4H * scale;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _currentScale != scale) {
                  setState(() {
                    _currentScale = scale;
                  });
                }
              });

              return Column(
                children: [
                  Container(
                    height: 550, // Fixed height viewport!
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cardBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            alignment: Alignment.center,
                            width: scaledW > constraints.maxWidth ? scaledW : constraints.maxWidth,
                            height: scaledH > 550 ? scaledH : 550,
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: scaledW,
                                  height: scaledH,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.08),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.fill,
                                    child: SizedBox(
                                      width: a4W,
                                      height: a4H,
                                      child: _buildA4Content(primaryColor, secondaryColor),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Zoom / Scaling Controls below the preview sheet (now fully stationary!)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 18),
                    onPressed: _zoomFactor > 0.5
                        ? () => setState(() => _zoomFactor = (_zoomFactor - 0.1).clamp(0.5, 1.5))
                        : null,
                    tooltip: 'Zoom Out',
                  ),
                  SizedBox(
                    width: 150,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: _zoomFactor,
                        min: 0.5,
                        max: 1.5,
                        divisions: 10,
                        onChanged: (val) {
                          setState(() {
                            _zoomFactor = val;
                          });
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 18),
                    onPressed: _zoomFactor < 1.5
                        ? () => setState(() => _zoomFactor = (_zoomFactor + 0.1).clamp(0.5, 1.5))
                        : null,
                    tooltip: 'Zoom In',
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_zoomFactor * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _zoomFactor = 1.0),
                    child: const Text('Fit', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildA4Content(Color primaryColor, Color secondaryColor) {
    final Map<String, Widget> sections = {
      'kop': Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_settings.showLogoLeft)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _logoLeftBytes != null
                      ? Image.memory(_logoLeftBytes!,
                          width: 60, height: 60, fit: BoxFit.contain)
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Icon(Icons.account_balance, color: primaryColor.withValues(alpha: 0.4), size: 32),
                        ),
                )
              else
                const SizedBox(width: 60),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _titleController.text.isEmpty
                          ? 'PEMERINTAH KOTA MALANG'
                          : _titleController.text.toUpperCase(),
                      style: TextStyle(
                        fontSize: _settings.titleFontSize.toDouble(),
                        fontWeight: _settings.titleIsBold ? FontWeight.bold : FontWeight.normal,
                        color: primaryColor.withValues(alpha: _settings.titleOpacity),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_subtitleController.text.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _subtitleController.text.toUpperCase(),
                        style: TextStyle(
                          fontSize: _settings.subtitleFontSize.toDouble(),
                          fontWeight: _settings.subtitleIsBold ? FontWeight.bold : FontWeight.normal,
                          color: primaryColor.withValues(alpha: _settings.subtitleOpacity),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _schoolNameController.text.isEmpty
                          ? 'NAMA SEKOLAH'
                          : _schoolNameController.text.toUpperCase(),
                      style: TextStyle(
                        fontSize: _settings.schoolNameFontSize.toDouble(),
                        fontWeight: _settings.schoolNameIsBold ? FontWeight.bold : FontWeight.normal,
                        color: primaryColor.withValues(alpha: _settings.schoolNameOpacity),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_addressController.text.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _addressController.text,
                        style: TextStyle(
                          fontSize: _settings.addressFontSize.toDouble(),
                          fontWeight: _settings.addressIsBold ? FontWeight.bold : FontWeight.normal,
                          color: primaryColor.withValues(alpha: _settings.addressOpacity),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_phoneController.text.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _phoneController.text,
                        style: TextStyle(
                          fontSize: _settings.phoneFontSize.toDouble(),
                          fontWeight: _settings.phoneIsBold ? FontWeight.bold : FontWeight.normal,
                          color: primaryColor.withValues(alpha: _settings.phoneOpacity),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              if (_settings.showLogoRight)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _logoRightBytes != null
                      ? Image.memory(_logoRightBytes!,
                          width: 60, height: 60, fit: BoxFit.contain)
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                          ),
                          child: Icon(Icons.school, color: primaryColor.withValues(alpha: 0.4), size: 32),
                        ),
                )
              else
                const SizedBox(width: 60),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 2, color: primaryColor),
          Container(height: 0.5, color: primaryColor.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'LAPORAN PENILAIAN HASIL BELAJAR SISWA\n(SEMESTER ${_schoolSemester.toUpperCase()} TAHUN AJARAN $_schoolTahunAjaran)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      'info': Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _previewInfoRow('Nama Siswa', 'Fadhly Syahputra'),
          _previewInfoRow('NISN / NIS', '202110370311419 / 1419'),
          _previewInfoRow('Kelas', 'X IPA 1'),
          _previewInfoRow('Sekolah', _schoolNameController.text.isEmpty ? 'NAMA SEKOLAH' : _schoolNameController.text),
        ],
      ),
      'attitude': Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _previewSectionHeader('A. PENILAIAN SIKAP', primaryColor),
          const SizedBox(height: 4),
          _previewTable(
            headers: const ['Aspek Sikap', 'Predikat', 'Deskripsi / Keterangan'],
            rows: const [
              ['Spiritual', 'B', 'Menunjukkan sikap spiritual yang baik.'],
              ['Sosial', 'B', 'Menunjukkan sikap sosial yang baik.'],
            ],
            primaryColor: primaryColor,
            colFlex: const [2, 1, 4],
          ),
        ],
      ),
      'academic': Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _previewSectionHeader('B. PENILAIAN AKADEMIK', primaryColor),
          const SizedBox(height: 4),
          _buildResizablePreviewTable(
            headers: const ['No', 'Mata Pelajaran', 'KKM', 'Nilai', 'Predikat', 'Deskripsi Pencapaian'],
            rows: const [
              ['1', 'Bahasa Indonesia', '75', '82', 'B', 'Sudah baik dalam memahami teks.'],
              ['2', 'Matematika', '75', '78', 'B', 'Memahami konsep dasar dengan baik.'],
              ['3', 'Bahasa Inggris', '75', '80', 'B', 'Mampu berkomunikasi dengan baik.'],
              ['4', 'Fisika', '75', '76', 'C', 'Perlu peningkatan di beberapa bagian.'],
              ['5', 'Biologi', '75', '85', 'A', 'Sangat baik dalam memahami materi.'],
            ],
            primaryColor: primaryColor,
            widths: _settings.academicColWidths,
            onWidthsChanged: (newWidths) {
              setState(() {
                _settings = _settings.copyWith(academicColWidths: newWidths);
              });
            },
          ),
        ],
      ),
      'legend': Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _previewSectionHeader('KETERANGAN PREDIKAT', primaryColor),
          const SizedBox(height: 4),
          _buildResizablePreviewTable(
            headers: const ['Rentang Nilai', 'Predikat'],
            rows: const [
              ['95 - 100', 'A+'],
              ['90 - 94', 'A'],
              ['85 - 89', 'A-'],
              ['80 - 84', 'B+'],
              ['75 - 79', 'B'],
              ['70 - 74', 'B-'],
              ['65 - 69', 'C+'],
              ['60 - 64', 'C'],
              ['55 - 59', 'C-'],
              ['< 55', 'D'],
            ],
            primaryColor: primaryColor,
            widths: _settings.legendColWidths,
            onWidthsChanged: (newWidths) {
              setState(() {
                _settings = _settings.copyWith(legendColWidths: newWidths);
              });
            },
          ),
        ],
      ),
      'attendance': Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _previewSectionHeader('C. KETIDAKHADIRAN', primaryColor),
          const SizedBox(height: 4),
          _buildResizablePreviewTable(
            headers: const ['Alasan Absensi', 'Jumlah'],
            rows: const [
              ['1. Sakit (S)', '0 hari'],
              ['2. Izin (I)', '0 hari'],
              ['3. Tanpa Keterangan (A)', '0 hari'],
            ],
            primaryColor: primaryColor,
            widths: _settings.attendanceColWidths,
            onWidthsChanged: (newWidths) {
              setState(() {
                _settings = _settings.copyWith(attendanceColWidths: newWidths);
              });
            },
          ),
        ],
      ),
      'notes': Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _previewSectionHeader('D. CATATAN WALI KELAS', primaryColor),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            height: 60,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Siswa menunjukkan perkembangan yang baik. Terus semangat dalam belajar!',
              style: TextStyle(fontSize: 8, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
      'signatures': Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_settings.ttdOrtuPosition != 'none')
            _previewSignatureCol('Orang Tua/Wali Murid,', '', '')
          else
            const SizedBox(),
          if (_settings.ttdWaliPosition != 'none')
            _previewSignatureCol('Wali Kelas,', 'Ahmad Fauzan, S.Pd', '')
          else
            const SizedBox(),
          if (_settings.ttdKepsekPosition != 'none')
            _previewSignatureCol(
              'Kepala Sekolah,',
              _kepsekNameController.text.isNotEmpty ? _kepsekNameController.text : 'Dra. Hj. Siti Aminah, M.Pd',
              _kepsekNipController.text.isNotEmpty ? 'NIP. ${_kepsekNipController.text}' : 'NIP. 196504151990032001',
            )
          else
            const SizedBox(),
        ],
      ),
    };

    return Container(
      key: _a4CanvasKey,
      width: 794,
      height: 1123,
      color: Colors.white,
      child: Stack(
        children: [
          // Watermark
          if (_settings.showWatermark && _logoRightBytes != null)
            Positioned.fill(
              child: Center(
                child: Opacity(
                  opacity: 0.06,
                  child: Image.memory(
                    _logoRightBytes!,
                    width: 350,
                    height: 350,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

          // Grid background guidelines while dragging
          if (_draggingId != null) _buildGridBackground(),

          // Render sections absolutely
          _buildGridElement('kop', sections['kop']!, isVisible: true),
          _buildGridElement('info', sections['info']!, isVisible: true),
          _buildGridElement('attitude', sections['attitude']!, isVisible: _settings.showSpiritualAttitude),
          _buildGridElement('academic', sections['academic']!, isVisible: true),
          _buildGridElement('legend', sections['legend']!, isVisible: _settings.showPredikat),
          _buildGridElement('attendance', sections['attendance']!, isVisible: _settings.showAttendance),
          _buildGridElement('notes', sections['notes']!, isVisible: _settings.showNotes),
          _buildGridElement('signatures', sections['signatures']!, isVisible: true),
        ],
      ),
    );
  }

  Widget _previewInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.black54)),
          ),
          const Text(':', style: TextStyle(fontSize: 9, color: Colors.black54)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _previewSectionHeader(String title, Color primaryColor) {
    return Row(
      children: [
        Container(width: 3, height: 14, color: primaryColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: primaryColor),
        ),
      ],
    );
  }

  Widget _previewTable({
    required List<String> headers,
    required List<List<String>> rows,
    required Color primaryColor,
    required List<int> colFlex,
  }) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      columnWidths: {
        for (int i = 0; i < colFlex.length; i++)
          i: FlexColumnWidth(colFlex[i].toDouble()),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08)),
          children: headers
              .map(
                (h) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    h,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: primaryColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
        // Data rows
        ...rows.map(
          (row) => TableRow(
            children: row
                .map(
                  (cell) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Text(
                      cell,
                      style: const TextStyle(fontSize: 8, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _previewSignatureCol(String title, String name, String nip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Malang, ${DateTime.now().day} Juli ${DateTime.now().year}',
          style: const TextStyle(fontSize: 8, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(title,
            style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        const SizedBox(height: 48),
        Container(
          width: 120,
          height: 0.5,
          color: Colors.black54,
        ),
        const SizedBox(height: 3),
        Text(
          name,
          style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        if (nip.isNotEmpty)
          Text(nip,
              style: const TextStyle(fontSize: 7.5, color: Colors.black54)),
      ],
    );
  }

  void _onElementDrag(String id, Offset currentLocalPos) {
    if (_dragStartPos == null || _dragStartGridX == null || _dragStartGridY == null) return;

    final double colWidth = 682.0 / 12.0;
    const double rowHeight = 15.0;

    final double deltaX = currentLocalPos.dx - _dragStartPos!.dx;
    final double deltaY = currentLocalPos.dy - _dragStartPos!.dy;

    final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
    final int w = currentPos[2];
    final int h = currentPos[3];

    final double startLeft = 56.0 + _dragStartGridX! * colWidth;
    final double startTop = 40.0 + _dragStartGridY! * rowHeight;

    setState(() {
      _tempLeft = (startLeft + deltaX).clamp(56.0, 56.0 + (12 - w) * colWidth);
      _tempTop = (startTop + deltaY).clamp(40.0, 40.0 + (70 - h) * rowHeight);
    });
  }

  void _onElementResize(String id, Offset currentLocalPos) {
    if (_dragStartPos == null || _dragStartGridW == null) return;

    final double colWidth = 682.0 / 12.0;

    final double deltaX = currentLocalPos.dx - _dragStartPos!.dx;
    final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
    final int startCol = currentPos[0];

    final double startWidth = _dragStartGridW! * colWidth;

    setState(() {
      _tempWidth = (startWidth + deltaX).clamp(colWidth, (12 - startCol) * colWidth);
    });
  }

  Widget _buildGridBackground() {
    final double colWidth = 682.0 / 12.0;
    const double rowHeight = 15.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 40, 56, 40),
          child: Stack(
            children: [
              for (int i = 1; i < 12; i++)
                Positioned(
                  left: i * colWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 0.5,
                    color: Colors.blue.withValues(alpha: 0.15),
                  ),
                ),
              for (int i = 1; i < 70; i++)
                Positioned(
                  left: 0,
                  right: 0,
                  top: i * rowHeight,
                  child: Container(
                    height: 0.5,
                    color: Colors.blue.withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridElement(String id, Widget child, {required bool isVisible}) {
    if (!isVisible) return const SizedBox();

    final pos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
    final int gridX = pos[0];
    final int gridY = pos[1];
    final int gridW = pos[2];

    final double colWidth = 682.0 / 12.0;
    const double rowHeight = 15.0;

    // Use fluid temporary pixel coordinates during dragging
    final double left = (_draggingId == id && !_isResizing)
        ? (_tempLeft ?? (56.0 + gridX * colWidth))
        : (56.0 + gridX * colWidth);

    final double top = (_draggingId == id && !_isResizing)
        ? (_tempTop ?? (40.0 + gridY * rowHeight))
        : (40.0 + gridY * rowHeight);

    final double width = (_draggingId == id && _isResizing)
        ? (_tempWidth ?? (gridW * colWidth))
        : (gridW * colWidth);

    final isDraggingThis = _draggingId == id;

    return Positioned(
      left: left - 24,
      top: top - 24,
      width: width + 48,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoveredId = id),
        onExit: (_) => setState(() => _hoveredId = null),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Element body draggable detector
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  final RenderBox? renderBox = _a4CanvasKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final canvasGlobalPos = renderBox.localToGlobal(Offset.zero);
                    final localPos = Offset(
                      (details.globalPosition.dx - canvasGlobalPos.dx) / _currentScale,
                      (details.globalPosition.dy - canvasGlobalPos.dy) / _currentScale,
                    );
                    final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
                    setState(() {
                      _draggingId = id;
                      _isResizing = false;
                      _dragStartPos = localPos;
                      _dragStartGridX = currentPos[0];
                      _dragStartGridY = currentPos[1];
                      _tempLeft = 56.0 + currentPos[0] * colWidth;
                      _tempTop = 40.0 + currentPos[1] * rowHeight;
                    });
                  }
                },
                onPanUpdate: (details) {
                  final RenderBox? renderBox = _a4CanvasKey.currentContext?.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final canvasGlobalPos = renderBox.localToGlobal(Offset.zero);
                    final localPos = Offset(
                      (details.globalPosition.dx - canvasGlobalPos.dx) / _currentScale,
                      (details.globalPosition.dy - canvasGlobalPos.dy) / _currentScale,
                    );
                    _onElementDrag(id, localPos);
                  }
                },
                onPanEnd: (_) {
                  if (_tempLeft == null || _tempTop == null) return;
                  final snapGridX = ((_tempLeft! - 56.0) / colWidth).round();
                  final snapGridY = ((_tempTop! - 40.0) / rowHeight).round();

                  final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
                  final int w = currentPos[2];
                  final int h = currentPos[3];

                  final updatedPositions = Map<String, List<int>>.from(_settings.elementPositions);
                  updatedPositions[id] = [
                    snapGridX.clamp(0, 12 - w),
                    snapGridY.clamp(0, 70 - h),
                    w,
                    h
                  ];

                  setState(() {
                    _settings = _settings.copyWith(elementPositions: updatedPositions);
                    _draggingId = null;
                    _dragStartPos = null;
                    _dragStartGridX = null;
                    _dragStartGridY = null;
                    _tempLeft = null;
                    _tempTop = null;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDraggingThis
                          ? Colors.blue.shade500
                          : (_hoveredId == id ? Colors.blue.shade300 : Colors.transparent),
                      width: 1.5,
                    ),
                    color: isDraggingThis ? Colors.blue.shade50.withValues(alpha: 0.15) : Colors.transparent,
                  ),
                  child: child,
                ),
              ),
              if (_hoveredId == id || isDraggingThis)
                Positioned(
                  top: -16,
                  left: -16,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (details) {
                        final RenderBox? renderBox = _a4CanvasKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox != null) {
                          final canvasGlobalPos = renderBox.localToGlobal(Offset.zero);
                          final localPos = Offset(
                            (details.position.dx - canvasGlobalPos.dx) / _currentScale,
                            (details.position.dy - canvasGlobalPos.dy) / _currentScale,
                          );
                          final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
                          setState(() {
                            _draggingId = id;
                            _isResizing = false;
                            _dragStartPos = localPos;
                            _dragStartGridX = currentPos[0];
                            _dragStartGridY = currentPos[1];
                            _tempLeft = 56.0 + currentPos[0] * colWidth;
                            _tempTop = 40.0 + currentPos[1] * rowHeight;
                          });
                        }
                      },
                      onPointerMove: (details) {
                        final RenderBox? renderBox = _a4CanvasKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox != null) {
                          final canvasGlobalPos = renderBox.localToGlobal(Offset.zero);
                          final localPos = Offset(
                            (details.position.dx - canvasGlobalPos.dx) / _currentScale,
                            (details.position.dy - canvasGlobalPos.dy) / _currentScale,
                          );
                          _onElementDrag(id, localPos);
                        }
                      },
                      onPointerUp: (details) {
                        if (_tempLeft == null || _tempTop == null) return;
                        final snapGridX = ((_tempLeft! - 56.0) / colWidth).round();
                        final snapGridY = ((_tempTop! - 40.0) / rowHeight).round();

                        final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
                        final int w = currentPos[2];
                        final int h = currentPos[3];

                        final updatedPositions = Map<String, List<int>>.from(_settings.elementPositions);
                        updatedPositions[id] = [
                          snapGridX.clamp(0, 12 - w),
                          snapGridY.clamp(0, 70 - h),
                          w,
                          h
                        ];

                        setState(() {
                          _settings = _settings.copyWith(elementPositions: updatedPositions);
                          _draggingId = null;
                          _dragStartPos = null;
                          _dragStartGridX = null;
                          _dragStartGridY = null;
                          _tempLeft = null;
                          _tempTop = null;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.open_with, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (_hoveredId == id || isDraggingThis)
                Positioned(
                  right: -16,
                  top: 0,
                  bottom: 0,
                  width: 32,
                  child: Align(
                    alignment: Alignment.center,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (details) {
                          final RenderBox? renderBox = _a4CanvasKey.currentContext?.findRenderObject() as RenderBox?;
                          if (renderBox != null) {
                            final canvasGlobalPos = renderBox.localToGlobal(Offset.zero);
                            final localPos = Offset(
                              (details.position.dx - canvasGlobalPos.dx) / _currentScale,
                              (details.position.dy - canvasGlobalPos.dy) / _currentScale,
                            );
                            final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
                            setState(() {
                              _draggingId = id;
                              _isResizing = true;
                              _dragStartPos = localPos;
                              _dragStartGridW = currentPos[2];
                              _tempWidth = currentPos[2] * colWidth;
                            });
                          }
                        },
                        onPointerMove: (details) {
                          final RenderBox? renderBox = _a4CanvasKey.currentContext?.findRenderObject() as RenderBox?;
                          if (renderBox != null) {
                            final canvasGlobalPos = renderBox.localToGlobal(Offset.zero);
                            final localPos = Offset(
                              (details.position.dx - canvasGlobalPos.dx) / _currentScale,
                              (details.position.dy - canvasGlobalPos.dy) / _currentScale,
                            );
                            _onElementResize(id, localPos);
                          }
                        },
                        onPointerUp: (details) {
                          if (_tempWidth == null) return;
                          final snapGridW = (_tempWidth! / colWidth).round();

                          final currentPos = _settings.elementPositions[id] ?? [0, 0, 12, 5];
                          final int startCol = currentPos[0];
                          final int row = currentPos[1];
                          final int h = currentPos[3];

                          final updatedPositions = Map<String, List<int>>.from(_settings.elementPositions);
                          updatedPositions[id] = [
                            startCol,
                            row,
                            snapGridW.clamp(1, 12 - startCol),
                            h
                          ];

                          setState(() {
                            _settings = _settings.copyWith(elementPositions: updatedPositions);
                            _draggingId = null;
                            _isResizing = false;
                            _dragStartPos = null;
                            _dragStartGridW = null;
                            _tempWidth = null;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.swap_horiz, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResizablePreviewTable({
    required List<String> headers,
    required List<List<String>> rows,
    required Color primaryColor,
    required List<double> widths,
    required ValueChanged<List<double>> onWidthsChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: primaryColor.withValues(alpha: 0.08),
                child: Row(
                  children: List.generate(headers.length * 2 - 1, (index) {
                    if (index.isOdd) {
                      final colIndex = index ~/ 2;
                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (details) {
                          if (totalWidth > 0) {
                            final double dw = details.primaryDelta! / totalWidth;
                            final newWidths = List<double>.from(widths);
                            final double leftVal = newWidths[colIndex];
                            final double rightVal = newWidths[colIndex + 1];
                            newWidths[colIndex] = (leftVal + dw).clamp(0.04, 0.9);
                            newWidths[colIndex + 1] = (rightVal - dw).clamp(0.04, 0.9);
                            final double sum = newWidths.reduce((a, b) => a + b);
                            for (int k = 0; k < newWidths.length; k++) {
                              newWidths[k] /= sum;
                            }
                            onWidthsChanged(newWidths);
                          }
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeLeftRight,
                          child: Container(
                            width: 12,
                            height: 18,
                            alignment: Alignment.center,
                            child: Container(
                              width: 1.5,
                              height: 10,
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    } else {
                      final colIndex = index ~/ 2;
                      final w = widths[colIndex];
                      return Expanded(
                        flex: (w * 10000).round(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          alignment: Alignment.center,
                          child: Text(
                            headers[colIndex],
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }
                  }),
                ),
              ),
              const Divider(height: 0.5, thickness: 0.5, color: Colors.grey),
              ...rows.map((row) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: List.generate(row.length * 2 - 1, (index) {
                      if (index.isOdd) {
                        return Container(
                          width: 12,
                          alignment: Alignment.center,
                          child: Container(
                            width: 0.5,
                            height: 14,
                            color: Colors.grey.shade300,
                          ),
                        );
                      } else {
                        final colIndex = index ~/ 2;
                        final w = widths[colIndex];
                        return Expanded(
                          flex: (w * 10000).round(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                            alignment: Alignment.center,
                            child: Text(
                              row[colIndex],
                              style: const TextStyle(fontSize: 8, color: Colors.black87),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }
                    }),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // 2. Header / Kop Surat Section
  Widget _buildHeaderSection(bool isDark, Color cardBg, Color cardBorder, Color inputFill, Color titleColor, Color subText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalization.isIndonesian ? 'Informasi Kop Surat (Header)' : 'Letterhead (Header) Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _titleController,
            label: AppLocalization.isIndonesian ? 'Judul Rapor' : 'Report Title',
            hint: 'LAPORAN HASIL BELAJAR (RAPOR)',
            inputFill: inputFill,
            titleColor: titleColor,
            subText: subText,
          ),
          _buildFieldStyleSettings(
            label: AppLocalization.isIndonesian ? 'Judul' : 'Title',
            fontSize: _settings.titleFontSize,
            opacity: _settings.titleOpacity,
            isBold: _settings.titleIsBold,
            onFontSizeChanged: (val) => setState(() => _settings = _settings.copyWith(titleFontSize: val)),
            onOpacityChanged: (val) => setState(() => _settings = _settings.copyWith(titleOpacity: val)),
            onBoldChanged: (val) => setState(() => _settings = _settings.copyWith(titleIsBold: val)),
            titleColor: titleColor,
            subText: subText,
          ),
          _buildTextField(
            controller: _subtitleController,
            label: AppLocalization.isIndonesian ? 'Sub-Judul / Instansi Atas' : 'Subtitle / Top Institution',
            hint: 'DINAS PENDIDIKAN PROVINSI JAWA BARAT',
            inputFill: inputFill,
            titleColor: titleColor,
            subText: subText,
          ),
          _buildFieldStyleSettings(
            label: AppLocalization.isIndonesian ? 'Sub-Judul' : 'Subtitle',
            fontSize: _settings.subtitleFontSize,
            opacity: _settings.subtitleOpacity,
            isBold: _settings.subtitleIsBold,
            onFontSizeChanged: (val) => setState(() => _settings = _settings.copyWith(subtitleFontSize: val)),
            onOpacityChanged: (val) => setState(() => _settings = _settings.copyWith(subtitleOpacity: val)),
            onBoldChanged: (val) => setState(() => _settings = _settings.copyWith(subtitleIsBold: val)),
            titleColor: titleColor,
            subText: subText,
          ),
          _buildTextField(
            controller: _schoolNameController,
            label: AppLocalization.isIndonesian ? 'Nama Sekolah (Custom)' : 'School Name (Custom)',
            hint: widget.defaultSchoolName,
            inputFill: inputFill,
            titleColor: titleColor,
            subText: subText,
          ),
          _buildFieldStyleSettings(
            label: AppLocalization.isIndonesian ? 'Nama Sekolah' : 'School Name',
            fontSize: _settings.schoolNameFontSize,
            opacity: _settings.schoolNameOpacity,
            isBold: _settings.schoolNameIsBold,
            onFontSizeChanged: (val) => setState(() => _settings = _settings.copyWith(schoolNameFontSize: val)),
            onOpacityChanged: (val) => setState(() => _settings = _settings.copyWith(schoolNameOpacity: val)),
            onBoldChanged: (val) => setState(() => _settings = _settings.copyWith(schoolNameIsBold: val)),
            titleColor: titleColor,
            subText: subText,
          ),
          _buildTextField(
            controller: _addressController,
            label: AppLocalization.isIndonesian ? 'Alamat Sekolah' : 'School Address',
            hint: 'Jl. Merdeka No. 45, Bandung',
            inputFill: inputFill,
            titleColor: titleColor,
            subText: subText,
          ),
          _buildFieldStyleSettings(
            label: AppLocalization.isIndonesian ? 'Alamat' : 'Address',
            fontSize: _settings.addressFontSize,
            opacity: _settings.addressOpacity,
            isBold: _settings.addressIsBold,
            onFontSizeChanged: (val) => setState(() => _settings = _settings.copyWith(addressFontSize: val)),
            onOpacityChanged: (val) => setState(() => _settings = _settings.copyWith(addressOpacity: val)),
            onBoldChanged: (val) => setState(() => _settings = _settings.copyWith(addressIsBold: val)),
            titleColor: titleColor,
            subText: subText,
          ),
          _buildTextField(
            controller: _phoneController,
            label: AppLocalization.isIndonesian ? 'Telepon / Website Sekolah' : 'School Phone / Website',
            hint: '(022) 123456 / www.sekolah.sch.id',
            inputFill: inputFill,
            titleColor: titleColor,
            subText: subText,
          ),
          _buildFieldStyleSettings(
            label: AppLocalization.isIndonesian ? 'Telepon' : 'Phone',
            fontSize: _settings.phoneFontSize,
            opacity: _settings.phoneOpacity,
            isBold: _settings.phoneIsBold,
            onFontSizeChanged: (val) => setState(() => _settings = _settings.copyWith(phoneFontSize: val)),
            onOpacityChanged: (val) => setState(() => _settings = _settings.copyWith(phoneOpacity: val)),
            onBoldChanged: (val) => setState(() => _settings = _settings.copyWith(phoneIsBold: val)),
            titleColor: titleColor,
            subText: subText,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldStyleSettings({
    required String label,
    required int fontSize,
    required double opacity,
    required bool isBold,
    required ValueChanged<int> onFontSizeChanged,
    required ValueChanged<double> onOpacityChanged,
    required ValueChanged<bool> onBoldChanged,
    required Color titleColor,
    required Color subText,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalization.isIndonesian ? 'Gaya: $label' : 'Style: $label',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subText),
              ),
              Row(
                children: [
                  Text(
                    AppLocalization.isIndonesian ? 'Tebal (Bold)' : 'Bold',
                    style: TextStyle(fontSize: 11, color: subText),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: isBold,
                      activeColor: Colors.purple.shade400,
                      onChanged: onBoldChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.isIndonesian
                          ? 'Ukuran Font: $fontSize pt'
                          : 'Font Size: $fontSize pt',
                      style: TextStyle(fontSize: 11, color: subText),
                    ),
                    Slider(
                      value: fontSize.toDouble(),
                      min: 6,
                      max: 24,
                      divisions: 18,
                      activeColor: Colors.purple.shade400,
                      inactiveColor: Colors.purple.shade100,
                      onChanged: (val) => onFontSizeChanged(val.toInt()),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.isIndonesian
                          ? 'Opasitas: ${(opacity * 100).round()}%'
                          : 'Opacity: ${(opacity * 100).round()}%',
                      style: TextStyle(fontSize: 11, color: subText),
                    ),
                    Slider(
                      value: opacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      activeColor: Colors.purple.shade400,
                      inactiveColor: Colors.purple.shade100,
                      onChanged: onOpacityChanged,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Logo Upload/Configuration Section
  Widget _buildLogoSection(bool isDark, Color cardBg, Color cardBorder, Color titleColor, Color subText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalization.isIndonesian ? 'Pengaturan Logo' : 'Logo Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Logo Kiri
          _buildLogoUploadRow(
            title: AppLocalization.isIndonesian ? 'Logo Kiri (Dinas/Pemda)' : 'Left Logo (Government)',
            showLogo: _settings.showLogoLeft,
            logoBase64: _settings.logoLeftBase64,
            onToggle: (val) {
              setState(() {
                _settings = RaporPdfSettings(
                  headerTitle: _titleController.text,
                  headerSubtitle: _subtitleController.text,
                  schoolName: _schoolNameController.text,
                  schoolAddress: _addressController.text,
                  schoolPhone: _phoneController.text,
                  logoLeftBase64: _settings.logoLeftBase64,
                  logoRightBase64: _settings.logoRightBase64,
                  showLogoLeft: val,
                  showLogoRight: _settings.showLogoRight,
                  showWatermark: _settings.showWatermark,
                  showSpiritualAttitude: _settings.showSpiritualAttitude,
                  showPredikat: _settings.showPredikat,
                  showAttendance: _settings.showAttendance,
                  showNotes: _settings.showNotes,
                  kepsekName: _kepsekNameController.text,
                  kepsekNip: _kepsekNipController.text,
                  ttdKepsekPosition: _settings.ttdKepsekPosition,
                  ttdWaliPosition: _settings.ttdWaliPosition,
                  ttdOrtuPosition: _settings.ttdOrtuPosition,
                  fontSize: _settings.fontSize,
                  primaryColorHex: _settings.primaryColorHex,
                  secondaryColorHex: _settings.secondaryColorHex,
                );
              });
            },
            onPick: () => _pickLogo(isLeft: true),
            onRemove: () => _removeLogo(isLeft: true),
            isDark: isDark,
          ),
          const Divider(height: 24),
          // Logo Kanan
          _buildLogoUploadRow(
            title: AppLocalization.isIndonesian ? 'Logo Kanan (Sekolah)' : 'Right Logo (School)',
            showLogo: _settings.showLogoRight,
            logoBase64: _settings.logoRightBase64,
            onToggle: (val) {
              setState(() {
                _settings = RaporPdfSettings(
                  headerTitle: _titleController.text,
                  headerSubtitle: _subtitleController.text,
                  schoolName: _schoolNameController.text,
                  schoolAddress: _addressController.text,
                  schoolPhone: _phoneController.text,
                  logoLeftBase64: _settings.logoLeftBase64,
                  logoRightBase64: _settings.logoRightBase64,
                  showLogoLeft: _settings.showLogoLeft,
                  showLogoRight: val,
                  showWatermark: _settings.showWatermark,
                  showSpiritualAttitude: _settings.showSpiritualAttitude,
                  showPredikat: _settings.showPredikat,
                  showAttendance: _settings.showAttendance,
                  showNotes: _settings.showNotes,
                  kepsekName: _kepsekNameController.text,
                  kepsekNip: _kepsekNipController.text,
                  ttdKepsekPosition: _settings.ttdKepsekPosition,
                  ttdWaliPosition: _settings.ttdWaliPosition,
                  ttdOrtuPosition: _settings.ttdOrtuPosition,
                  fontSize: _settings.fontSize,
                  primaryColorHex: _settings.primaryColorHex,
                  secondaryColorHex: _settings.secondaryColorHex,
                );
              });
            },
            onPick: () => _pickLogo(isLeft: false),
            onRemove: () => _removeLogo(isLeft: false),
            isDark: isDark,
          ),
          const Divider(height: 24),
          // Watermark
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalization.isIndonesian ? 'Gunakan Watermark Background' : 'Use Background Watermark',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalization.isIndonesian ? 'Menampilkan bayangan logo sekolah di tengah halaman PDF.' : 'Display faint school logo in the center of the PDF page.',
                      style: TextStyle(fontSize: 11, color: subText),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _settings.showWatermark,
                onChanged: (val) {
                  setState(() {
                    _settings = RaporPdfSettings(
                      headerTitle: _titleController.text,
                      headerSubtitle: _subtitleController.text,
                      schoolName: _schoolNameController.text,
                      schoolAddress: _addressController.text,
                      schoolPhone: _phoneController.text,
                      logoLeftBase64: _settings.logoLeftBase64,
                      logoRightBase64: _settings.logoRightBase64,
                      showLogoLeft: _settings.showLogoLeft,
                      showLogoRight: _settings.showLogoRight,
                      showWatermark: val,
                      showSpiritualAttitude: _settings.showSpiritualAttitude,
                      showPredikat: _settings.showPredikat,
                      showAttendance: _settings.showAttendance,
                      showNotes: _settings.showNotes,
                      kepsekName: _kepsekNameController.text,
                      kepsekNip: _kepsekNipController.text,
                      ttdKepsekPosition: _settings.ttdKepsekPosition,
                      ttdWaliPosition: _settings.ttdWaliPosition,
                      ttdOrtuPosition: _settings.ttdOrtuPosition,
                      fontSize: _settings.fontSize,
                      primaryColorHex: _settings.primaryColorHex,
                      secondaryColorHex: _settings.secondaryColorHex,
                    );
                  });
                },
                activeColor: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoUploadRow({
    required String title,
    required bool showLogo,
    required String? logoBase64,
    required ValueChanged<bool> onToggle,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Switch(
                    value: showLogo,
                    onChanged: onToggle,
                    activeColor: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    showLogo
                        ? (AppLocalization.isIndonesian ? 'Ditampilkan' : 'Visible')
                        : (AppLocalization.isIndonesian ? 'Disembunyikan' : 'Hidden'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showLogo)
          Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: logoBase64 != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(base64Decode(logoBase64), fit: BoxFit.contain),
                      )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.file_upload, size: 18, color: Colors.blue),
                    onPressed: onPick,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  if (logoBase64 != null)
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: onRemove,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                ],
              )
            ],
          ),
      ],
    );
  }

  // 4. Layout Toggles Section
  Widget _buildLayoutSection(bool isDark, Color cardBg, Color cardBorder, Color titleColor, Color subText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_rounded, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalization.isIndonesian ? 'Tampilkan Bagian Dokumen' : 'Document Section Toggles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildToggleRow(
            title: AppLocalization.isIndonesian ? 'Tabel Sikap Spiritual (Bagian A.1)' : 'Spiritual Attitude Table (Part A.1)',
            value: _settings.showSpiritualAttitude,
            onChanged: (val) {
              setState(() {
                _settings = RaporPdfSettings(
                  headerTitle: _titleController.text,
                  headerSubtitle: _subtitleController.text,
                  schoolName: _schoolNameController.text,
                  schoolAddress: _addressController.text,
                  schoolPhone: _phoneController.text,
                  logoLeftBase64: _settings.logoLeftBase64,
                  logoRightBase64: _settings.logoRightBase64,
                  showLogoLeft: _settings.showLogoLeft,
                  showLogoRight: _settings.showLogoRight,
                  showWatermark: _settings.showWatermark,
                  showSpiritualAttitude: val,
                  showPredikat: _settings.showPredikat,
                  showAttendance: _settings.showAttendance,
                  showNotes: _settings.showNotes,
                  kepsekName: _kepsekNameController.text,
                  kepsekNip: _kepsekNipController.text,
                  ttdKepsekPosition: _settings.ttdKepsekPosition,
                  ttdWaliPosition: _settings.ttdWaliPosition,
                  ttdOrtuPosition: _settings.ttdOrtuPosition,
                  fontSize: _settings.fontSize,
                  primaryColorHex: _settings.primaryColorHex,
                  secondaryColorHex: _settings.secondaryColorHex,
                );
              });
            },
          ),
          const Divider(),
          _buildToggleRow(
            title: AppLocalization.isIndonesian ? 'Tampilkan Keterangan Predikat Nilai' : 'Show Grade Predicate Legend',
            value: _settings.showPredikat,
            onChanged: (val) {
              setState(() {
                _settings = RaporPdfSettings(
                  headerTitle: _titleController.text,
                  headerSubtitle: _subtitleController.text,
                  schoolName: _schoolNameController.text,
                  schoolAddress: _addressController.text,
                  schoolPhone: _phoneController.text,
                  logoLeftBase64: _settings.logoLeftBase64,
                  logoRightBase64: _settings.logoRightBase64,
                  showLogoLeft: _settings.showLogoLeft,
                  showLogoRight: _settings.showLogoRight,
                  showWatermark: _settings.showWatermark,
                  showSpiritualAttitude: _settings.showSpiritualAttitude,
                  showPredikat: val,
                  showAttendance: _settings.showAttendance,
                  showNotes: _settings.showNotes,
                  kepsekName: _kepsekNameController.text,
                  kepsekNip: _kepsekNipController.text,
                  ttdKepsekPosition: _settings.ttdKepsekPosition,
                  ttdWaliPosition: _settings.ttdWaliPosition,
                  ttdOrtuPosition: _settings.ttdOrtuPosition,
                  fontSize: _settings.fontSize,
                  primaryColorHex: _settings.primaryColorHex,
                  secondaryColorHex: _settings.secondaryColorHex,
                );
              });
            },
          ),
          const Divider(),
          _buildToggleRow(
            title: AppLocalization.isIndonesian ? 'Rekap Absensi Ketidakhadiran (Bagian C)' : 'Attendance Recap (Part C)',
            value: _settings.showAttendance,
            onChanged: (val) {
              setState(() {
                _settings = RaporPdfSettings(
                  headerTitle: _titleController.text,
                  headerSubtitle: _subtitleController.text,
                  schoolName: _schoolNameController.text,
                  schoolAddress: _addressController.text,
                  schoolPhone: _phoneController.text,
                  logoLeftBase64: _settings.logoLeftBase64,
                  logoRightBase64: _settings.logoRightBase64,
                  showLogoLeft: _settings.showLogoLeft,
                  showLogoRight: _settings.showLogoRight,
                  showWatermark: _settings.showWatermark,
                  showSpiritualAttitude: _settings.showSpiritualAttitude,
                  showPredikat: _settings.showPredikat,
                  showAttendance: val,
                  showNotes: _settings.showNotes,
                  kepsekName: _kepsekNameController.text,
                  kepsekNip: _kepsekNipController.text,
                  ttdKepsekPosition: _settings.ttdKepsekPosition,
                  ttdWaliPosition: _settings.ttdWaliPosition,
                  ttdOrtuPosition: _settings.ttdOrtuPosition,
                  fontSize: _settings.fontSize,
                  primaryColorHex: _settings.primaryColorHex,
                  secondaryColorHex: _settings.secondaryColorHex,
                );
              });
            },
          ),
          const Divider(),
          _buildToggleRow(
            title: AppLocalization.isIndonesian ? 'Catatan Wali Kelas (Bagian D)' : 'Homeroom Teacher Notes (Part D)',
            value: _settings.showNotes,
            onChanged: (val) {
              setState(() {
                _settings = RaporPdfSettings(
                  headerTitle: _titleController.text,
                  headerSubtitle: _subtitleController.text,
                  schoolName: _schoolNameController.text,
                  schoolAddress: _addressController.text,
                  schoolPhone: _phoneController.text,
                  logoLeftBase64: _settings.logoLeftBase64,
                  logoRightBase64: _settings.logoRightBase64,
                  showLogoLeft: _settings.showLogoLeft,
                  showLogoRight: _settings.showLogoRight,
                  showWatermark: _settings.showWatermark,
                  showSpiritualAttitude: _settings.showSpiritualAttitude,
                  showPredikat: _settings.showPredikat,
                  showAttendance: _settings.showAttendance,
                  showNotes: val,
                  kepsekName: _kepsekNameController.text,
                  kepsekNip: _kepsekNipController.text,
                  ttdKepsekPosition: _settings.ttdKepsekPosition,
                  ttdWaliPosition: _settings.ttdWaliPosition,
                  ttdOrtuPosition: _settings.ttdOrtuPosition,
                  fontSize: _settings.fontSize,
                  primaryColorHex: _settings.primaryColorHex,
                  secondaryColorHex: _settings.secondaryColorHex,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  // 5. Signature Section
  Widget _buildSignatureSection(bool isDark, Color cardBg, Color cardBorder, Color inputFill, Color titleColor, Color subText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_ind_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalization.isIndonesian ? 'Tanda Tangan & Pejabat' : 'Signature & Officers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _kepsekNameController,
            label: AppLocalization.isIndonesian ? 'Nama Kepala Sekolah' : 'Headmaster Name',
            hint: 'Drs. H. Mulyadi, M.M.',
            inputFill: inputFill,
            titleColor: titleColor,
            subText: subText,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _kepsekNipController,
            label: AppLocalization.isIndonesian ? 'NIP Kepala Sekolah' : 'Headmaster NIP',
            hint: '19760512 200212 1 003',
            inputFill: inputFill,
            titleColor: titleColor,
            subText: subText,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            AppLocalization.isIndonesian ? 'Posisi Tanda Tangan' : 'Signature Positions',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildDropdownPosition(
            label: AppLocalization.isIndonesian ? 'Tanda Tangan Orang Tua' : 'Parent Signature',
            value: _settings.ttdOrtuPosition,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _settings = RaporPdfSettings(
                    headerTitle: _titleController.text,
                    headerSubtitle: _subtitleController.text,
                    schoolName: _schoolNameController.text,
                    schoolAddress: _addressController.text,
                    schoolPhone: _phoneController.text,
                    logoLeftBase64: _settings.logoLeftBase64,
                    logoRightBase64: _settings.logoRightBase64,
                    showLogoLeft: _settings.showLogoLeft,
                    showLogoRight: _settings.showLogoRight,
                    showWatermark: _settings.showWatermark,
                    showSpiritualAttitude: _settings.showSpiritualAttitude,
                    showPredikat: _settings.showPredikat,
                    showAttendance: _settings.showAttendance,
                    showNotes: _settings.showNotes,
                    kepsekName: _kepsekNameController.text,
                    kepsekNip: _kepsekNipController.text,
                    ttdKepsekPosition: _settings.ttdKepsekPosition,
                    ttdWaliPosition: _settings.ttdWaliPosition,
                    ttdOrtuPosition: val,
                    fontSize: _settings.fontSize,
                    primaryColorHex: _settings.primaryColorHex,
                    secondaryColorHex: _settings.secondaryColorHex,
                  );
                });
              }
            },
            inputFill: inputFill,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDropdownPosition(
            label: AppLocalization.isIndonesian ? 'Tanda Tangan Wali Kelas' : 'Homeroom Teacher Signature',
            value: _settings.ttdWaliPosition,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _settings = RaporPdfSettings(
                    headerTitle: _titleController.text,
                    headerSubtitle: _subtitleController.text,
                    schoolName: _schoolNameController.text,
                    schoolAddress: _addressController.text,
                    schoolPhone: _phoneController.text,
                    logoLeftBase64: _settings.logoLeftBase64,
                    logoRightBase64: _settings.logoRightBase64,
                    showLogoLeft: _settings.showLogoLeft,
                    showLogoRight: _settings.showLogoRight,
                    showWatermark: _settings.showWatermark,
                    showSpiritualAttitude: _settings.showSpiritualAttitude,
                    showPredikat: _settings.showPredikat,
                    showAttendance: _settings.showAttendance,
                    showNotes: _settings.showNotes,
                    kepsekName: _kepsekNameController.text,
                    kepsekNip: _kepsekNipController.text,
                    ttdKepsekPosition: _settings.ttdKepsekPosition,
                    ttdWaliPosition: val,
                    ttdOrtuPosition: _settings.ttdOrtuPosition,
                    fontSize: _settings.fontSize,
                    primaryColorHex: _settings.primaryColorHex,
                    secondaryColorHex: _settings.secondaryColorHex,
                  );
                });
              }
            },
            inputFill: inputFill,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildDropdownPosition(
            label: AppLocalization.isIndonesian ? 'Tanda Tangan Kepala Sekolah' : 'Headmaster Signature',
            value: _settings.ttdKepsekPosition,
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _settings = RaporPdfSettings(
                    headerTitle: _titleController.text,
                    headerSubtitle: _subtitleController.text,
                    schoolName: _schoolNameController.text,
                    schoolAddress: _addressController.text,
                    schoolPhone: _phoneController.text,
                    logoLeftBase64: _settings.logoLeftBase64,
                    logoRightBase64: _settings.logoRightBase64,
                    showLogoLeft: _settings.showLogoLeft,
                    showLogoRight: _settings.showLogoRight,
                    showWatermark: _settings.showWatermark,
                    showSpiritualAttitude: _settings.showSpiritualAttitude,
                    showPredikat: _settings.showPredikat,
                    showAttendance: _settings.showAttendance,
                    showNotes: _settings.showNotes,
                    kepsekName: _kepsekNameController.text,
                    kepsekNip: _kepsekNipController.text,
                    ttdKepsekPosition: val,
                    ttdWaliPosition: _settings.ttdWaliPosition,
                    ttdOrtuPosition: _settings.ttdOrtuPosition,
                    fontSize: _settings.fontSize,
                    primaryColorHex: _settings.primaryColorHex,
                    secondaryColorHex: _settings.secondaryColorHex,
                  );
                });
              }
            },
            inputFill: inputFill,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownPosition({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
    required Color inputFill,
    required bool isDark,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        fillColor: inputFill,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: const [
        DropdownMenuItem<String>(value: 'left', child: Text('Kiri (Left)')),
        DropdownMenuItem<String>(value: 'center', child: Text('Tengah (Center)')),
        DropdownMenuItem<String>(value: 'right', child: Text('Kanan (Right)')),
        DropdownMenuItem<String>(value: 'none', child: Text('Sembunyikan (Hide)')),
      ],
      onChanged: onChanged,
    );
  }

  // 6. Theme and Font styling Section
  Widget _buildStyleSection(bool isDark, Color cardBg, Color cardBorder, Color titleColor, Color subText) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_rounded, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalization.isIndonesian ? 'Gaya & Tema Warna PDF' : 'PDF Style & Theme',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tema Warna primer
          Text(
            AppLocalization.isIndonesian ? 'Tema Warna (Border & Judul)' : 'Color Theme (Borders & Headings)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _colorThemes.map((theme) {
              final isSelected = _settings.primaryColorHex.toLowerCase() == theme['primary']!.toLowerCase();
              final pColor = _parseHexColor(theme['primary']!);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _settings = RaporPdfSettings(
                      headerTitle: _titleController.text,
                      headerSubtitle: _subtitleController.text,
                      schoolName: _schoolNameController.text,
                      schoolAddress: _addressController.text,
                      schoolPhone: _phoneController.text,
                      logoLeftBase64: _settings.logoLeftBase64,
                      logoRightBase64: _settings.logoRightBase64,
                      showLogoLeft: _settings.showLogoLeft,
                      showLogoRight: _settings.showLogoRight,
                      showWatermark: _settings.showWatermark,
                      showSpiritualAttitude: _settings.showSpiritualAttitude,
                      showPredikat: _settings.showPredikat,
                      showAttendance: _settings.showAttendance,
                      showNotes: _settings.showNotes,
                      kepsekName: _kepsekNameController.text,
                      kepsekNip: _kepsekNipController.text,
                      ttdKepsekPosition: _settings.ttdKepsekPosition,
                      ttdWaliPosition: _settings.ttdWaliPosition,
                      ttdOrtuPosition: _settings.ttdOrtuPosition,
                      fontSize: _settings.fontSize,
                      primaryColorHex: theme['primary']!,
                      secondaryColorHex: theme['secondary']!,
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: pColor.withOpacity(0.1),
                    border: Border.all(
                      color: isSelected ? pColor : Colors.grey.withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: pColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        theme['name']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Ukuran Font
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalization.isIndonesian ? 'Ukuran Font Konten PDF' : 'PDF Content Font Size',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              DropdownButton<int>(
                value: _settings.fontSize,
                dropdownColor: isDark ? const Color(0xFF0F0C20) : Colors.white,
                items: [8, 9, 10, 11, 12].map((size) {
                  return DropdownMenuItem<int>(
                    value: size,
                    child: Text('$size pt'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _settings = RaporPdfSettings(
                        headerTitle: _titleController.text,
                        headerSubtitle: _subtitleController.text,
                        schoolName: _schoolNameController.text,
                        schoolAddress: _addressController.text,
                        schoolPhone: _phoneController.text,
                        logoLeftBase64: _settings.logoLeftBase64,
                        logoRightBase64: _settings.logoRightBase64,
                        showLogoLeft: _settings.showLogoLeft,
                        showLogoRight: _settings.showLogoRight,
                        showWatermark: _settings.showWatermark,
                        showSpiritualAttitude: _settings.showSpiritualAttitude,
                        showPredikat: _settings.showPredikat,
                        showAttendance: _settings.showAttendance,
                        showNotes: _settings.showNotes,
                        kepsekName: _kepsekNameController.text,
                        kepsekNip: _kepsekNipController.text,
                        ttdKepsekPosition: _settings.ttdKepsekPosition,
                        ttdWaliPosition: _settings.ttdWaliPosition,
                        ttdOrtuPosition: _settings.ttdOrtuPosition,
                        fontSize: val,
                        primaryColorHex: _settings.primaryColorHex,
                        secondaryColorHex: _settings.secondaryColorHex,
                      );
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color inputFill,
    required Color titleColor,
    required Color subText,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: titleColor, fontSize: 13),
      onChanged: (val) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subText, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: subText.withOpacity(0.5), fontSize: 12),
        fillColor: inputFill,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
