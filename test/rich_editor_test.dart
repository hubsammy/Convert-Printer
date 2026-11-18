import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:convert_printer/models/format_config.dart';
import 'package:convert_printer/services/font_service.dart';
import 'package:convert_printer/services/pdf_generator_service.dart';

void main() {
  testWidgets('rich delta renders to a PDF', (tester) async {
    final document = Document.fromJson([
      {
        'insert': 'Heading',
        'attributes': {'header': 1},
      },
      {'insert': '\n'},
      {
        'insert': 'plain ',
      },
      {
        'insert': 'bold',
        'attributes': {'bold': true},
      },
      {
        'insert': ' red',
        'attributes': {'color': '#d32f2f', 'underline': true},
      },
      {
        'insert': ' marked',
        'attributes': {'background': '#fff59d'},
      },
      {'insert': '\n', 'attributes': {'align': 'center'}},
    ]);

    final service = PdfGeneratorService([pw.Font.helvetica()]);
    final result = await service.generate(document, FormatConfig());

    expect(result.pdfData, isNotEmpty);
    expect(result.totalPages, greaterThanOrEqualTo(1));
  });

  testWidgets('chinese rich text generates a PDF with embedded font', (tester) async {
    await FontService.instance.loadAll();
    final fonts = FontService.instance.loadedFonts
        .map((data) => pw.Font.ttf(data.buffer.asByteData()))
        .toList();
    expect(fonts, isNotEmpty);

    final document = Document.fromJson([
      {
        'insert': '标题',
        'attributes': {'header': 1},
      },
      {'insert': '\n'},
      {'insert': '中文正文 '},
      {
        'insert': '加粗',
        'attributes': {'bold': true, 'color': '#1565c0'},
      },
      {
        'insert': '高亮',
        'attributes': {'background': '#fff59d', 'underline': true},
      },
      {'insert': '\n', 'attributes': {'align': 'justify', 'list': 'bullet'}},
    ]);

    final result =
        await PdfGeneratorService(fonts).generate(document, FormatConfig());

    expect(result.pdfData.length, greaterThan(1000));
    expect(result.totalPages, greaterThanOrEqualTo(1));
  });

  testWidgets('long document produces multiple PDF pages', (tester) async {
    await FontService.instance.loadAll();
    final fonts = FontService.instance.loadedFonts
        .map((data) => pw.Font.ttf(data.buffer.asByteData()))
        .toList();
    expect(fonts, isNotEmpty);

    final text =
        '${List.generate(300, (i) => '第$i行 测试文字内容').join('\n')}\n';
    final document = Document.fromJson([
      {'insert': text},
    ]);

    final result =
        await PdfGeneratorService(fonts).generate(document, FormatConfig());

    expect(result.totalPages, greaterThan(1));
  });

  testWidgets('quill editor builds inside a page surface', (tester) async {
    final controller = QuillController.basic();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates:
            FlutterQuillLocalizations.localizationsDelegates,
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Container(
              width: 400,
              height: 500,
              color: Colors.white,
              child: QuillEditor.basic(
                controller: controller,
                config: const QuillEditorConfig(expands: true),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
