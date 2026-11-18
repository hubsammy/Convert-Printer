import 'dart:ui';
import '../constants/page_config.dart';

class FormatConfig {
  double fontSize;
  TextAlign textAlign;
  double lineSpacing;
  double paragraphSpacing;
  double marginTop;
  double marginBottom;
  double marginLeft;
  double marginRight;
  PageSizeType pageSizeType;
  int selectedFontIndex;
  List<double> rulerHorizontalMarkers;
  List<double> rulerVerticalMarkers;

  FormatConfig({
    this.fontSize = PageConfig.defaultFontSize,
    this.textAlign = TextAlign.left,
    this.lineSpacing = PageConfig.defaultLineSpacing,
    this.paragraphSpacing = PageConfig.defaultParagraphSpacing,
    this.marginTop = PageConfig.defaultMargin,
    this.marginBottom = PageConfig.defaultMargin,
    this.marginLeft = PageConfig.defaultMargin,
    this.marginRight = PageConfig.defaultMargin,
    this.pageSizeType = PageSizeType.a4,
    this.selectedFontIndex = 0,
    this.rulerHorizontalMarkers = const <double>[],
    this.rulerVerticalMarkers = const <double>[],
  });

  double get pageWidth => pageSizeType.size.width;
  double get pageHeight => pageSizeType.size.height;

  double get usableWidth => pageWidth - marginLeft - marginRight;

  double get usableHeight =>
      pageHeight - marginTop - marginBottom - PageConfig.footerHeight;

  double get lineHeight => fontSize * lineSpacing;

  FormatConfig copyWith({
    double? fontSize,
    TextAlign? textAlign,
    double? lineSpacing,
    double? paragraphSpacing,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    PageSizeType? pageSizeType,
    int? selectedFontIndex,
    List<double>? rulerHorizontalMarkers,
    List<double>? rulerVerticalMarkers,
  }) {
    return FormatConfig(
      fontSize: fontSize ?? this.fontSize,
      textAlign: textAlign ?? this.textAlign,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      pageSizeType: pageSizeType ?? this.pageSizeType,
      selectedFontIndex: selectedFontIndex ?? this.selectedFontIndex,
      rulerHorizontalMarkers:
          List<double>.from(rulerHorizontalMarkers ?? this.rulerHorizontalMarkers),
      rulerVerticalMarkers:
          List<double>.from(rulerVerticalMarkers ?? this.rulerVerticalMarkers),
    );
  }

  Map<String, dynamic> toJson() => {
    'fontSize': fontSize,
    'textAlign': textAlign.index,
    'lineSpacing': lineSpacing,
    'paragraphSpacing': paragraphSpacing,
    'marginTop': marginTop,
    'marginBottom': marginBottom,
    'marginLeft': marginLeft,
    'marginRight': marginRight,
    'pageSizeType': pageSizeType.index,
    'selectedFontIndex': selectedFontIndex,
    'rulerHorizontalMarkers': rulerHorizontalMarkers,
    'rulerVerticalMarkers': rulerVerticalMarkers,
  };

  static TextAlign _normalizeAlign(TextAlign value) =>
      value == TextAlign.justify ? TextAlign.left : value;

  factory FormatConfig.fromJson(Map<String, dynamic> json) {
    return FormatConfig(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? PageConfig.defaultFontSize,
      textAlign: _normalizeAlign(TextAlign.values[(json['textAlign'] as int?) ?? 0]),
      lineSpacing: (json['lineSpacing'] as num?)?.toDouble() ?? PageConfig.defaultLineSpacing,
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? PageConfig.defaultParagraphSpacing,
      marginTop: (json['marginTop'] as num?)?.toDouble() ?? PageConfig.defaultMargin,
      marginBottom: (json['marginBottom'] as num?)?.toDouble() ?? PageConfig.defaultMargin,
      marginLeft: (json['marginLeft'] as num?)?.toDouble() ?? PageConfig.defaultMargin,
      marginRight: (json['marginRight'] as num?)?.toDouble() ?? PageConfig.defaultMargin,
      pageSizeType: PageSizeType.values[(json['pageSizeType'] as int?) ?? 0],
      selectedFontIndex: (json['selectedFontIndex'] as int?) ?? 0,
      rulerHorizontalMarkers: ((json['rulerHorizontalMarkers'] as List?) ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      rulerVerticalMarkers: ((json['rulerVerticalMarkers'] as List?) ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}
