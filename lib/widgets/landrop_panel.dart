import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/editor_provider.dart';

class LandropPanel extends StatefulWidget {
  final EditorProvider provider;

  const LandropPanel({super.key, required this.provider});

  static Future<void> show(BuildContext context, EditorProvider provider) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LandropPanel(provider: provider),
    );
  }

  @override
  State<LandropPanel> createState() => _LandropPanelState();
}

class _LandropPanelState extends State<LandropPanel> {
  @override
  Widget build(BuildContext context) {
    final svc = widget.provider.landropService;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.wifi, size: 20),
          const SizedBox(width: 8),
          const Text('LAN Transfer'),
          const Spacer(),
          Icon(Icons.fiber_manual_record, size: 10,
              color: svc.isRunning ? Colors.green : Colors.red),
          const SizedBox(width: 4),
          Text(svc.isRunning ? 'Running' : 'Error',
              style: TextStyle(fontSize: 12, color: svc.isRunning ? Colors.green : Colors.red)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildServerInfo(),
            const SizedBox(height: 12),
            _buildActions(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(
          onPressed: () => _changeDir(),
          icon: const Icon(Icons.folder_open, size: 18),
          label: const Text('Change Dir'),
        ),
      ],
    );
  }

  Widget _buildServerInfo() {
    final svc = widget.provider.landropService;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: svc.isRunning ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(svc.isRunning ? Icons.check_circle : Icons.error,
                  size: 18, color: svc.isRunning ? Colors.green : Colors.red),
              const SizedBox(width: 6),
              Text(svc.isRunning ? 'Service RUNNING' : 'Service STOPPED',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,
                      color: svc.isRunning ? Colors.green : Colors.red)),
            ],
          ),
          const SizedBox(height: 6),
          Text('TCP: ${svc.tcpPort}  |  HTTP: ${svc.httpUrl}',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          if (svc.httpUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: QrImageView(
                data: svc.httpUrl,
                version: QrVersions.auto,
                size: 100,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(svc.httpUrl,
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      textAlign: TextAlign.center),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy URL',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: svc.httpUrl));
                    _snack('URL copied');
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(height: 34,
            child: OutlinedButton.icon(
              onPressed: _sendTextToPhone,
              icon: const Icon(Icons.text_snippet, size: 16),
              label: const Text('Send Text', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: SizedBox(height: 34,
            child: OutlinedButton.icon(
              onPressed: _sendPdfToPhone,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send PDF', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: SizedBox(height: 34,
            child: OutlinedButton.icon(
              onPressed: _sendFileToPhone,
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Send File', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendTextToPhone() async {
    final text = widget.provider.text;
    if (text.isEmpty) { _snack('Editor is empty'); return; }
    await widget.provider.landropService.sendTextToPhone(text);
    _snack('Text sent to phone');
  }

  Future<void> _sendPdfToPhone() async {
    final pdf = widget.provider.pdfData;
    if (pdf == null) { _snack('No PDF generated'); return; }
    await widget.provider.landropService.sendPdfToPhone(pdf.toList());
    _snack('PDF sent to phone');
  }

  Future<void> _sendFileToPhone() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        r'Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.OpenFileDialog; $f.Filter = "All Files|*.*"; $f.Multiselect = $false; if ($f.ShowDialog() -eq "OK") { $f.FileName }',
      ]);
      final path = result.stdout.toString().trim();
      if (path.isEmpty) return;
      final name = path.split(Platform.pathSeparator).last;
      await widget.provider.landropService.sendFileToPhone(path);
      _snack('$name sent to phone');
    } catch (_) {}
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 12)),
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _changeDir() async {
    final ctrl = TextEditingController(text: widget.provider.landropService.downloadDir);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download Directory'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Path')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await widget.provider.landropService.setDownloadDir(result);
    }
  }
}
