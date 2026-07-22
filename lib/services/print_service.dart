import 'dart:typed_data';

import 'package:printing/printing.dart';

class PrintService {
  Future<void> printPdf(Uint8List pdfData, {String? fileName}) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: fileName ?? 'document.pdf',
    );
  }

  Future<void> sharePdf(Uint8List pdfData, {String? fileName}) async {
    await Printing.sharePdf(
      bytes: pdfData,
      filename: fileName ?? 'document.pdf',
    );
  }
}
