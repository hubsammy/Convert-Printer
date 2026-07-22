import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'lan_drop_ui_protocol.dart';
import 'http_server.dart';

class LandropService {
  LanDropUiServer? _server;
  HttpTransferServer? _httpServer;
  final _statusController = StreamController<String>.broadcast();
  final _newFileController = StreamController<LandropFile>.broadcast();
  final _textReceivedController = StreamController<String>.broadcast();
  String _downloadDir = '';

  Stream<String> get onStatusChanged => _statusController.stream;
  Stream<LandropFile> get onNewFile => _newFileController.stream;
  Stream<String> get onTextReceived => _textReceivedController.stream;

  bool get isRunning => _server?.isRunning ?? false;
  String get downloadDir => _downloadDir;
  int get tcpPort => _server?.port ?? 45874;
  int get httpPort => _httpServer?.port ?? 8080;
  String get httpUrl => _httpServer?.url ?? '';
  String? get lastError => _server?.lastError;

  String get defaultDownloadDir {
    final home = Platform.environment['USERPROFILE'] ?? '';
    return '$home\\Downloads\\LANDrop';
  }

  Future<void> initialize({String? downloadPath}) async {
    _downloadDir = downloadPath ?? defaultDownloadDir;

    _server = LanDropUiServer(downloadDir: _downloadDir);

    _server!.onFileReceived.listen((file) {
      _newFileController.add(LandropFile(
        path: file.path,
        name: file.name,
        size: file.size,
        modified: file.receivedAt,
      ));
    });

    _server!.onStatus.listen((s) {
      _statusController.add(s);
    });

    await _server!.start();

    _httpServer = HttpTransferServer(downloadDir: _downloadDir);
    _httpServer!.onTextReceived.listen((text) {
      _textReceivedController.add(text);
    });
    await _httpServer!.start();
  }

  void updateEditorText(String text) => _httpServer?.updateText(text);
  void updateEditorPdf(List<int> pdfData) => _httpServer?.updatePdf(pdfData);

  Future<void> setDownloadDir(String path) async {
    _downloadDir = path;
    _server?.stop();
    _server?.dispose();
    _httpServer?.stop();

    _server = LanDropUiServer(downloadDir: _downloadDir);
    _server!.onFileReceived.listen((file) {
      _newFileController.add(LandropFile(
        path: file.path, name: file.name, size: file.size, modified: file.receivedAt,
      ));
    });
    _server!.onStatus.listen((s) => _statusController.add(s));
    await _server!.start();

    _httpServer = HttpTransferServer(downloadDir: _downloadDir);
    _httpServer!.onTextReceived.listen((text) => _textReceivedController.add(text));
    await _httpServer!.start();
  }

  Future<List<LandropFile>> listRecentFiles({int limit = 20}) async {
    final dir = Directory(_downloadDir);
    if (!await dir.exists()) return [];

    final files = <LandropFile>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = entity.path.toLowerCase();
        if (_isTextFile(ext)) {
          try {
            final stat = await entity.stat();
            files.add(LandropFile(
              path: entity.path,
              name: entity.path.split(Platform.pathSeparator).last,
              size: stat.size,
              modified: stat.modified,
            ));
          } catch (_) {}
        }
      }
    }

    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files.take(limit).toList();
  }

  Future<String?> readTextFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString(encoding: utf8);
      }
    } catch (_) {}
    return null;
  }

  Future<LanDropUiSendResult> sendToDevice({
    required String ip,
    required int port,
    required Uint8List data,
    required String fileName,
  }) async {
    return lanDropUiSendFile(
      ip: ip,
      port: port,
      fileData: data,
      fileName: fileName,
    );
  }

  Future<LanDropUiSendResult> sendPdf({
    required String ip,
    required int port,
    required Uint8List pdfData,
  }) async {
    return sendToDevice(ip: ip, port: port, data: pdfData, fileName: 'article.pdf');
  }

  Future<LanDropUiSendResult> sendText({
    required String ip,
    required int port,
    required String text,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    return sendToDevice(ip: ip, port: port, data: bytes, fileName: 'text.txt');
  }

  Future<String> sendFileToPhone(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 'File not found';

    final name = filePath.split(Platform.pathSeparator).last;
    final stat = await file.stat();
    final dest = await _copyToDownloadDir(file, name);
    _httpServer?.notifyFile(
      name,
      stat.size,
      fileType(name),
    );
    return dest;
  }

  Future<void> sendTextToPhone(String text) async {
    final dir = Directory(_downloadDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    var path = '${dir.path}${Platform.pathSeparator}text.txt';
    var c = 1;
    while (File(path).existsSync()) {
      path = '${dir.path}${Platform.pathSeparator}text_$c.txt';
      c++;
    }
    await File(path).writeAsString(text);
    _httpServer?.notifyFile(
      'text.txt',
      text.length,
      'text',
    );
  }

  Future<void> sendPdfToPhone(List<int> pdfData) async {
    final dir = Directory(_downloadDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    var path = '${dir.path}${Platform.pathSeparator}article.pdf';
    var c = 1;
    while (File(path).existsSync()) {
      path = '${dir.path}${Platform.pathSeparator}article_$c.pdf';
      c++;
    }
    await File(path).writeAsBytes(pdfData);
    _httpServer?.notifyFile(
      'article.pdf',
      pdfData.length,
      'pdf',
    );
  }

  Future<String> _copyToDownloadDir(File src, String name) async {
    final dir = Directory(_downloadDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    var dst = '${dir.path}${Platform.pathSeparator}$name';
    var c = 1;
    while (File(dst).existsSync()) {
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';
      dst = '${dir.path}${Platform.pathSeparator}${base}_$c$ext';
      c++;
    }
    await src.copy(dst);
    return dst;
  }

  Future<List<LandropFile>> listAllFiles({int limit = 50}) async {
    final dir = Directory(_downloadDir);
    if (!await dir.exists()) return [];
    final files = <LandropFile>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        try {
          final stat = await entity.stat();
          files.add(LandropFile(
            path: entity.path,
            name: entity.path.split(Platform.pathSeparator).last,
            size: stat.size,
            modified: stat.modified,
          ));
        } catch (_) {}
      }
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files.take(limit).toList();
  }

  String fileType(String name) {
    final ext = name.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') ||
        ext.endsWith('.gif') || ext.endsWith('.webp') || ext.endsWith('.bmp')) {
      return 'image';
    }
    if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.flac') ||
        ext.endsWith('.aac') || ext.endsWith('.ogg') || ext.endsWith('.m4a')) {
      return 'audio';
    }
    if (ext.endsWith('.txt') || ext.endsWith('.md') || ext.endsWith('.json') ||
        ext.endsWith('.csv') || ext.endsWith('.xml') || ext.endsWith('.html')) {
      return 'text';
    }
    if (ext.endsWith('.pdf')) return 'pdf';
    return 'other';
  }

  bool _isTextFile(String ext) {
    const textExts = {'.txt', '.md', '.json', '.csv', '.xml', '.html', '.log'};
    return textExts.any((e) => ext.endsWith(e));
  }

  void stop() {
    _statusController.add('stopped');
    _server?.stop();
    _httpServer?.stop();
  }

  void dispose() {
    stop();
    _server?.dispose();
    _statusController.close();
    _newFileController.close();
    _textReceivedController.close();
  }
}

class LandropFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;

  LandropFile({required this.path, required this.name, required this.size, required this.modified});

  String get sizeDisplay {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
