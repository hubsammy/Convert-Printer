import 'package:flutter/services.dart';

class FontInfo {
  final String name;
  final String asset;
  final String family;

  const FontInfo(this.name, this.asset, this.family);
}

class FontService {
  static FontService? _instance;
  final Map<String, ByteData> _data = {};
  final Map<String, String> _families = {};

  FontService._();

  static FontService get instance {
    _instance ??= FontService._();
    return _instance!;
  }

  static const fontList = [
    FontInfo('Hei Ti', 'assets/fonts/simhei.ttf', 'CPHeiTi'),
    FontInfo('Kai Ti', 'assets/fonts/simkai.ttf', 'CPKaiTi'),
    FontInfo('Fang Song', 'assets/fonts/simfang.ttf', 'CPFangSong'),
    FontInfo('Song Ti', 'assets/fonts/STSONG.TTF', 'CPSongTi'),
  ];

  bool get isLoaded => _data.isNotEmpty;

  List<Uint8List> get loadedFonts {
    final list = <Uint8List>[];
    for (final info in fontList) {
      final data = _data[info.name];
      if (data != null) list.add(_toBytes(data));
    }
    return list;
  }

  Future<void> loadAll() async {
    for (final info in fontList) {
      try {
        final data = await rootBundle.load(info.asset);
        _data[info.name] = data;
        final loader = FontLoader(info.family)..addFont(Future.value(data));
        await loader.load();
        _families[info.name] = info.family;
      } catch (_) {
        // Font missing or unreadable: skip, PDF falls back to loaded fonts.
      }
    }
  }

  static Uint8List _toBytes(ByteData data) =>
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

  Uint8List getFont(int index) {
    final info = fontList[index.clamp(0, fontList.length - 1)];
    final data = _data[info.name] ?? (_data.isEmpty ? null : _data.values.first);
    return data == null ? Uint8List(0) : _toBytes(data);
  }

  Uint8List? bytesForIndex(int index) {
    final info = fontList[index.clamp(0, fontList.length - 1)];
    final data = _data[info.name];
    return data == null ? null : _toBytes(data);
  }

  /// Maps a registered Flutter family name back to the font index.
  int? indexForFamily(String? family) {
    if (family == null || family.isEmpty) return null;
    for (var i = 0; i < fontList.length; i++) {
      final info = fontList[i];
      if (_families[info.name] == family || info.name == family) return i;
    }
    return null;
  }

  String fontName(int index) {
    return fontList[index.clamp(0, fontList.length - 1)].name;
  }

  /// Flutter font family registered for the editor, or null when unavailable.
  String? flutterFamily(int index) {
    final info = fontList[index.clamp(0, fontList.length - 1)];
    return _families[info.name];
  }
}
