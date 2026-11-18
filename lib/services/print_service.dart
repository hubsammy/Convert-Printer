import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrintService {
  Future<void> printPdf(Uint8List pdfData, {String? fileName}) async {
    await Printing.layoutPdf(
      onLayout: (_) async => pdfData,
      name: fileName ?? 'document.pdf',
    );
  }

  Future<void> printImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final image = pw.MemoryImage(bytes);
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(24),
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
    await printPdf(await doc.save(), fileName: 'image.pdf');
  }

  Future<void> sharePdf(Uint8List pdfData, {String? fileName}) async {
    await Printing.sharePdf(
      bytes: pdfData,
      filename: fileName ?? 'document.pdf',
    );
  }
}
