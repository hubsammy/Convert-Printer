import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:convert_printer/providers/editor_provider.dart';
import 'package:convert_printer/widgets/text_editor_panel.dart';

/// Regression gate for the paper editor input contract.
///
/// These tests intentionally exercise the public paper widget rather than
/// copying its pagination logic, so changing the contract makes a test fail.
void main() {
  Future<void> pumpPaper(WidgetTester tester) async {
    final provider = EditorProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 1000,
            child: TextEditorPanel(provider: provider),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  List<TextField> fields(WidgetTester tester) =>
      tester.widgetList<TextField>(find.byType(TextField)).toList();

  testWidgets('paper input keeps endless letters and adds pages',
      (tester) async {
    await pumpPaper(tester);
    final input = fields(tester).first;
    final value =
        List<String>.filled(80, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789').join();
    await tester.enterText(find.byWidget(input), value);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final pages = fields(tester);
    expect(pages.length, greaterThan(1));
    expect(pages.map((field) => field.controller!.text).join(), value);
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('paper input keeps endless spaces and adds pages',
      (tester) async {
    await pumpPaper(tester);
    final input = fields(tester).first;
    final value = List<String>.filled(120, '          ').join();
    await tester.enterText(find.byWidget(input), value);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final pages = fields(tester);
    expect(pages.length, greaterThan(1));
    final rendered = pages
        .map((field) => field.controller!.text)
        .join()
        .replaceAll('\u00A0', ' ');
    expect(rendered, value);
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('clearing the second page returns to the first page',
      (tester) async {
    await pumpPaper(tester);
    final input = fields(tester).first;
    await tester.enterText(
      find.byWidget(input),
      List<String>.filled(
        100,
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789',
      ).join(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final pagesBefore = fields(tester);
    expect(pagesBefore.length, greaterThan(1));

    await tester.enterText(
      find.byWidget(pagesBefore.last),
      '',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fields(tester).length, lessThan(pagesBefore.length));
    await tester.pump(const Duration(milliseconds: 900));
  });
}
