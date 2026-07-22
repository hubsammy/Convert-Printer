import 'dart:ui';

class PageConfig {
  static const double a4Width = 595.28;
  static const double a4Height = 841.89;
  static const double letterWidth = 612.0;
  static const double letterHeight = 792.0;

  static const double defaultPageWidth = a4Width;
  static const double defaultPageHeight = a4Height;

  static const double defaultFontSize = 14.0;
  static const double minFontSize = 8.0;
  static const double maxFontSize = 72.0;

  static const double defaultLineSpacing = 1.5;
  static const double minLineSpacing = 1.0;
  static const double maxLineSpacing = 3.0;

  static const double defaultParagraphSpacing = 10.0;
  static const double minParagraphSpacing = 0.0;
  static const double maxParagraphSpacing = 40.0;

  static const double defaultMargin = 72.0;
  static const double minMargin = 20.0;
  static const double maxMargin = 120.0;

  static const double footerFontSize = 10.0;
  static const double footerHeight = 30.0;
}

enum PageSizeType {
  a4,
  letter,
}

extension PageSizeTypeExt on PageSizeType {
  String get label {
    switch (this) {
      case PageSizeType.a4:
        return 'A4';
      case PageSizeType.letter:
        return 'Letter';
    }
  }

  Size get size {
    switch (this) {
      case PageSizeType.a4:
        return const Size(PageConfig.a4Width, PageConfig.a4Height);
      case PageSizeType.letter:
        return const Size(PageConfig.letterWidth, PageConfig.letterHeight);
    }
  }
}
