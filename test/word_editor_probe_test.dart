import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quds_office_editor/quds_office_editor.dart';

import 'package:convert_printer/services/font_service.dart';

void main() {
  testWidgets('paginated word editor builds and paginates chinese text',
      (tester) async {
    try {
      await OfficeHostFonts.ensureRegistered();
    } catch (_) {}

    final WmlDocument document = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            for (int i = 0; i < 300; i++)
              WmlParagraph(
                inlines: <WmlInline>[WmlRun(text: '第$i行 中文测试文字内容')],
              ),
          ],
        ),
      ],
    );

    final controller = WordEditorController(
      document: document,
      config: const OfficeSurfaceConfig(
        theme: OfficeTheme.light,
        showRulers: false,
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 900,
            child: QudsWordEditor(controller: controller),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.pageCount, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  test('word pdf export embeds chinese fonts', () async {
    await FontService.instance.loadAll();
    final fonts = <SfntFont>[];
    for (var i = 0; i < FontService.fontList.length; i++) {
      final bytes = FontService.instance.bytesForIndex(i);
      if (bytes == null) continue;
      try {
        fonts.add(SfntFont.parse(bytes));
      } catch (_) {}
    }
    expect(fonts, isNotEmpty);

    final document = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            for (int i = 0; i < 300; i++)
              WmlParagraph(
                inlines: <WmlInline>[WmlRun(text: '第$i行 中文测试文字内容')],
              ),
          ],
        ),
      ],
    );

    final controller = WordEditorController(document: document);
    addTearDown(controller.dispose);

    final pdf = controller.exportPdf(
      fonts: OfficeFontSet(
        primary: fonts.first,
        fallbacks: fonts.skip(1).toList(),
      ),
    );

    expect(pdf.length, greaterThan(1000));
    expect(controller.pageCount, greaterThan(1));
  });

  testWidgets('mixed run sizes reserve the tallest line', (tester) async {
    final document = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(
              inlines: <WmlInline>[
                WmlRun(
                  text: 'small ',
                  properties: WmlRunProps(fontSizeHalfPoints: 28),
                ),
                WmlRun(
                  text: 'BIG',
                  properties: WmlRunProps(fontSizeHalfPoints: 144),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final controller = WordEditorController(document: document);
    addTearDown(controller.dispose);

    final lines = controller.documentLaidOut.pages
        .expand((page) => page.lines)
        .toList();
    expect(lines, isNotEmpty);

    var maxHeight = 0.0;
    for (final line in lines) {
      if (line.height > maxHeight) maxHeight = line.height;
    }
    expect(maxHeight, greaterThan(80));
  });

  testWidgets('long CJK text wraps inside the page width', (tester) async {
    await FontService.instance.loadAll();
    final family = FontService.instance.flutterFamily(0) ?? 'Arial';

    final document = WmlDocument(
      sections: <WmlSection>[
        WmlSection(
          blocks: <WmlBlock>[
            WmlParagraph(
              inlines: <WmlInline>[
                WmlRun(
                  text: '汉' * 300,
                  properties: WmlRunProps(
                    asciiFont: family,
                    csFont: family,
                    fontSizeHalfPoints: 48,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final controller = WordEditorController(document: document);
    addTearDown(controller.dispose);

    final pages = controller.documentLaidOut.pages;
    final lines = pages.expand((page) => page.lines).toList();
    expect(lines.length, greaterThan(1));

    final contentWidth = controller.document.sections.first.contentWidth;
    for (final line in lines) {
      expect(line.width, lessThanOrEqualTo(contentWidth + 1));
    }
  });
}
