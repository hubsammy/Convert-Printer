import 'dart:typed_data';

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

  Future<PdfDocumentResult> generate(String text, FormatConfig config) async {
    final font = _selectedFont(config);
    final clean = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final doc = pw.Document(
      pageMode: PdfPageMode.outlines,
    );

    final paragraphs = clean.split('\n');
    final widgets = <pw.Widget>[];

    for (var i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];

      if (p.isEmpty && i > 0) {
        widgets.add(pw.SizedBox(height: config.paragraphSpacing));
        continue;
      }

      widgets.add(
        pw.Align(
          alignment: _mapAlignment(config.textAlign),
          child: pw.Text(
            p.isEmpty ? ' ' : p,
            style: pw.TextStyle(
              font: font,
              fontNormal: font,
              fontBold: font,
              fontFallback: [font],
              fontSize: config.fontSize,
              lineSpacing: config.lineSpacing,
            ),
            textAlign: _mapTextAlign(config.textAlign),
          ),
        ),
      );

      if (i < paragraphs.length - 1 && config.paragraphSpacing > 0) {
        widgets.add(pw.SizedBox(height: config.paragraphSpacing));
      }
    }

    var totalPages = 1;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(
          config.pageWidth,
          config.pageHeight,
        ),
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

    return PdfDocumentResult(
      pdfData: pdfData,
      totalPages: totalPages,
    );
  }

  pw.TextAlign _mapTextAlign(dynamic align) {
    switch (align.toString()) {
      case 'TextAlign.center':
        return pw.TextAlign.center;
      case 'TextAlign.right':
        return pw.TextAlign.right;
      case 'TextAlign.justify':
        return pw.TextAlign.justify;
      case 'TextAlign.start':
        return pw.TextAlign.left;
      case 'TextAlign.end':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }

  pw.Alignment _mapAlignment(dynamic align) {
    switch (align.toString()) {
      case 'TextAlign.center':
        return pw.Alignment.center;
      case 'TextAlign.right':
        return pw.Alignment.centerRight;
      case 'TextAlign.justify':
        return pw.Alignment.centerLeft;
      case 'TextAlign.start':
        return pw.Alignment.centerLeft;
      case 'TextAlign.end':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }
}

class PdfDocumentResult {
  final Uint8List pdfData;
  final int totalPages;

  PdfDocumentResult({required this.pdfData, required this.totalPages});
}
