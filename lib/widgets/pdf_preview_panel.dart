import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import '../providers/editor_provider.dart';

class PdfPreviewPanel extends StatelessWidget {
  final EditorProvider provider;

  const PdfPreviewPanel({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            child: const Text(
              'PDF 预览',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF616161),
              ),
            ),
          ),
          Expanded(child: _buildPreviewContent(context)),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(BuildContext context) {
    if (!provider.isFontLoaded) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在加载字体...'),
          ],
        ),
      );
    }

    if (provider.isComputing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text('正在生成预览...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => provider.rebuildLayout(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (provider.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              '在左侧输入文本后，此处将显示 PDF 预览',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (provider.pdfData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PdfPreview(
      build: (format) => Uint8List.fromList(provider.pdfData!),
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      shouldRepaint: true,
      initialPageFormat: PdfPageFormat(
        provider.format.pageWidth,
        provider.format.pageHeight,
      ),
      scrollViewDecoration: const BoxDecoration(
        color: Color(0xFFE0E0E0),
      ),
    );
  }
}
