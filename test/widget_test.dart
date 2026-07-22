import 'package:flutter_test/flutter_test.dart';

import 'package:convert_printers/app.dart';

void main() {
  testWidgets('App renders toolbar and panels', (WidgetTester tester) async {
    await tester.pumpWidget(const PdfGeneratorApp());
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('PDF 预览'), findsOneWidget);
    expect(find.text('文本编辑'), findsOneWidget);
  });
}
