import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/page_config.dart';
import '../models/format_config.dart';
import '../services/font_service.dart';
import '../services/landrop_service.dart';
import '../services/pdf_generator_service.dart';
import '../services/print_service.dart';

class EditorProvider extends ChangeNotifier {
  String _text = '';
  FormatConfig _format = FormatConfig();
  Uint8List? _pdfData;
  bool _isComputing = false;
  String? _error;
  int _pageCount = 1;

  List<pw.Font> _fonts = [];
  PdfGeneratorService? _pdfService;
  final PrintService _printService = PrintService();
  final LandropService _landropService = LandropService();
  final _notificationController = StreamController<String>.broadcast();

  Timer? _debounceTimer;

  Stream<String> get onNotification => _notificationController.stream;

  LandropService get landropService => _landropService;

  String get text => _text;
  FormatConfig get format => _format;
  Uint8List? get pdfData => _pdfData;
  bool get isComputing => _isComputing;
  String? get error => _error;
  PrintService get printService => _printService;
  bool get isFontLoaded => _fonts.isNotEmpty;
  int get pageCount => _pageCount;
  int get charCount => _text.length;

  Future<void> initialize() async {
    try {
      await FontService.instance.loadAll();
      for (final data in FontService.instance.loadedFonts) {
        _fonts.add(pw.Font.ttf(data.buffer.asByteData()));
      }
      _pdfService = PdfGeneratorService(_fonts);
      await _landropService.initialize();

      _landropService.onTextReceived.listen((text) {
        _text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        _landropService.updateEditorText(_text);
        _persistText();
        _notificationController.add('Text received from phone');
        notifyListeners();
        _debounceRebuild(300);
      });

      _landropService.onNewFile.listen((file) {
        final t = _landropService.fileType(file.name);
        final label = t == 'image' ? 'Image' : t == 'audio' ? 'Audio' : t == 'text' ? 'Text' : t == 'pdf' ? 'PDF' : 'File';
        _notificationController.add('$label received: ${file.name}');
        notifyListeners();
      });

      await _loadPersistedText();
      await _loadPersistedConfig();

      if (_text.isNotEmpty) {
        _landropService.updateEditorText(_text);
      }

      notifyListeners();
      await _generate();
    } catch (e) {
      _error = '初始化失败: $e';
      notifyListeners();
    }
  }

  void loadFromLandrop(String filePath, String content) {
    _text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    _landropService.updateEditorText(_text);
    _persistText();
    notifyListeners();
    _debounceRebuild(300);
  }

  void updateText(String newText) {
    _text = newText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    _landropService.updateEditorText(_text);
    _persistText();
    notifyListeners();
    _debounceRebuild(500);
  }

  void setFontSize(double size) {
    _format = _format.copyWith(
      fontSize: size.clamp(PageConfig.minFontSize, PageConfig.maxFontSize),
    );
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setAlignment(TextAlign align) {
    _format = _format.copyWith(textAlign: align);
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setLineSpacing(double spacing) {
    _format = _format.copyWith(
      lineSpacing:
          spacing.clamp(PageConfig.minLineSpacing, PageConfig.maxLineSpacing),
    );
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setParagraphSpacing(double spacing) {
    _format = _format.copyWith(
      paragraphSpacing: spacing.clamp(
          PageConfig.minParagraphSpacing, PageConfig.maxParagraphSpacing),
    );
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setMarginTop(double value) {
    _format = _format.copyWith(
        marginTop: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setMarginBottom(double value) {
    _format = _format.copyWith(
        marginBottom: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setMarginLeft(double value) {
    _format = _format.copyWith(
        marginLeft: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setMarginRight(double value) {
    _format = _format.copyWith(
        marginRight: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setPageSizeType(PageSizeType type) {
    _format = _format.copyWith(pageSizeType: type);
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  void setFontIndex(int index) {
    _format = _format.copyWith(selectedFontIndex: index);
    _persistConfig();
    notifyListeners();
    _debounceRebuild(200);
  }

  String get currentFontName => FontService.instance.fontName(_format.selectedFontIndex);
  int get currentFontIndex => _format.selectedFontIndex;
  List<String> get fontNames =>
      FontService.fontList.map((f) => f.name).toList();

  void _debounceRebuild(int ms) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: ms), _generate);
  }

  Future<void> _generate() async {
    if (_pdfService == null) return;

    _isComputing = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _pdfService!.generate(_text, _format);
      _pdfData = result.pdfData;
      _pageCount = result.totalPages;
      _landropService.updateEditorPdf(_pdfData?.toList() ?? []);
    } catch (e) {
      _error = '生成失败: $e';
    }

    _isComputing = false;
    notifyListeners();
  }

  Future<void> rebuildLayout() => _generate();

  String get _autosavePath {
    final dir = _landropService.downloadDir;
    return '$dir${Platform.pathSeparator}_editor_autosave.txt';
  }

  void _persistText() {
    try {
      final dir = Directory(_landropService.downloadDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File(_autosavePath).writeAsStringSync(_text);
    } catch (_) {}
  }

  Future<void> _loadPersistedText() async {
    try {
      final file = File(_autosavePath);
      if (await file.exists()) {
        _text = await file.readAsString();
      }
    } catch (_) {}
  }

  String get _configPath {
    final dir = _landropService.downloadDir;
    return '$dir${Platform.pathSeparator}_editor_config.json';
  }

  void _persistConfig() {
    try {
      final dir = Directory(_landropService.downloadDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File(_configPath).writeAsStringSync(jsonEncode(_format.toJson()));
    } catch (_) {}
  }

  Future<void> _loadPersistedConfig() async {
    try {
      final file = File(_configPath);
      if (await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        _format = FormatConfig.fromJson(json);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _landropService.dispose();
    super.dispose();
  }
}
