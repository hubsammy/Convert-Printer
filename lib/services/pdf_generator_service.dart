import 'dart:typed_data';
import 'dart:ui' show TextAlign;

import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/page_config.dart';
import '../models/format_config.dart';

class PdfGeneratorService {
  final List<pw.Font> _fonts;

  PdfGeneratorService(this._fonts);

  pw.Font _selectedFont(FormatConfig config) {
    final idx = config.selectedFontIndex.clamp(0, _fonts.length - 1);
    return _fonts[idx];
  }

  Future<PdfDocumentResult> generate(
      Document document, FormatConfig config) async {
    final font = _selectedFont(config);
    final blocks = _parseBlocks(document.toDelta().toList());
    final baseSize = config.fontSize;
    final widgets = <pw.Widget>[];
    var orderedCounter = 0;

    for (final block in blocks) {
      final listType = block.attrs['list'] as String?;
      if (listType != 'ordered') orderedCounter = 0;

      var prefix = '';
      if (listType == 'bullet') {
        prefix = '-  ';
      } else if (listType == 'checked') {
        prefix = '[x]  ';
      } else if (listType == 'unchecked') {
        prefix = '[ ]  ';
      } else if (listType == 'ordered') {
        orderedCounter++;
        prefix = '$orderedCounter.  ';
      }

      if (block.runs.isEmpty && prefix.isEmpty) {
        widgets.add(pw.SizedBox(height: baseSize * config.lineSpacing));
        continue;
      }

      widgets.add(_buildParagraph(block, prefix, config, font, baseSize));

      if (config.paragraphSpacing > 0) {
        widgets.add(pw.SizedBox(height: config.paragraphSpacing));
      }
    }

    if (widgets.isEmpty) {
      widgets.add(pw.SizedBox(height: baseSize * config.lineSpacing));
    }

    var totalPages = 1;

    final doc = pw.Document(pageMode: PdfPageMode.outlines);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(config.pageWidth, config.pageHeight),
        margin: pw.EdgeInsets.fromLTRB(
          config.marginLeft,
          config.marginTop,
          config.marginRight,
          config.marginBottom + PageConfig.footerHeight,
        ),
        build: (pw.Context context) => widgets,
        footer: (pw.Context context) {
          totalPages = context.pagesCount;
          return pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(
                font: font,
                fontNormal: font,
                fontSize: PageConfig.footerFontSize,
                color: PdfColors.grey600,
              ),
            ),
          );
        },
      ),
    );

    final pdfData = await doc.save();

    return PdfDocumentResult(pdfData: pdfData, totalPages: totalPages);
  }

  pw.Widget _buildParagraph(_Block block, String prefix, FormatConfig config,
      pw.Font font, double baseSize) {
    final header = _headerLevel(block.attrs);
    final paragraphSize = header == null
        ? baseSize
        : baseSize * _headerScale(header);
    final forceBold = header != null;

    final spans = <pw.InlineSpan>[];
    if (prefix.isNotEmpty) {
      spans.add(pw.TextSpan(
        text: prefix,
        style: _runStyle(const <String, dynamic>{}, paragraphSize, config, font,
            forceBold),
      ));
    }
    for (final run in block.runs) {
      spans.add(pw.TextSpan(
        text: run.text,
        style: _runStyle(
            run.attrs, paragraphSize, config, font, forceBold),
      ));
    }

    return pw.RichText(
      text: pw.TextSpan(children: spans),
      textAlign: _alignFor(block.attrs, config.textAlign),
    );
  }

  pw.TextStyle _runStyle(Map<String, dynamic> attrs, double baseSize,
      FormatConfig config, pw.Font font, bool forceBold) {
    final bold = forceBold || attrs['bold'] == true;
    final italic = attrs['italic'] == true;
    final underline = attrs['underline'] == true;
    final strike = attrs['strike'] == true;

    var size = baseSize;
    final rawSize = attrs['size'];
    if (rawSize is num) {
      size = rawSize.toDouble();
    } else if (rawSize is String) {
      size = double.tryParse(rawSize) ?? baseSize;
    }

    final color = _parseColor(attrs['color']);
    final background = _parseColor(attrs['background']);

    final decorations = <pw.TextDecoration>[];
    if (underline) decorations.add(pw.TextDecoration.underline);
    if (strike) decorations.add(pw.TextDecoration.lineThrough);

    pw.TextDecoration? decoration;
    if (decorations.length == 1) {
      decoration = decorations.first;
    } else if (decorations.length > 1) {
      decoration = pw.TextDecoration.combine(decorations);
    }

    return pw.TextStyle(
      font: font,
      fontNormal: font,
      fontBold: font,
      fontItalic: font,
      fontBoldItalic: font,
      fontFallback: [font],
      fontSize: size,
      lineSpacing: config.lineSpacing,
      fontWeight: bold ? pw.FontWeight.bold : null,
      fontStyle: italic ? pw.FontStyle.italic : null,
      color: color,
      background: background != null
          ? pw.BoxDecoration(color: background)
          : null,
      decoration: decoration,
    );
  }

  List<_Block> _parseBlocks(List<dynamic> operations) {
    final blocks = <_Block>[];
    var runs = <_Run>[];

    for (final op in operations) {
      final data = op.data;
      final rawAttrs = op.attributes;
      final attrs = <String, dynamic>{
        if (rawAttrs is Map) ...rawAttrs.cast<String, dynamic>(),
      };

      if (data is String) {
        final parts = data.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            runs.add(_Run(parts[i], attrs));
          }
          if (i < parts.length - 1) {
            blocks.add(_Block(List<_Run>.unmodifiable(runs), attrs));
            runs = <_Run>[];
          }
        }
      } else {
        runs.add(_Run('[未支持的嵌入内容]', const <String, dynamic>{}));
      }
    }

    if (runs.isNotEmpty) {
      blocks.add(_Block(List<_Run>.unmodifiable(runs), const <String, dynamic>{}));
    }
    if (blocks.isEmpty) {
      blocks.add(const _Block(<_Run>[], <String, dynamic>{}));
    }
    return blocks;
  }

  int? _headerLevel(Map<String, dynamic> attrs) {
    final value = attrs['header'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  double _headerScale(int level) {
    switch (level) {
      case 1:
        return 2.0;
      case 2:
        return 1.6;
      case 3:
        return 1.35;
      case 4:
        return 1.2;
      case 5:
        return 1.1;
      default:
        return 1.0;
    }
  }

  PdfColor? _parseColor(dynamic value) {
    if (value is! String) return null;
    var hex = value.trim();
    if (hex.isEmpty) return null;
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length != 3 && hex.length != 6 && hex.length != 8) return null;
    try {
      return PdfColor.fromHex(hex);
    } catch (_) {
      return null;
    }
  }

  pw.TextAlign _alignFor(Map<String, dynamic> attrs, TextAlign fallback) {
    switch (attrs['align'] as String?) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      case 'justify':
        return pw.TextAlign.justify;
      case 'left':
        return pw.TextAlign.left;
    }
    switch (fallback) {
      case TextAlign.center:
        return pw.TextAlign.center;
      case TextAlign.right:
      case TextAlign.end:
        return pw.TextAlign.right;
      case TextAlign.justify:
        return pw.TextAlign.justify;
      default:
        return pw.TextAlign.left;
    }
  }

  Future<PdfDocumentResult> generateImagePdf(
      Uint8List imageBytes, String name) async {
    final doc = pw.Document();
    final img = pw.MemoryImage(imageBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Center(
            child: pw.Image(img, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    final pdfData = await doc.save();
    return PdfDocumentResult(pdfData: pdfData, totalPages: 1);
  }
}

class _Run {
  final String text;
  final Map<String, dynamic> attrs;

  const _Run(this.text, this.attrs);
}

class _Block {
  final List<_Run> runs;
  final Map<String, dynamic> attrs;

  const _Block(this.runs, this.attrs);
}

class PdfDocumentResult {
  final Uint8List pdfData;
  final int totalPages;

  PdfDocumentResult({required this.pdfData, required this.totalPages});
}
