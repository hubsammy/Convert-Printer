import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../providers/editor_provider.dart';
import '../services/landrop_service.dart';

/// LAN transfer controls shown in the QR transfer dialog.
class LanTransferPanel extends StatefulWidget {
  final EditorProvider provider;
  final VoidCallback? onTransferComplete;

  const LanTransferPanel({
    super.key,
    required this.provider,
    this.onTransferComplete,
  });

  @override
  State<LanTransferPanel> createState() => _LanTransferPanelState();
}

class _LanTransferPanelState extends State<LanTransferPanel> {
  StreamSubscription<String>? _textSubscription;
  StreamSubscription<LandropFile>? _fileSubscription;

  @override
  void initState() {
    super.initState();
    _textSubscription =
        widget.provider.landropService.onTextReceived.listen((_) {
      _completeTransfer();
    });
    _fileSubscription = widget.provider.landropService.onNewFile.listen((_) {
      _completeTransfer();
    });
  }

  void _completeTransfer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTransferComplete?.call();
    });
  }

  @override
  void dispose() {
    _textSubscription?.cancel();
    _fileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.provider.landropService;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 6),
              const Text(
                '局域网传输',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(
                Icons.fiber_manual_record,
                size: 10,
                color: svc.isRunning ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                svc.isRunning ? '运行中' : '未运行',
                style: TextStyle(
                  fontSize: 12,
                  color: svc.isRunning ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildServerInfo(),
          const SizedBox(height: 12),
          _buildActions(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _changeDir,
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('修改接收目录', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(34),
            ),
          ),
        ],
      ),
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
              Icon(
                svc.isRunning ? Icons.check_circle : Icons.error,
                size: 16,
                color: svc.isRunning ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 6),
              Text(
                svc.isRunning ? '服务运行中' : '服务未运行',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: svc.isRunning ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'TCP: ${svc.tcpPort}  |  HTTP: ${svc.httpUrl}',
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
          if (svc.httpUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: svc.httpUrl,
                  version: QrVersions.auto,
                  size: 120,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    svc.httpUrl,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: '复制地址',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: svc.httpUrl));
                    _snack('地址已复制');
                  },
                ),
              ],
            ),
            const Text(
              '手机扫码打开传输页，可发送文字/文件到电脑',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
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
          child: SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: _sendTextToPhone,
              icon: const Icon(Icons.text_snippet, size: 16),
              label: const Text('发文字', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: _sendFileToPhone,
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('发文件', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendTextToPhone() async {
    final text = widget.provider.text;
    if (text.isEmpty) {
      _snack('编辑器内容为空');
      return;
    }
    await widget.provider.landropService.sendTextToPhone(text);
    _snack('文字已发送到手机');
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
      _snack('$name 已发送到手机');
    } catch (_) {}
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _changeDir() async {
    final ctrl = TextEditingController(
      text: widget.provider.landropService.downloadDir,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('接收目录'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '路径'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await widget.provider.landropService.setDownloadDir(result);
    }
  }
}
