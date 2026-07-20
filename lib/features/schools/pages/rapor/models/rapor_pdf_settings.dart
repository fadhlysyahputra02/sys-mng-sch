class RaporPdfSettings {
  final String headerTitle;
  final String headerSubtitle;
  final String schoolName;
  final String schoolAddress;
  final String schoolPhone;
  final String? logoLeftBase64;
  final String? logoRightBase64;
  final bool showLogoLeft;
  final bool showLogoRight;
  final bool showWatermark;
  final bool showSpiritualAttitude;
  final bool showPredikat;
  final bool showAttendance;
  final bool showNotes;
  final String kepsekName;
  final String kepsekNip;

  // Independent signature element toggles
  final bool showSigOrtu;
  final bool showSigWali;
  final bool showSigKepsek;
  final bool showSigDate;

  // Custom date text prefix e.g. "Malang" (if empty, uses school city)
  final String sigDateText;

  final int fontSize;
  final String primaryColorHex;
  final String secondaryColorHex;

  final int titleFontSize;
  final double titleOpacity;
  final bool titleIsBold;

  final int subtitleFontSize;
  final double subtitleOpacity;
  final bool subtitleIsBold;

  final int schoolNameFontSize;
  final double schoolNameOpacity;
  final bool schoolNameIsBold;

  final int addressFontSize;
  final double addressOpacity;
  final bool addressIsBold;

  final int phoneFontSize;
  final double phoneOpacity;
  final bool phoneIsBold;

  final List<String> sectionOrder;
  final List<double> academicColWidths;
  final List<double> legendColWidths;
  final List<double> attendanceColWidths;
  final Map<String, List<int>> elementPositions;

  RaporPdfSettings({
    required this.headerTitle,
    required this.headerSubtitle,
    required this.schoolName,
    required this.schoolAddress,
    required this.schoolPhone,
    this.logoLeftBase64,
    this.logoRightBase64,
    required this.showLogoLeft,
    required this.showLogoRight,
    required this.showWatermark,
    required this.showSpiritualAttitude,
    required this.showPredikat,
    required this.showAttendance,
    required this.showNotes,
    required this.kepsekName,
    required this.kepsekNip,
    this.showSigOrtu = true,
    this.showSigWali = true,
    this.showSigKepsek = true,
    this.showSigDate = true,
    this.sigDateText = '',
    required this.fontSize,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    this.titleFontSize = 13,
    this.titleOpacity = 1.0,
    this.titleIsBold = true,
    this.subtitleFontSize = 10,
    this.subtitleOpacity = 1.0,
    this.subtitleIsBold = false,
    this.schoolNameFontSize = 11,
    this.schoolNameOpacity = 1.0,
    this.schoolNameIsBold = true,
    this.addressFontSize = 9,
    this.addressOpacity = 1.0,
    this.addressIsBold = false,
    this.phoneFontSize = 9,
    this.phoneOpacity = 1.0,
    this.phoneIsBold = false,
    this.sectionOrder = const ['kop', 'info', 'attitude', 'academic', 'bottom_row', 'signatures'],
    this.academicColWidths = const [0.05, 0.25, 0.1, 0.1, 0.1, 0.4],
    this.legendColWidths = const [0.6, 0.4],
    this.attendanceColWidths = const [0.7, 0.3],
    this.elementPositions = const {
      'kop': [0, 0, 12, 8],
      'info': [0, 9, 8, 4],
      'attitude': [0, 14, 12, 5],
      'academic': [0, 20, 12, 11],
      'legend': [0, 32, 5, 11],
      'attendance': [6, 32, 6, 5],
      'notes': [6, 38, 6, 5],
      'sig_date': [6, 44, 6, 2],
      'sig_ortu': [0, 46, 4, 5],
      'sig_wali': [4, 46, 4, 5],
      'sig_kepsek': [8, 46, 4, 5],
    },
  });

  factory RaporPdfSettings.defaultSettings(String defaultSchoolName) {
    return RaporPdfSettings(
      headerTitle: 'LAPORAN HASIL BELAJAR (RAPOR)',
      headerSubtitle: 'KEMENTERIAN PENDIDIKAN, KEBUDAYAAN, RISET, DAN TEKNOLOGI',
      schoolName: defaultSchoolName,
      schoolAddress: '',
      schoolPhone: '',
      logoLeftBase64: null,
      logoRightBase64: null,
      showLogoLeft: false,
      showLogoRight: true,
      showWatermark: true,
      showSpiritualAttitude: true,
      showPredikat: true,
      showAttendance: true,
      showNotes: true,
      kepsekName: '',
      kepsekNip: '',
      showSigOrtu: true,
      showSigWali: true,
      showSigKepsek: true,
      showSigDate: true,
      sigDateText: '',
      fontSize: 9,
      primaryColorHex: '#1E1B4B',
      secondaryColorHex: '#4B5563',
      titleFontSize: 13,
      titleOpacity: 1.0,
      titleIsBold: true,
      subtitleFontSize: 10,
      subtitleOpacity: 1.0,
      subtitleIsBold: false,
      schoolNameFontSize: 11,
      schoolNameOpacity: 1.0,
      schoolNameIsBold: true,
      addressFontSize: 9,
      addressOpacity: 1.0,
      addressIsBold: false,
      phoneFontSize: 9,
      phoneOpacity: 1.0,
      phoneIsBold: false,
      sectionOrder: const ['kop', 'info', 'attitude', 'academic', 'bottom_row', 'signatures'],
      academicColWidths: const [0.05, 0.25, 0.1, 0.1, 0.1, 0.4],
      legendColWidths: const [0.6, 0.4],
      attendanceColWidths: const [0.7, 0.3],
    );
  }

  factory RaporPdfSettings.fromMap(Map<String, dynamic> map, String defaultSchoolName) {
    Map<String, List<int>>? parsedPositions = (map['elementPositions'] as Map?)?.map(
      (k, v) => MapEntry(k.toString(), (v as List).map((e) => (e as num).toInt()).toList()),
    );

    // Migration: if old 'signatures' key exists but new sig_ keys don't, derive defaults
    if (parsedPositions != null &&
        parsedPositions.containsKey('signatures') &&
        !parsedPositions.containsKey('sig_ortu')) {
      final sigPos = parsedPositions['signatures']!;
      final int baseY = sigPos.length > 1 ? sigPos[1] : 44;
      parsedPositions = Map<String, List<int>>.from(parsedPositions)
        ..remove('signatures')
        ..['sig_date'] = [6, baseY, 6, 2]
        ..['sig_ortu'] = [0, baseY + 2, 4, 5]
        ..['sig_wali'] = [4, baseY + 2, 4, 5]
        ..['sig_kepsek'] = [8, baseY + 2, 4, 5];
    }

    return RaporPdfSettings(
      headerTitle: map['headerTitle']?.toString() ?? 'LAPORAN HASIL BELAJAR (RAPOR)',
      headerSubtitle: map['headerSubtitle']?.toString() ?? 'KEMENTERIAN PENDIDIKAN, KEBUDAYAAN, RISET, DAN TEKNOLOGI',
      schoolName: map['schoolName']?.toString() ?? defaultSchoolName,
      schoolAddress: map['schoolAddress']?.toString() ?? '',
      schoolPhone: map['schoolPhone']?.toString() ?? '',
      logoLeftBase64: map['logoLeftBase64']?.toString(),
      logoRightBase64: map['logoRightBase64']?.toString(),
      showLogoLeft: map['showLogoLeft'] as bool? ?? false,
      showLogoRight: map['showLogoRight'] as bool? ?? true,
      showWatermark: map['showWatermark'] as bool? ?? true,
      showSpiritualAttitude: map['showSpiritualAttitude'] as bool? ?? true,
      showPredikat: map['showPredikat'] as bool? ?? true,
      showAttendance: map['showAttendance'] as bool? ?? true,
      showNotes: map['showNotes'] as bool? ?? true,
      kepsekName: map['kepsekName']?.toString() ?? '',
      kepsekNip: map['kepsekNip']?.toString() ?? '',
      showSigOrtu: map['showSigOrtu'] as bool? ?? true,
      showSigWali: map['showSigWali'] as bool? ?? true,
      showSigKepsek: map['showSigKepsek'] as bool? ?? true,
      showSigDate: map['showSigDate'] as bool? ?? true,
      sigDateText: map['sigDateText']?.toString() ?? '',
      fontSize: map['fontSize'] as int? ?? 9,
      primaryColorHex: map['primaryColorHex']?.toString() ?? '#1E1B4B',
      secondaryColorHex: map['secondaryColorHex']?.toString() ?? '#4B5563',
      titleFontSize: map['titleFontSize'] as int? ?? 13,
      titleOpacity: (map['titleOpacity'] as num?)?.toDouble() ?? 1.0,
      titleIsBold: map['titleIsBold'] as bool? ?? true,
      subtitleFontSize: map['subtitleFontSize'] as int? ?? 10,
      subtitleOpacity: (map['subtitleOpacity'] as num?)?.toDouble() ?? 1.0,
      subtitleIsBold: map['subtitleIsBold'] as bool? ?? false,
      schoolNameFontSize: map['schoolNameFontSize'] as int? ?? 11,
      schoolNameOpacity: (map['schoolNameOpacity'] as num?)?.toDouble() ?? 1.0,
      schoolNameIsBold: map['schoolNameIsBold'] as bool? ?? true,
      addressFontSize: map['addressFontSize'] as int? ?? 9,
      addressOpacity: (map['addressOpacity'] as num?)?.toDouble() ?? 1.0,
      addressIsBold: map['addressIsBold'] as bool? ?? false,
      phoneFontSize: map['phoneFontSize'] as int? ?? 9,
      phoneOpacity: (map['phoneOpacity'] as num?)?.toDouble() ?? 1.0,
      phoneIsBold: map['phoneIsBold'] as bool? ?? false,
      sectionOrder: (map['sectionOrder'] as List?)?.map((e) => e.toString()).toList() ??
          const ['kop', 'info', 'attitude', 'academic', 'bottom_row', 'signatures'],
      academicColWidths: (map['academicColWidths'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [0.05, 0.25, 0.1, 0.1, 0.1, 0.4],
      legendColWidths: (map['legendColWidths'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [0.6, 0.4],
      attendanceColWidths: (map['attendanceColWidths'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [0.7, 0.3],
      elementPositions: parsedPositions ??
          const {
            'kop': [0, 0, 12, 8],
            'info': [0, 9, 8, 4],
            'attitude': [0, 14, 12, 5],
            'academic': [0, 20, 12, 11],
            'legend': [0, 32, 5, 11],
            'attendance': [6, 32, 6, 5],
            'notes': [6, 38, 6, 5],
            'sig_date': [6, 44, 6, 2],
            'sig_ortu': [0, 46, 4, 5],
            'sig_wali': [4, 46, 4, 5],
            'sig_kepsek': [8, 46, 4, 5],
          },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'headerTitle': headerTitle,
      'headerSubtitle': headerSubtitle,
      'schoolName': schoolName,
      'schoolAddress': schoolAddress,
      'schoolPhone': schoolPhone,
      'logoLeftBase64': logoLeftBase64,
      'logoRightBase64': logoRightBase64,
      'showLogoLeft': showLogoLeft,
      'showLogoRight': showLogoRight,
      'showWatermark': showWatermark,
      'showSpiritualAttitude': showSpiritualAttitude,
      'showPredikat': showPredikat,
      'showAttendance': showAttendance,
      'showNotes': showNotes,
      'kepsekName': kepsekName,
      'kepsekNip': kepsekNip,
      'showSigOrtu': showSigOrtu,
      'showSigWali': showSigWali,
      'showSigKepsek': showSigKepsek,
      'showSigDate': showSigDate,
      'sigDateText': sigDateText,
      'fontSize': fontSize,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
      'titleFontSize': titleFontSize,
      'titleOpacity': titleOpacity,
      'titleIsBold': titleIsBold,
      'subtitleFontSize': subtitleFontSize,
      'subtitleOpacity': subtitleOpacity,
      'subtitleIsBold': subtitleIsBold,
      'schoolNameFontSize': schoolNameFontSize,
      'schoolNameOpacity': schoolNameOpacity,
      'schoolNameIsBold': schoolNameIsBold,
      'addressFontSize': addressFontSize,
      'addressOpacity': addressOpacity,
      'addressIsBold': addressIsBold,
      'phoneFontSize': phoneFontSize,
      'phoneOpacity': phoneOpacity,
      'phoneIsBold': phoneIsBold,
      'sectionOrder': sectionOrder,
      'academicColWidths': academicColWidths,
      'legendColWidths': legendColWidths,
      'attendanceColWidths': attendanceColWidths,
      'elementPositions': elementPositions,
    };
  }

  RaporPdfSettings copyWith({
    String? headerTitle,
    String? headerSubtitle,
    String? schoolName,
    String? schoolAddress,
    String? schoolPhone,
    String? logoLeftBase64,
    String? logoRightBase64,
    bool? showLogoLeft,
    bool? showLogoRight,
    bool? showWatermark,
    bool? showSpiritualAttitude,
    bool? showPredikat,
    bool? showAttendance,
    bool? showNotes,
    String? kepsekName,
    String? kepsekNip,
    bool? showSigOrtu,
    bool? showSigWali,
    bool? showSigKepsek,
    bool? showSigDate,
    String? sigDateText,
    int? fontSize,
    String? primaryColorHex,
    String? secondaryColorHex,
    int? titleFontSize,
    double? titleOpacity,
    bool? titleIsBold,
    int? subtitleFontSize,
    double? subtitleOpacity,
    bool? subtitleIsBold,
    int? schoolNameFontSize,
    double? schoolNameOpacity,
    bool? schoolNameIsBold,
    int? addressFontSize,
    double? addressOpacity,
    bool? addressIsBold,
    int? phoneFontSize,
    double? phoneOpacity,
    bool? phoneIsBold,
    List<String>? sectionOrder,
    List<double>? academicColWidths,
    List<double>? legendColWidths,
    List<double>? attendanceColWidths,
    Map<String, List<int>>? elementPositions,
  }) {
    return RaporPdfSettings(
      headerTitle: headerTitle ?? this.headerTitle,
      headerSubtitle: headerSubtitle ?? this.headerSubtitle,
      schoolName: schoolName ?? this.schoolName,
      schoolAddress: schoolAddress ?? this.schoolAddress,
      schoolPhone: schoolPhone ?? this.schoolPhone,
      logoLeftBase64: logoLeftBase64 ?? this.logoLeftBase64,
      logoRightBase64: logoRightBase64 ?? this.logoRightBase64,
      showLogoLeft: showLogoLeft ?? this.showLogoLeft,
      showLogoRight: showLogoRight ?? this.showLogoRight,
      showWatermark: showWatermark ?? this.showWatermark,
      showSpiritualAttitude: showSpiritualAttitude ?? this.showSpiritualAttitude,
      showPredikat: showPredikat ?? this.showPredikat,
      showAttendance: showAttendance ?? this.showAttendance,
      showNotes: showNotes ?? this.showNotes,
      kepsekName: kepsekName ?? this.kepsekName,
      kepsekNip: kepsekNip ?? this.kepsekNip,
      showSigOrtu: showSigOrtu ?? this.showSigOrtu,
      showSigWali: showSigWali ?? this.showSigWali,
      showSigKepsek: showSigKepsek ?? this.showSigKepsek,
      showSigDate: showSigDate ?? this.showSigDate,
      sigDateText: sigDateText ?? this.sigDateText,
      fontSize: fontSize ?? this.fontSize,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      titleFontSize: titleFontSize ?? this.titleFontSize,
      titleOpacity: titleOpacity ?? this.titleOpacity,
      titleIsBold: titleIsBold ?? this.titleIsBold,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleOpacity: subtitleOpacity ?? this.subtitleOpacity,
      subtitleIsBold: subtitleIsBold ?? this.subtitleIsBold,
      schoolNameFontSize: schoolNameFontSize ?? this.schoolNameFontSize,
      schoolNameOpacity: schoolNameOpacity ?? this.schoolNameOpacity,
      schoolNameIsBold: schoolNameIsBold ?? this.schoolNameIsBold,
      addressFontSize: addressFontSize ?? this.addressFontSize,
      addressOpacity: addressOpacity ?? this.addressOpacity,
      addressIsBold: addressIsBold ?? this.addressIsBold,
      phoneFontSize: phoneFontSize ?? this.phoneFontSize,
      phoneOpacity: phoneOpacity ?? this.phoneOpacity,
      phoneIsBold: phoneIsBold ?? this.phoneIsBold,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      academicColWidths: academicColWidths ?? this.academicColWidths,
      legendColWidths: legendColWidths ?? this.legendColWidths,
      attendanceColWidths: attendanceColWidths ?? this.attendanceColWidths,
      elementPositions: elementPositions ?? this.elementPositions,
    );
  }
}
