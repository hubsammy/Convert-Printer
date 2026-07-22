import 'dart:typed_data';

import 'package:flutter/services.dart';

class FontInfo {
  final String name;
  final String asset;
  final Uint8List? _data;
  Uint8List? get data => _data;

  FontInfo(this.name, this.asset, [this._data]);
}

class FontService {
  static FontService? _instance;
  final _fonts = <String, Uint8List>{};

  FontService._();

  static FontService get instance {
    _instance ??= FontService._();
    return _instance!;
  }

  static final fontList = [
    FontInfo('Hei Ti', 'assets/fonts/simhei.ttf'),
    FontInfo('Kai Ti', 'assets/fonts/simkai.ttf'),
    FontInfo('Fang Song', 'assets/fonts/simfang.ttf'),
    FontInfo('Song Ti', 'assets/fonts/STSONG.TTF'),
  ];

  List<Uint8List> get loadedFonts => _fonts.values.toList();

  Future<void> loadAll() async {
    for (final info in fontList) {
      try {
        final data = await rootBundle.load(info.asset);
        _fonts[info.name] = data.buffer.asUint8List();
      } catch (_) {}
    }
  }

  Uint8List getFont(int index) {
    final info = fontList[index.clamp(0, fontList.length - 1)];
    return _fonts[info.name] ?? _fonts.values.first;
  }

  String fontName(int index) {
    return fontList[index.clamp(0, fontList.length - 1)].name;
  }
}
