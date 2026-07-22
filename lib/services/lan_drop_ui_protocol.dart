import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class LanDropUiServer {
  ServerSocket? _server;
  final _receivedController = StreamController<LanDropUiReceivedFile>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final String downloadDir;
  int port;
  bool _running = false;
  int _retryCount = 0;

  Stream<LanDropUiReceivedFile> get onFileReceived => _receivedController.stream;
  Stream<String> get onStatus => _statusController.stream;
  bool get isRunning => _running;
  String? lastError;

  LanDropUiServer({required this.downloadDir, this.port = 45874});

  Future<void> start() async {
    if (_running) return;
    _retryCount = 0;
    await _tryBind();
  }

  Future<void> _tryBind() async {
    _statusController.add('binding');
    lastError = null;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _statusController.add('ready');
      _running = true;
      debugPrint('LanDropUi: listening on TCP $port');
      _server!.listen(_handleConnection);
    } catch (e) {
      lastError = e.toString();
      _statusController.add('error: $lastError');
      _retryCount++;
      if (_retryCount < 5) {
        debugPrint('LanDropUi: retry $_retryCount/5 in 3s...');
        await Future.delayed(const Duration(seconds: 3));
        await _tryBind();
      } else {
        _running = false;
        _statusController.add('failed');
      }
    }
  }

  Future<void> _handleConnection(Socket client) async {
    try {
      final result = await _readAndSave(client);
      if (result != null) {
        _receivedController.add(result);
        debugPrint('LanDropUi: received ${result.name} (${result.size} bytes)');
      }
    } catch (e) {
      debugPrint('LanDropUi: $e');
    } finally {
      try { client.destroy(); } catch (_) {}
    }
  }

  Future<LanDropUiReceivedFile?> _readAndSave(Socket client) async {
    final headerCompleter = Completer<void>();
    final dataCompleter = Completer<void>();
    final headerBuffer = <int>[];
    String? fileName;
    int? fileSize;
    
    String? pendingDataStr;
    final pendingDataBytes = <int>[];

    client.listen(
      (data) {
        if (fileSize == null) {
          headerBuffer.addAll(data);
          final text = utf8.decode(headerBuffer);
          
          if (fileName == null) {
            final idx = text.indexOf('\n');
            if (idx >= 0) {
              fileName = text.substring(0, idx).trim();
              pendingDataStr = text.substring(idx + 1);
              headerBuffer.clear();
              headerBuffer.addAll(utf8.encode(pendingDataStr!));
            }
          }
          
          if (fileName != null && fileSize == null) {
            final text2 = utf8.decode(headerBuffer);
            final idx = text2.indexOf('\n');
            if (idx >= 0) {
              final sizeStr = text2.substring(0, idx).trim();
              fileSize = int.tryParse(sizeStr);
              if (fileSize == null || fileSize! <= 0) {
                headerCompleter.complete();
                return;
              }
              pendingDataStr = text2.substring(idx + 1);
              final dataBytes = utf8.encode(pendingDataStr!);
              pendingDataBytes.addAll(dataBytes);
              headerCompleter.complete();
            }
          }
        } else {
          pendingDataBytes.addAll(data);
        }
        
        if (fileSize != null && !dataCompleter.isCompleted && 
            pendingDataBytes.length >= fileSize!) {
          dataCompleter.complete();
        }
      },
      onDone: () {
        if (!headerCompleter.isCompleted) headerCompleter.complete();
        if (!dataCompleter.isCompleted) dataCompleter.complete();
      },
      onError: (e) {
        if (!headerCompleter.isCompleted) headerCompleter.completeError(e);
        if (!dataCompleter.isCompleted) dataCompleter.completeError(e);
      },
      cancelOnError: true,
    );

    await headerCompleter.future.timeout(const Duration(seconds: 10));

    if (fileName == null || fileSize == null || fileSize! <= 0) {
      return null;
    }

    final safeName = fileName!.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final dir = Directory(downloadDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    var filePath = '${dir.path}${Platform.pathSeparator}$safeName';
    var counter = 1;
    while (File(filePath).existsSync()) {
      final dot = safeName.lastIndexOf('.');
      final base = dot > 0 ? safeName.substring(0, dot) : safeName;
      final ext = dot > 0 ? safeName.substring(dot) : '';
      filePath = '${dir.path}${Platform.pathSeparator}${base}_$counter$ext';
      counter++;
    }

    await dataCompleter.future.timeout(const Duration(seconds: 120));

    final totalPending = pendingDataBytes.length;
    final dataToWrite = totalPending >= fileSize! 
        ? pendingDataBytes.sublist(0, fileSize!) 
        : pendingDataBytes;

    await File(filePath).writeAsBytes(dataToWrite);

    return LanDropUiReceivedFile(
      path: filePath,
      name: safeName,
      size: dataToWrite.length,
      receivedAt: DateTime.now(),
    );
  }

  void stop() {
    _running = false;
    _server?.close();
    _server = null;
    _statusController.add('stopped');
  }

  void dispose() {
    stop();
    _receivedController.close();
    _statusController.close();
  }
}

class LanDropUiReceivedFile {
  final String path;
  final String name;
  final int size;
  final DateTime receivedAt;

  LanDropUiReceivedFile({required this.path, required this.name, required this.size, required this.receivedAt});

  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

Future<LanDropUiSendResult> lanDropUiSendFile({
  required String ip,
  required int port,
  required List<int> fileData,
  required String fileName,
  int timeoutMs = 10000,
}) async {
  try {
    final socket = await Socket.connect(ip, port, timeout: Duration(milliseconds: timeoutMs));
    final header = '$fileName\n${fileData.length}\n';
    socket.add(utf8.encode(header));
    socket.add(fileData);
    await socket.flush();
    await socket.close();
    return LanDropUiSendResult(success: true);
  } catch (e) {
    return LanDropUiSendResult(success: false, error: e.toString());
  }
}

class LanDropUiSendResult {
  final bool success;
  final String? error;
  LanDropUiSendResult({required this.success, this.error});
}
