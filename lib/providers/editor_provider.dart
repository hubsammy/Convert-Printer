import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import '../constants/page_config.dart';
import '../models/format_config.dart';
import '../services/font_service.dart';
import '../services/landrop_service.dart';
import '../services/print_service.dart';

class EditorProvider extends ChangeNotifier {
  FormatConfig _format = FormatConfig();
  Uint8List? _pdfData;
  bool _isComputing = false;
  bool _isInitialized = false;
  int _focusRequest = 0;
  String? _error;
  int _pageCount = 1;
  double _zoom = 1.0;

  late final WordEditorController _word;
  late OfficeSurfaceConfig _surfaceConfig;
  OfficeFontSet? _officeFonts;

  final PrintService _printService = PrintService();
  final LandropService _landropService = LandropService();
  final _notificationController = StreamController<String>.broadcast();
  final _imagePreviewController = StreamController<String>.broadcast();

  Timer? _pdfDebounce;
  bool _pdfDirty = false;
  Timer? _saveDebounce;
  String _lastKnownText = '';
  bool _suppressWord = false;

  static const double minZoom = 0.25;
  static const double maxZoom = 2.5;

  EditorProvider() {
    _surfaceConfig = OfficeSurfaceConfig(
      mode: OfficeInteractionMode.editing,
      theme: OfficeTheme.light.copyWith(
        pageBackground: const Color(0xFF5B5B5B),
        pageBorder: Colors.transparent,
        selectionFill: const Color(0x664A90E2),
        selectionStroke: const Color(0xFF1E6FD9),
      ),
      showRulers: true,
      autofocus: true,
    );
    _word = WordEditorController(
      document: WmlDocument.empty(),
      config: _surfaceConfig,
    );
    _word.addListener(_onWordChanged);
  }

  Stream<String> get onNotification => _notificationController.stream;
  Stream<String> get onImagePreview => _imagePreviewController.stream;
  LandropService get landropService => _landropService;
  WordEditorController get wordController => _word;
  OfficeSurfaceConfig get officeSurfaceConfig => _surfaceConfig;

  FormatConfig get format => _format;
  Uint8List? get pdfData => _pdfData;
  bool get isComputing => _isComputing;
  bool get isInitialized => _isInitialized;
  int get focusRequest => _focusRequest;
  String? get error => _error;
  PrintService get printService => _printService;
  bool get isFontLoaded => _officeFonts != null;
  int get pageCount => _pageCount;

  int get activePageIndex {
    try {
      final pages = _word.documentLaidOut.pages;
      if (pages.isEmpty) {
        return 0;
      }
      final caret = _word.caret;
      final paragraph = caret.paragraphIndex;
      for (var i = 0; i < pages.length; i++) {
        for (final line in pages[i].lines) {
          if (line.paragraphIndex != paragraph || line.glyphs.isEmpty) {
            continue;
          }
          var first = 1 << 30;
          var last = -1;
          for (final glyph in line.glyphs) {
            final logical = glyph.glyph.logicalIndex;
            if (logical < first) first = logical;
            if (logical > last) last = logical;
          }
          if (caret.logicalIndex >= first && caret.logicalIndex <= last + 1) {
            return i;
          }
        }
      }
      for (var i = 0; i < pages.length; i++) {
        if (pages[i].lines.any((line) => line.paragraphIndex == paragraph)) {
          return i;
        }
      }
      return _word.visiblePageIndex.clamp(0, pages.length - 1).toInt();
    } catch (_) {
      return 0;
    }
  }
  double get zoom => _zoom;

  String get text {
    try {
      return _word.document.paragraphs.map((p) => p.text).join('\n');
    } catch (_) {
      return '';
    }
  }

  bool get isDocEmpty => text.trim().isEmpty;
  int get charCount => text.replaceAll('\n', '').length;

  WmlRunProps get _activeProps {
    try {
      return _word.activeRunProps;
    } catch (_) {
      return WmlRunProps();
    }
  }

  bool get isBold => _activeProps.bold;
  bool get isItalic => _activeProps.italic;
  bool get isUnderline => _activeProps.underline != WmlUnderline.none;
  bool get isStrike => _activeProps.strike;
  String? get selectionColor => '#${_activeProps.color}';
  String? get selectionHighlight =>
      _activeProps.highlight == null ? null : '#${_activeProps.highlight}';

  int? get selectionHeaderLevel {
    try {
      final level = _word.activeHeadingLevel;
      return level == 0 ? null : level;
    } catch (_) {
      return null;
    }
  }

  String? get selectionAlign {
    final index = _format.textAlign;
    switch (index) {
      case TextAlign.left:
      case TextAlign.start:
        return 'left';
      case TextAlign.center:
        return 'center';
      case TextAlign.right:
      case TextAlign.end:
        return 'right';
      case TextAlign.justify:
        return 'justify';
    }
  }

  String get currentFontName =>
      FontService.instance.fontName(_format.selectedFontIndex);
  int get currentFontIndex => _format.selectedFontIndex;
  String? get currentFontFamily =>
      FontService.instance.flutterFamily(_format.selectedFontIndex);
  List<String> get fontNames =>
      FontService.fontList.map((f) => f.name).toList();

  Future<void> initialize() async {
    try {
      await FontService.instance.loadAll();
      try {
        await OfficeHostFonts.ensureRegistered();
      } catch (_) {}

      _officeFonts = _buildOfficeFontSet(_format.selectedFontIndex);
      _updateSurfaceConfig();
      await _landropService.initialize();

      _landropService.onTextReceived.listen((received) {
        _focusRequest++;
        setPlainText(received,
            notification: 'Text received from phone', delayMs: 80);
      });

      _landropService.onNewFile.listen((file) {
        final t = _landropService.fileType(file.name);
        if (t == 'image') {
          _imagePreviewController.add(file.path);
          _notificationController.add('Image received: ${file.name}');
          notifyListeners();
        } else {
          final label = t == 'audio'
              ? 'Audio'
              : t == 'text'
                  ? 'Text'
                  : t == 'pdf'
                      ? 'PDF'
                      : 'File';
          _notificationController.add('$label received: ${file.name}');
          notifyListeners();
        }
      });

      await _loadPersistedConfig();
      await _loadPersistedWord();

      _suppressWord = true;
      _applyPageSetup();
      _applyFontToDocument();
      _applyParagraphFormatToDocument();
      _word.relayout();
      _suppressWord = false;

      _zoom = _word.viewport.scale;
      _lastKnownText = text;
      _pageCount = _word.pageCount;
      _landropService.updateEditorText(text);

      _isInitialized = true;
      notifyListeners();
      _debouncePdf(100);
      _persistWordLater();
    } catch (e) {
      _error = '初始化失败: $e';
      _isInitialized = true;
      notifyListeners();
    }
  }

  OfficeFontSet _buildOfficeFontSet(int selected) {
    final primaryBytes = FontService.instance.bytesForIndex(selected) ??
        (FontService.instance.loadedFonts.isEmpty
            ? null
            : FontService.instance.loadedFonts.first);
    if (primaryBytes == null) return const OfficeFontSet();

    SfntFont? primary;
    try {
      primary = SfntFont.parse(primaryBytes);
    } catch (_) {}

    final fallbacks = <SfntFont>[];
    for (var i = 0; i < FontService.fontList.length; i++) {
      if (i == selected) continue;
      final bytes = FontService.instance.bytesForIndex(i);
      if (bytes == null) continue;
      try {
        fallbacks.add(SfntFont.parse(bytes));
      } catch (_) {}
    }
    return OfficeFontSet(primary: primary, fallbacks: fallbacks);
  }

  void _updateSurfaceConfig() {
    final family =
        FontService.instance.flutterFamily(_format.selectedFontIndex) ??
            'Arial';
    _surfaceConfig = _surfaceConfig.copyWith(
      theme: _surfaceConfig.theme.copyWith(fontFamily: family),
    );
    _word.syncConfig(_surfaceConfig);
    _word.refreshMetrics();
  }

  void _applyPageSetup() {
    _word.setPageSize(_format.pageSizeType == PageSizeType.a4
        ? WmlPageSize.a4()
        : WmlPageSize.letter());
    _word.setPageMargins(WmlPageMargins(
      top: _format.marginTop,
      bottom: _format.marginBottom,
      left: _format.marginLeft,
      right: _format.marginRight,
    ));
  }

  void _applyFontToDocument() {
    final family =
        FontService.instance.flutterFamily(_format.selectedFontIndex) ??
            'Arial';
    for (final paragraph in _word.document.paragraphs) {
      for (final inline in paragraph.inlines) {
        if (inline is WmlRun) {
          inline.properties
            ..asciiFont = family
            ..csFont = family;
        }
      }
    }
  }

  WmlJustification _justificationFor(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return WmlJustification.center;
      case TextAlign.right:
      case TextAlign.end:
        return WmlJustification.right;
      default:
        return WmlJustification.left;
    }
  }

  void _applyParagraphFormatToDocument() {
    final justification = _justificationFor(_format.textAlign);
    for (final paragraph in _word.document.paragraphs) {
      paragraph.properties
        ..lineSpacing = _format.lineSpacing
        ..lineSpacingRule = WmlLineSpacingRule.auto
        ..explicitLineSpacing = true
        ..spacingAfter = _format.paragraphSpacing
        ..explicitSpacingAfter = true
        ..justification = justification;
    }
  }

  void _onWordChanged() {
    if (_suppressWord) return;

    if (_word.document.paragraphs.isEmpty) {
      _suppressWord = true;
      _word.document = _documentFromText('');
      _resetEditorState();
      _word.relayout();
      _suppressWord = false;
      _focusRequest++;
    }

    _zoom = _word.viewport.scale;
    _pageCount = _word.pageCount;

    final current = text;
    if (current != _lastKnownText) {
      _lastKnownText = current;
      _landropService.updateEditorText(current);
      _persistWordLater();
      _debouncePdf(120);
    }
    notifyListeners();
  }

  void _debouncePdf(int ms) {
    _pdfDebounce?.cancel();
    _pdfDebounce = Timer(Duration(milliseconds: ms), _requestPdf);
  }

  void _requestPdf() {
    if (_isComputing) {
      _pdfDirty = true;
      return;
    }
    _generatePdf();
  }

  Future<void> _generatePdf() async {    if (_officeFonts == null) return;

    _isComputing = true;
    _error = null;
    notifyListeners();

    await Future<void>.delayed(Duration.zero);
    try {
      final bytes = _word.exportPdf(fonts: _officeFonts);
      _pdfData = bytes;
      _pageCount = _word.pageCount;
      _landropService.updateEditorPdf(bytes.toList());
    } catch (e) {
      _error = '生成失败: $e';
    }

    _isComputing = false;
    if (_pdfDirty) {
      _pdfDirty = false;
      _debouncePdf(20);
    }
    notifyListeners();
  }

  /// Builds the PDF from the current canonical editor document, waiting for
  /// any in-flight generation so print/share never uses stale content.
  Future<Uint8List?> ensureLatestPdf() async {
    _pdfDebounce?.cancel();
    if (_officeFonts == null) return _pdfData;
    while (_isComputing) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await _generatePdf();
    return _pdfData;
  }

  Future<bool> printCurrentPdf() async {
    final bytes = await ensureLatestPdf();
    if (bytes == null) return false;
    await _printService.printPdf(bytes);
    return true;
  }

  Future<void> printImagePreview(String path) => _printService.printImage(path);

  Future<bool> shareCurrentPdf() async {
    final bytes = await ensureLatestPdf();
    if (bytes == null) return false;
    await _printService.sharePdf(bytes, fileName: 'article.pdf');
    return true;
  }

  Future<void> rebuildLayout() async {
    _word.relayout();
    _requestPdf();
  }

  void clearDocument() {
    _focusRequest++;
    setPlainText('', notification: '内容已删除');
  }

  /// Creates one blank A4 sheet with the default page format.
  void newA4Document() {
    _format = FormatConfig();
    _focusRequest++;
    setPlainText('', notification: '新建 A4 纸面', delayMs: 0);
    _persistConfig();
  }

  void setPlainText(String value,
      {String? notification, int delayMs = 120}) {
    _suppressWord = true;
    _word.document = _documentFromText(value);
    _resetEditorState();
    _applyPageSetup();
    _word.relayout();
    _suppressWord = false;

    _lastKnownText = text;
    _pageCount = _word.pageCount;
    _landropService.updateEditorText(text);
    _persistWordLater();
    if (notification != null) _notificationController.add(notification);
    notifyListeners();
    _debouncePdf(delayMs);
  }

  void _resetEditorState() {
    final caret = _word.caret;
    caret.paragraphIndex = 0;
    caret.logicalIndex = 0;
    caret.selectionAnchorParagraph = 0;
    caret.selectionAnchor = 0;
    caret.collapseSelection();
    _word.selectedVisual = null;
    _word.selectedFrame = null;
    _word.selectedTable = null;
    _word.selectedTableBand = null;
    _word.selectedEquation = null;
  }

  void loadFromLandrop(String filePath, String content) {
    _focusRequest++;
    setPlainText(content, delayMs: 80);
  }

  WmlDocument _documentFromText(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    var source = normalized;
    if (source.endsWith('\n')) {
      source = source.substring(0, source.length - 1);
    }
    final family =
        FontService.instance.flutterFamily(_format.selectedFontIndex) ??
            'Arial';
    final halfPoints = (_format.fontSize * 2).round();

    final blocks = <WmlBlock>[
      for (final line in source.split('\n'))
        WmlParagraph(
          properties: WmlParagraphProps(
            justification: _justificationFor(_format.textAlign),
            lineSpacing: _format.lineSpacing,
            lineSpacingRule: WmlLineSpacingRule.auto,
            explicitLineSpacing: true,
            spacingAfter: _format.paragraphSpacing,
            explicitSpacingAfter: true,
          ),
          inlines: <WmlInline>[
            WmlRun(
              text: line,
              properties: WmlRunProps(
                asciiFont: family,
                csFont: family,
                fontSizeHalfPoints: halfPoints,
              ),
            ),
          ],
        ),
    ];
    if (blocks.isEmpty) {
      blocks.add(WmlParagraph(
        inlines: <WmlInline>[
          WmlRun(
            text: '',
            properties: WmlRunProps(
              asciiFont: family,
              csFont: family,
              fontSizeHalfPoints: halfPoints,
            ),
          ),
        ],
      ));
    }
    return WmlDocument(sections: <WmlSection>[
      WmlSection(blocks: blocks),
    ]);
  }

  void _syncDocumentAfterFormatChange() {
    final current = text;
    _suppressWord = true;
    _word.document = _documentFromText(current);
    _applyPageSetup();
    _word.relayout();
    _suppressWord = false;

    _pageCount = _word.pageCount;
    _lastKnownText = text;
    _landropService.updateEditorText(text);
    _persistConfig();
    _persistWordLater();
    notifyListeners();
    _debouncePdf(120);
  }

  void setHeading(int? level) {
    try {
      _word.applyHeading(level ?? 0);
    } catch (_) {}
    _syncDocumentAfterFormatChange();
  }

  void toggleBold() {
    _word.applyRunFormat((props) => props.bold = !props.bold);
    _syncDocumentAfterFormatChange();
  }

  void toggleItalic() {
    _word.applyRunFormat((props) => props.italic = !props.italic);
    _syncDocumentAfterFormatChange();
  }

  void toggleUnderline() {
    _word.applyRunFormat((props) {
      props.underline = props.underline == WmlUnderline.none
          ? WmlUnderline.single
          : WmlUnderline.none;
    });
    _syncDocumentAfterFormatChange();
  }

  void toggleStrike() {
    _word.applyRunFormat((props) => props.strike = !props.strike);
    _syncDocumentAfterFormatChange();
  }

  void setTextColor(String? hex) {
    final color = _normalizeHex(hex) ?? '000000';
    _word.applyRunFormat((props) => props.color = color);
    _syncDocumentAfterFormatChange();
  }

  void setHighlight(String? hex) {
    final color = _normalizeHex(hex);
    _word.applyRunFormat((props) => props.highlight = color);
    _syncDocumentAfterFormatChange();
  }

  void clearInlineFormatting() {
    _word.applyRunFormat((props) {
      props.bold = false;
      props.italic = false;
      props.underline = WmlUnderline.none;
      props.strike = false;
      props.color = '000000';
      props.highlight = null;
    });
    _syncDocumentAfterFormatChange();
  }

  void setFontSize(double size) {
    final value = size.clamp(PageConfig.minFontSize, PageConfig.maxFontSize);
    _format = _format.copyWith(fontSize: value);
    _word.applyRunFormat((props) =>
        props.fontSizeHalfPoints = (value * 2).round());
    _syncDocumentAfterFormatChange();
  }

  void setFontIndex(int index) {
    _format = _format.copyWith(selectedFontIndex: index);
    final family = FontService.instance.flutterFamily(index) ?? 'Arial';
    _word.applyRunFormat((props) {
      props.asciiFont = family;
      props.csFont = family;
    });
    _officeFonts = _buildOfficeFontSet(index);
    _updateSurfaceConfig();
    _syncDocumentAfterFormatChange();
  }

  void setAlignment(TextAlign align) {
    final normalized = align == TextAlign.justify ? TextAlign.left : align;
    _format = _format.copyWith(textAlign: normalized);
    final justification = switch (normalized) {
      TextAlign.center => WmlJustification.center,
      TextAlign.right || TextAlign.end => WmlJustification.right,
      _ => WmlJustification.left,
    };
    _word.applyParagraphFormat((props) => props.justification = justification);
    _syncDocumentAfterFormatChange();
  }

  void setLineSpacing(double spacing) {
    final value =
        spacing.clamp(PageConfig.minLineSpacing, PageConfig.maxLineSpacing);
    _format = _format.copyWith(lineSpacing: value);
    _word.applyParagraphFormat((props) {
      props.lineSpacing = value;
      props.explicitLineSpacing = true;
    });
    _syncDocumentAfterFormatChange();
  }

  void setParagraphSpacing(double spacing) {
    final value = spacing.clamp(
        PageConfig.minParagraphSpacing, PageConfig.maxParagraphSpacing);
    _format = _format.copyWith(paragraphSpacing: value);
    _word.applyParagraphFormat((props) {
      props.spacingAfter = value;
      props.spacingBefore = 0;
      props.explicitSpacingAfter = true;
    });
    _syncDocumentAfterFormatChange();
  }

  void setMarginTop(double value) {
    _format = _format.copyWith(
        marginTop: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _applyPageSetup();
    _word.relayout();
    _syncDocumentAfterFormatChange();
  }

  void setMarginBottom(double value) {
    _format = _format.copyWith(
        marginBottom: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _applyPageSetup();
    _word.relayout();
    _syncDocumentAfterFormatChange();
  }

  void setMarginLeft(double value) {
    _format = _format.copyWith(
        marginLeft: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _applyPageSetup();
    _word.relayout();
    _syncDocumentAfterFormatChange();
  }

  void setMarginRight(double value) {
    _format = _format.copyWith(
        marginRight: value.clamp(PageConfig.minMargin, PageConfig.maxMargin));
    _applyPageSetup();
    _word.relayout();
    _syncDocumentAfterFormatChange();
  }

  void setPageSizeType(PageSizeType type) {
    _format = _format.copyWith(pageSizeType: type);
    _applyPageSetup();
    _word.relayout();
    _syncDocumentAfterFormatChange();
  }

  void addHorizontalRulerMarker() {
    _format = _format.copyWith(
      rulerHorizontalMarkers: [
        ..._format.rulerHorizontalMarkers,
        0.0,
      ],
    );
    _persistConfig();
    notifyListeners();
  }

  void addVerticalRulerMarker() {
    _format = _format.copyWith(
      rulerVerticalMarkers: [
        ..._format.rulerVerticalMarkers,
        0.0,
      ],
    );
    _persistConfig();
    notifyListeners();
  }

  void clearRulerMarkers() {
    _format = _format.copyWith(
      rulerHorizontalMarkers: const <double>[],
      rulerVerticalMarkers: const <double>[],
    );
    _persistConfig();
    notifyListeners();
  }

  void updateRulerMarkers({
    List<double>? horizontal,
    List<double>? vertical,
    bool persist = false,
  }) {
    _format = _format.copyWith(
      rulerHorizontalMarkers: horizontal,
      rulerVerticalMarkers: vertical,
    );
    if (persist) {
      _persistConfig();
    }
    notifyListeners();
  }

  void setZoom(double value) {
    _zoom = value.clamp(minZoom, maxZoom);
    _word.viewport.setScale(_zoom);
    _word.viewport.origin = Offset.zero;
    _word.refresh();
    _zoom = _word.viewport.scale;
    notifyListeners();
  }

  void zoomIn() => setZoom(_zoom + 0.1);
  void zoomOut() => setZoom(_zoom - 0.1);
  void resetZoom() => setZoom(1.0);

  String? _normalizeHex(String? hex) {
    if (hex == null) return null;
    var value = hex.trim().replaceFirst('#', '').toUpperCase();
    if (value.length == 3) {
      value = value.split('').map((c) => '$c$c').join();
    }
    if (value.length == 8) value = value.substring(2);
    if (value.length != 6) return null;
    return value;
  }

  String get _wordPath {
    final dir = _landropService.downloadDir;
    return '$dir${Platform.pathSeparator}_editor_document.docx';
  }

  String get _legacyDeltaPath {
    final dir = _landropService.downloadDir;
    return '$dir${Platform.pathSeparator}_editor_document.json';
  }

  String get _legacyTextPath {
    final dir = _landropService.downloadDir;
    return '$dir${Platform.pathSeparator}_editor_autosave.txt';
  }

  String get _configPath {
    final dir = _landropService.downloadDir;
    return '$dir${Platform.pathSeparator}_editor_config.json';
  }

  void _persistWordLater() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _persistWord);
  }

  void _persistWord() {
    try {
      final dir = Directory(_landropService.downloadDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final bytes = _word.saveBytes();
      File(_wordPath).writeAsBytesSync(bytes);
      File(_legacyTextPath).writeAsStringSync(text);
    } catch (_) {}
  }

  Future<void> _loadPersistedWord() async {
    try {
      final docx = File(_wordPath);
      if (await docx.exists()) {
        _word.loadBytes(await docx.readAsBytes());
        _word.relayout();
        return;
      }
    } catch (_) {}

    String? legacy;
    try {
      final deltaFile = File(_legacyDeltaPath);
      if (await deltaFile.exists()) {
        legacy = _deltaToText(await deltaFile.readAsString());
      }
    } catch (_) {}

    if (legacy == null) {
      try {
        final textFile = File(_legacyTextPath);
        if (await textFile.exists()) {
          legacy = await textFile.readAsString();
        }
      } catch (_) {}
    }

    _word.document = _documentFromText(legacy ?? '');
    _word.relayout();
  }

  String? _deltaToText(String raw) {
    try {
      final decoded = jsonDecode(raw);
      List? delta;
      if (decoded is Map && decoded['delta'] is List) {
        delta = decoded['delta'] as List;
      } else if (decoded is List) {
        delta = decoded;
      }
      if (delta == null) return null;
      final buffer = StringBuffer();
      for (final op in delta) {
        if (op is Map && op['insert'] is String) {
          buffer.write(op['insert'] as String);
        }
      }
      var result = buffer.toString();
      if (result.endsWith('\n')) {
        result = result.substring(0, result.length - 1);
      }
      return result;
    } catch (_) {
      return null;
    }
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
        _officeFonts = _buildOfficeFontSet(_format.selectedFontIndex);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pdfDebounce?.cancel();
    _saveDebounce?.cancel();
    _word.removeListener(_onWordChanged);
    _word.dispose();
    _landropService.dispose();
    _notificationController.close();
    _imagePreviewController.close();
    super.dispose();
  }
}
