import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../providers/editor_provider.dart';

/// Editable A4 page stack.
///
/// LOCKED INPUT CONTRACT: line wrapping, page flow, spaces, and cross-page
/// backspace are protected by `test/paper_input_lock_test.dart`. Do not change
/// this behavior without keeping that regression gate passing.
///
/// Every page is a real TextField. Text is paginated by the same A4 content
/// width/height used for display, so a full page automatically adds the next
/// paper page. No Scrollbar widget is used.
class TextEditorPanel extends StatefulWidget {
  final EditorProvider provider;

  const TextEditorPanel({super.key, required this.provider});

  @override
  State<TextEditorPanel> createState() => _TextEditorPanelState();
}

class _PageEditor {
  _PageEditor(String text)
      : controller = TextEditingController(text: text),
        focusNode = FocusNode();

  final TextEditingController controller;
  final FocusNode focusNode;
  final GlobalKey key = GlobalKey();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

String _displaySpaces(String value) {
  final canonical = value.replaceAll('\u00A0', ' ');
  return canonical.replaceAllMapped(
    RegExp(r' {2,}'),
    (match) => '\u00A0' * match.group(0)!.length,
  );
}

String _canonicalSpaces(String value) => value.replaceAll('\u00A0', ' ');

class _SpaceWrapFormatter extends TextInputFormatter {
  const _SpaceWrapFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final converted = _displaySpaces(newValue.text);
    if (converted == newValue.text) return newValue;
    return TextEditingValue(
      text: converted,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}

class _TextEditorPanelState extends State<TextEditorPanel> {
  static const double _pointsToPixels = 96 / 72;

  final List<_PageEditor> _pages = <_PageEditor>[];
  List<String> _pageTexts = <String>[''];
  Timer? _paginateDebounce;
  bool _editing = false;
  bool _applying = false;
  bool _didFit = false;
  String _lastKey = '';

  EditorProvider get _provider => widget.provider;

  @override
  void initState() {
    super.initState();
    final initialText = _displayText(_provider.text);
    _pageTexts = <String>[initialText];
    _pages.add(_PageEditor(initialText));
    _pages.first.controller.selection =
        const TextSelection.collapsed(offset: 0);
    _provider.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _focusPage(0, atStart: true);
      });
    });
  }

  @override
  void dispose() {
    _paginateDebounce?.cancel();
    _provider.removeListener(_onProviderChanged);
    for (final page in _pages) {
      page.dispose();
    }
    super.dispose();
  }

  String _key() {
    final f = _provider.format;
    return '${f.pageSizeType.index}|${f.pageWidth}|${f.pageHeight}|'
        '${f.marginTop}|${f.marginBottom}|${f.marginLeft}|${f.marginRight}|'
        '${f.fontSize}|${f.selectedFontIndex}|${f.lineSpacing}|'
        '${f.paragraphSpacing}|${_provider.zoom}';
  }

  String _displayText(String value) =>
      value.trim().isEmpty ? _displaySpaces(value) : value;

  String _canonicalText(String value) => _canonicalSpaces(value);

  void _onProviderChanged() {
    if (!mounted || _editing || _applying) return;
    final local = _canonicalText(_pageTexts.join());
    final textChanged = _provider.text != local;
    final geometryChanged = _key() != _lastKey;
    if (!textChanged && !geometryChanged) return;
    _schedule(
      text: _displayText(_provider.text),
      resetFocus: textChanged,
      delayMs: 0,
    );
  }

  void _schedule({
    required String text,
    required bool resetFocus,
    int delayMs = 220,
  }) {
    _paginateDebounce?.cancel();
    _paginateDebounce = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      _apply(text, resetFocus: resetFocus);
    });
  }

  List<String> _paginate(String text) {
    if (text.isEmpty) return <String>[''];

    final format = _provider.format;
    final zoom = _provider.zoom;
    final pageWidth = format.pageWidth * _pointsToPixels * zoom;
    final pageHeight = format.pageHeight * _pointsToPixels * zoom;
    final contentWidth = math.max(
      24.0,
      pageWidth -
          (format.marginLeft + format.marginRight) * _pointsToPixels * zoom -
          2.0,
    );
    final contentHeight = math.max(
      24.0,
      pageHeight -
          (format.marginTop + format.marginBottom) * _pointsToPixels * zoom -
          2.0,
    );
    final style = TextStyle(
      fontFamily: _provider.currentFontFamily,
      fontSize: format.fontSize * _pointsToPixels * zoom,
      height: format.lineSpacing,
      letterSpacing: 0,
      color: Colors.black,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final pages = <String>[];
    var start = 0;

    while (start < text.length) {
      final remaining = text.substring(start);
      final painter = TextPainter(
        text: TextSpan(text: remaining, style: style),
        textDirection: Directionality.of(context),
        textAlign: TextAlign.left,
        textScaler: scaler,
      )..layout(maxWidth: contentWidth);

      final metrics = painter.computeLineMetrics();
      if (metrics.isEmpty || painter.height <= contentHeight + 0.5) {
        pages.add(remaining);
        break;
      }

      var y = 0.0;
      var fit = 0;
      for (final line in metrics) {
        if (y + line.height > contentHeight) break;
        y += line.height;
        fit++;
      }
      if (fit >= metrics.length) {
        pages.add(remaining);
        break;
      }

      final probe = painter.getPositionForOffset(Offset(0, y + 0.25));
      final line = painter.getLineBoundary(probe);
      var end = line.start;
      if (end <= 0) end = line.end;
      if (end <= 0) end = 1;

      pages.add(remaining.substring(0, end));
      start += end;
    }

    if (pages.isEmpty) pages.add('');
    return pages;
  }

  void _apply(
    String text, {
    required bool resetFocus,
  }) {
    if (!mounted) return;
    final slices = _paginate(text);
    if (slices.isEmpty) slices.add('');
    assert(
      slices.join() == text,
      'LOCKED: paper pagination must preserve every input character',
    );

    final focusedIndex =
        _pages.indexWhere((page) => page.focusNode.hasFocus);
    var focusedOffset = focusedIndex >= 0
        ? _pages[focusedIndex].controller.selection.baseOffset
        : -1;
    if (focusedOffset < 0 && focusedIndex >= 0) {
      focusedOffset = _pages[focusedIndex].controller.text.length;
    }

    var globalCaret = 0;
    if (focusedIndex >= 0) {
      for (var i = 0; i < focusedIndex; i++) {
        globalCaret += _pages[i].controller.text.length;
      }
      globalCaret += focusedOffset;
    }

    var targetPage = 0;
    var targetOffset = 0;
    if (!resetFocus && focusedIndex >= 0) {
      var remaining = globalCaret;
      for (var i = 0; i < slices.length; i++) {
        if (remaining <= slices[i].length) {
          targetPage = i;
          targetOffset = remaining;
          break;
        }
        remaining -= slices[i].length;
        targetPage = i;
        targetOffset = slices[i].length;
      }
    }

    while (_pages.length < slices.length) {
      _pages.add(_PageEditor(''));
    }
    while (_pages.length > slices.length) {
      _pages.removeLast().dispose();
    }
    if (targetPage >= _pages.length) {
      targetPage = _pages.length - 1;
      targetOffset = _pages[targetPage].controller.text.length;
    }

    _applying = true;
    try {
      for (var i = 0; i < slices.length; i++) {
        final controller = _pages[i].controller;
        final isTarget = !resetFocus && i == targetPage;
        if (controller.text == slices[i]) {
          if (isTarget &&
              controller.selection.isValid &&
              controller.selection.baseOffset != targetOffset) {
            controller.selection =
                TextSelection.collapsed(offset: targetOffset);
          }
          continue;
        }
        controller.value = TextEditingValue(
          text: slices[i],
          selection: TextSelection.collapsed(
            offset: isTarget ? targetOffset : 0,
          ),
        );
      }
    } finally {
      _applying = false;
    }

    _pageTexts = slices;
    _lastKey = _key();
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (resetFocus) {
        _focusPage(0, atStart: true);
        return;
      }
      if (focusedIndex < 0 || targetPage >= _pages.length) return;
      if (targetPage != focusedIndex ||
          !_pages[targetPage].focusNode.hasFocus) {
        _focusPage(targetPage, offset: targetOffset);
      }
    });
  }

  void _focusPage(int index, {bool atStart = false, int? offset}) {
    if (!mounted || index < 0 || index >= _pages.length) return;
    final page = _pages[index];
    final caret = offset ?? (atStart ? 0 : null);
    if (caret != null) {
      page.controller.selection = TextSelection.collapsed(
        offset: caret.clamp(0, page.controller.text.length),
      );
    }
    page.focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      page.focusNode.requestFocus();
      final context = page.key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.08,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _backspaceToPreviousPage(int index) {
    if (index <= 0 || index >= _pages.length) return;
    final previous = _pages[index - 1];
    final text = previous.controller.text;
    if (text.isEmpty) {
      _focusPage(index - 1);
      return;
    }
    final trimmed = text.substring(0, text.length - 1);
    previous.controller.value = TextEditingValue(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
    _pageTexts[index - 1] = trimmed;
    final full = _pageTexts.join();
    _editing = true;
    try {
      _provider.setPlainText(_canonicalText(full), delayMs: 150);
    } finally {
      _editing = false;
    }
    _focusPage(index - 1, offset: trimmed.length);
    _schedule(text: full, resetFocus: false, delayMs: 0);
  }

  void _onPageChanged(int index, String value) {
    if (_applying || index < 0 || index >= _pageTexts.length) return;
    if (_pages[index].controller.text != value) return;
    if (_pageTexts[index] == value) return;
    _pageTexts[index] = value;
    final full = _pageTexts.join();
    _editing = true;
    try {
      _provider.setPlainText(_canonicalText(full), delayMs: 150);
    } finally {
      _editing = false;
    }

    // When the last character of a later page is deleted, go back to the
    // previous page automatically so backspace remains continuous.
    if (value.isEmpty && index > 0 && index - 1 < _pages.length) {
      _focusPage(
        index - 1,
        offset: _pages[index - 1].controller.text.length,
      );
    }

    // Keep every keystroke in this page until the user pauses briefly. Moving
    // focus to a newly paginated page inside onChanged can drop fast input.
    final overflowed = _paginate(value).length > 1;
    _schedule(
      text: full,
      resetFocus: false,
      delayMs: overflowed ? 0 : 220,
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = _provider.format;
    return Container(
      color: const Color(0xFF5B5B5B),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageWidth =
                    format.pageWidth * _pointsToPixels * _provider.zoom;
                final pageHeight =
                    format.pageHeight * _pointsToPixels * _provider.zoom;

                if (!_didFit) {
                  final fit = math
                      .min(
                        (constraints.maxWidth - 80) /
                            (format.pageWidth * _pointsToPixels),
                        (constraints.maxHeight - 80) /
                            (format.pageHeight * _pointsToPixels),
                      )
                      .clamp(0.35, 1.0);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _didFit) return;
                    _didFit = true;
                    _provider.setZoom(fit);
                  });
                }

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        for (var i = 0; i < _pages.length; i++) ...[
                          Center(
                            child: _buildPage(i, pageWidth, pageHeight),
                          ),
                          if (i != _pages.length - 1)
                            const SizedBox(height: 20),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, double pageWidth, double pageHeight) {
    final page = _pages[index];
    final format = _provider.format;
    page.focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final selection = page.controller.selection;
        if (event.logicalKey == LogicalKeyboardKey.backspace &&
            selection.isCollapsed &&
            selection.baseOffset == 0 &&
            index > 0) {
          _backspaceToPreviousPage(index);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    return Container(
      key: page.key,
      width: pageWidth,
      height: pageHeight,
      padding: EdgeInsets.fromLTRB(
        format.marginLeft * _pointsToPixels * _provider.zoom,
        format.marginTop * _pointsToPixels * _provider.zoom,
        format.marginRight * _pointsToPixels * _provider.zoom,
        format.marginBottom * _pointsToPixels * _provider.zoom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF9E9E9E)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: page.controller,
        focusNode: page.focusNode,
        autofocus: index == 0,
        maxLines: null,
        minLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        inputFormatters: const [_SpaceWrapFormatter()],
        textAlign: format.textAlign,
        cursorColor: Colors.black,
        style: TextStyle(
          fontFamily: _provider.currentFontFamily,
          fontSize: format.fontSize * _pointsToPixels * _provider.zoom,
          height: format.lineSpacing,
          letterSpacing: 0,
          color: Colors.black,
        ),
        scrollPhysics: const NeverScrollableScrollPhysics(),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) => _onPageChanged(index, value),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        border: Border(bottom: BorderSide(color: Color(0xFFB0B0B0))),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note, size: 18, color: Color(0xFF616161)),
          const SizedBox(width: 6),
          const Text(
            'A4 编辑',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF616161),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '共 ${_pages.length} 页',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
          ),
          const Spacer(),
          IconButton(
            tooltip: '缩小',
            icon: const Icon(Icons.zoom_out, size: 18),
            onPressed: _provider.zoomOut,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '${(_provider.zoom * 100).round()}%',
            style: const TextStyle(fontSize: 12, color: Color(0xFF616161)),
          ),
          IconButton(
            tooltip: '放大',
            icon: const Icon(Icons.zoom_in, size: 18),
            onPressed: _provider.zoomIn,
            visualDensity: VisualDensity.compact,
          ),
          TextButton(
            onPressed: _provider.resetZoom,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('1:1', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
