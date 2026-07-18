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
  final String ttdKepsekPosition; // 'left', 'center', 'right', 'none'
  final String ttdWaliPosition;   // 'left', 'center', 'right', 'none'
  final String ttdOrtuPosition;   // 'left', 'center', 'right', 'none'
  final int fontSize;
  final String primaryColorHex;
  final String secondaryColorHex;

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
    required this.ttdKepsekPosition,
    required this.ttdWaliPosition,
    required this.ttdOrtuPosition,
    required this.fontSize,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    this.sectionOrder = const ['kop', 'info', 'attitude', 'academic', 'bottom_row', 'signatures'],
    this.academicColWidths = const [0.05, 0.25, 0.1, 0.1, 0.1, 0.4],
    this.legendColWidths = const [0.6, 0.4],
    this.attendanceColWidths = const [0.7, 0.3],
    this.elementPositions = const {
      'kop': [0, 0, 12, 6],
      'info': [0, 7, 12, 3],
      'attitude': [0, 11, 12, 5],
      'academic': [0, 17, 12, 11],
      'legend': [0, 29, 5, 11],
      'attendance': [6, 29, 6, 5],
      'notes': [6, 35, 6, 5],
      'signatures': [0, 41, 12, 6],
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
      ttdKepsekPosition: 'right',
      ttdWaliPosition: 'right',
      ttdOrtuPosition: 'left',
      fontSize: 9,
      primaryColorHex: '#1E1B4B',
      secondaryColorHex: '#4B5563',
      sectionOrder: const ['kop', 'info', 'attitude', 'academic', 'bottom_row', 'signatures'],
      academicColWidths: const [0.05, 0.25, 0.1, 0.1, 0.1, 0.4],
      legendColWidths: const [0.6, 0.4],
      attendanceColWidths: const [0.7, 0.3],
    );
  }

  factory RaporPdfSettings.fromMap(Map<String, dynamic> map, String defaultSchoolName) {
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
      ttdKepsekPosition: map['ttdKepsekPosition']?.toString() ?? 'right',
      ttdWaliPosition: map['ttdWaliPosition']?.toString() ?? 'right',
      ttdOrtuPosition: map['ttdOrtuPosition']?.toString() ?? 'left',
      fontSize: map['fontSize'] as int? ?? 9,
      primaryColorHex: map['primaryColorHex']?.toString() ?? '#1E1B4B',
      secondaryColorHex: map['secondaryColorHex']?.toString() ?? '#4B5563',
      sectionOrder: (map['sectionOrder'] as List?)?.map((e) => e.toString()).toList() ??
          const ['kop', 'info', 'attitude', 'academic', 'bottom_row', 'signatures'],
      academicColWidths: (map['academicColWidths'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [0.05, 0.25, 0.1, 0.1, 0.1, 0.4],
      legendColWidths: (map['legendColWidths'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [0.6, 0.4],
      attendanceColWidths: (map['attendanceColWidths'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [0.7, 0.3],
      elementPositions: (map['elementPositions'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as List).map((e) => (e as num).toInt()).toList()),
          ) ??
          const {
            'kop': [0, 0, 12, 6],
            'info': [0, 7, 12, 3],
            'attitude': [0, 11, 12, 5],
            'academic': [0, 17, 12, 11],
            'legend': [0, 29, 5, 11],
            'attendance': [6, 29, 6, 5],
            'notes': [6, 35, 6, 5],
            'signatures': [0, 41, 12, 6],
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
      'ttdKepsekPosition': ttdKepsekPosition,
      'ttdWaliPosition': ttdWaliPosition,
      'ttdOrtuPosition': ttdOrtuPosition,
      'fontSize': fontSize,
      'primaryColorHex': primaryColorHex,
      'secondaryColorHex': secondaryColorHex,
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
    String? ttdKepsekPosition,
    String? ttdWaliPosition,
    String? ttdOrtuPosition,
    int? fontSize,
    String? primaryColorHex,
    String? secondaryColorHex,
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
      ttdKepsekPosition: ttdKepsekPosition ?? this.ttdKepsekPosition,
      ttdWaliPosition: ttdWaliPosition ?? this.ttdWaliPosition,
      ttdOrtuPosition: ttdOrtuPosition ?? this.ttdOrtuPosition,
      fontSize: fontSize ?? this.fontSize,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      secondaryColorHex: secondaryColorHex ?? this.secondaryColorHex,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      academicColWidths: academicColWidths ?? this.academicColWidths,
      legendColWidths: legendColWidths ?? this.legendColWidths,
      attendanceColWidths: attendanceColWidths ?? this.attendanceColWidths,
      elementPositions: elementPositions ?? this.elementPositions,
    );
  }
}
