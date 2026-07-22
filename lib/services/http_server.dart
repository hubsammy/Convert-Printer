import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HttpTransferServer {
  HttpServer? _httpServer;
  final int port;
  final String downloadDir;
  String? _text;
  List<int>? _pdfData;
  String? _localIp;
  bool _running = false;
  final _channels = <WebSocketChannel>{};

  final _textReceivedController = StreamController<String>.broadcast();

  Stream<String> get onTextReceived => _textReceivedController.stream;
  bool get isRunning => _running;
  int get listenPort => port;
  String get url => 'http://$_localIp:$port';

  HttpTransferServer({required this.downloadDir, this.port = 8080});

  void updateText(String text) => _text = text;
  void updatePdf(List<int> pdfData) => _pdfData = pdfData;

  Future<void> start() async {
    _localIp = await _getLocalIp();
    final router = Router();

    router.get('/', (_) => _servePage());
    router.post('/text', _handleText);
    router.post('/upload', _handleUpload);
    router.get('/files', _handleFiles);
    router.get('/file/<name>', _handleFile);
    router.get('/pdf', _handlePdf);
    router.get('/status', _handleStatus);

    final innerHandler = router.call;
    final wsHandler = webSocketHandler(_handleWs);

    final handler = const shelf.Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler((shelf.Request request) {
      if (request.headers['upgrade'] == 'websocket') {
        return wsHandler(request);
      }
      return innerHandler(request);
    });

    _httpServer = await io.serve(handler, InternetAddress.anyIPv4, port);
    _running = true;
  }

  void _handleWs(WebSocketChannel ws) {
    _channels.add(ws);
    ws.stream.listen(
      (_) {},
      onDone: () => _channels.remove(ws),
      onError: (_) => _channels.remove(ws),
    );
  }

  void notifyFile(String name, int size, String type) {
    final msg = jsonEncode({
      'type': 'file',
      'name': name,
      'size': size,
      'ftype': type,
      'time': DateTime.now().toIso8601String(),
    });
    _broadcast(msg);
  }

  void _broadcast(String msg) {
    final dead = <WebSocketChannel>[];
    for (final c in _channels) {
      try { c.sink.add(msg); } catch (_) { dead.add(c); }
    }
    _channels.removeAll(dead);
  }

  void stop() {
    _running = false;
    for (final c in _channels) c.sink.close();
    _channels.clear();
    _httpServer?.close();
  }

  shelf.Middleware _corsMiddleware() {
    return (handler) => (request) async {
      if (request.method == 'OPTIONS') {
        return shelf.Response.ok('', headers: _corsHeaders);
      }
      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  }

  Map<String, String> get _corsHeaders => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };

  Future<shelf.Response> _handleText(shelf.Request r) async {
    try {
      final body = await r.readAsString();
      final j = jsonDecode(body) as Map<String, dynamic>;
      _textReceivedController.add(j['text'] as String? ?? '');
      return shelf.Response.ok('{"ok":true}', headers: {'Content-Type': 'application/json'});
    } catch (_) {
      return shelf.Response(400, body: '{"ok":false}');
    }
  }

  Future<shelf.Response> _handleUpload(shelf.Request r) async {
    try {
      final body = await r.readAsString();
      final j = jsonDecode(body) as Map<String, dynamic>;
      final files = j['files'] as List? ?? [];
      final saved = <String>[];
      final dir = Directory(downloadDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      for (final f in files) {
        final fo = f as Map<String, dynamic>;
        final name = fo['name'] as String? ?? 'file.bin';
        final dataB64 = fo['data'] as String? ?? '';
        if (dataB64.isEmpty) continue;
        final bytes = base64Decode(dataB64);
        final safe = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
        var path = '${dir.path}${Platform.pathSeparator}$safe';
        var c = 1;
        while (File(path).existsSync()) {
          final dot = safe.lastIndexOf('.');
          final base = dot > 0 ? safe.substring(0, dot) : safe;
          final ext = dot > 0 ? safe.substring(dot) : '';
          path = '${dir.path}${Platform.pathSeparator}${base}_$c$ext';
          c++;
        }
        await File(path).writeAsBytes(bytes);
        saved.add(safe);
      }
      return shelf.Response.ok(jsonEncode({'ok': true, 'saved': saved}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return shelf.Response(400,
          body: jsonEncode({'ok': false, 'error': e.toString()}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<shelf.Response> _handleFiles(shelf.Request r) async {
    final dir = Directory(downloadDir);
    if (!await dir.exists()) {
      return shelf.Response.ok('[]', headers: {'Content-Type': 'application/json'});
    }
    final list = <Map<String, dynamic>>[];
    await for (final e in dir.list()) {
      if (e is File) {
        final st = await e.stat();
        list.add({
          'name': e.path.split(Platform.pathSeparator).last,
          'size': st.size, 'type': _fileType(e.path),
          'time': st.modified.toIso8601String(),
        });
      }
    }
    list.sort((a, b) => (b['time'] as String).compareTo(a['time'] as String));
    return shelf.Response.ok(jsonEncode(list), headers: {'Content-Type': 'application/json'});
  }

  Future<shelf.Response> _handleFile(shelf.Request r, String name) async {
    final file = File('${Directory(downloadDir).path}${Platform.pathSeparator}$name');
    if (!await file.exists()) return shelf.Response.notFound('Not found');
    return shelf.Response.ok(await file.readAsBytes(), headers: {
      'Content-Type': _mime(name),
      'Content-Disposition': 'attachment; filename="$name"',
    });
  }

  shelf.Response _handlePdf(shelf.Request r) {
    if (_pdfData == null || _pdfData!.isEmpty) return shelf.Response.notFound('No PDF');
    return shelf.Response.ok(_pdfData!, headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': 'attachment; filename="article.pdf"',
    });
  }

  shelf.Response _handleStatus(shelf.Request r) {
    return shelf.Response.ok(
      jsonEncode({'text': _text ?? '', 'connected': true}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  shelf.Response _servePage() {
    return shelf.Response.ok(_page, headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  String _fileType(String path) {
    final ext = path.toLowerCase();
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') ||
        ext.endsWith('.gif') || ext.endsWith('.webp') || ext.endsWith('.bmp')) return 'image';
    if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.flac') ||
        ext.endsWith('.aac') || ext.endsWith('.ogg') || ext.endsWith('.m4a')) return 'audio';
    if (ext.endsWith('.txt') || ext.endsWith('.md') || ext.endsWith('.json') ||
        ext.endsWith('.csv') || ext.endsWith('.xml') || ext.endsWith('.html')) return 'text';
    if (ext.endsWith('.pdf')) return 'pdf';
    return 'other';
  }

  String _mime(String n) {
    final e = n.toLowerCase();
    if (e.endsWith('.jpg') || e.endsWith('.jpeg')) return 'image/jpeg';
    if (e.endsWith('.png')) return 'image/png';
    if (e.endsWith('.gif')) return 'image/gif';
    if (e.endsWith('.webp')) return 'image/webp';
    if (e.endsWith('.mp3')) return 'audio/mpeg';
    if (e.endsWith('.wav')) return 'audio/wav';
    if (e.endsWith('.flac')) return 'audio/flac';
    if (e.endsWith('.ogg')) return 'audio/ogg';
    if (e.endsWith('.txt')) return 'text/plain';
    if (e.endsWith('.pdf')) return 'application/pdf';
    return 'application/octet-stream';
  }

  Future<String> _getLocalIp() async {
    for (final iface in await NetworkInterface.list()) {
      for (final addr in iface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) return addr.address;
      }
    }
    return '127.0.0.1';
  }

  static const _page = '''<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Cache-Control" content="no-store,no-cache,must-revalidate"><meta http-equiv="Pragma" content="no-cache"><meta http-equiv="Expires" content="0"><title>Convert Printers</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#f0f4f8;min-height:100vh;padding:12px}
.card{background:#fff;border-radius:14px;padding:18px;max-width:480px;margin:0 auto;box-shadow:0 4px 24px rgba(0,0,0,.07)}
h1{font-size:18px;color:#1565c0;text-align:center;margin-bottom:14px}
.section{margin-bottom:12px}
.section-title{font-size:12px;font-weight:600;color:#666;margin-bottom:6px;display:flex;align-items:center;gap:4px}
 textarea{width:100%;height:140px;border:2px solid #e0e0e0;border-radius:8px;padding:12px;font-size:15px;resize:vertical;outline:none}
 textarea:focus{border-color:#1565c0}
.btn{display:inline-flex;align-items:center;gap:4px;padding:10px 16px;border:none;border-radius:8px;font-size:14px;font-weight:600;cursor:pointer;transition:all .15s;background:#f5f5f5;color:#333}
.btn:active{transform:scale(.98)}
.btn-primary{background:#1565c0;color:#fff}.btn-primary:active{background:#0d47a1}
.btn-sm{padding:6px 12px;font-size:12px}
.status{font-size:11px;color:#999;margin-top:4px;min-height:16px}
.file-list{display:flex;flex-direction:column;gap:4px;max-height:260px;overflow-y:auto}
.file-row{display:flex;align-items:center;gap:8px;padding:6px 8px;background:#f8f9fa;border-radius:6px;border:1px solid #e8e8e8}
.file-row:hover{background:#e3f2fd}
.file-icon{font-size:18px;flex-shrink:0}
.file-name{flex:1;font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;cursor:pointer;color:#1565c0}
.file-name:hover{text-decoration:underline}
.file-size{font-size:10px;color:#999;flex-shrink:0}
input[type=file]{font-size:12px}
.notification{position:fixed;top:16px;left:16px;right:16px;z-index:99;display:flex;flex-direction:column;gap:8px}
.notify-card{background:#fff;border-radius:12px;padding:14px;box-shadow:0 8px 32px rgba(0,0,0,.15);border-left:4px solid #1565c0;animation:slideIn .3s ease}
@keyframes slideIn{from{transform:translateY(-40px);opacity:0}to{transform:translateY(0);opacity:1}}
.notify-title{font-size:13px;font-weight:600;color:#333;margin-bottom:4px}
.notify-meta{font-size:11px;color:#999;margin-bottom:10px}
.notify-actions{display:flex;gap:6px}
.notify-btn{padding:8px 16px;border-radius:8px;font-size:13px;font-weight:600;cursor:pointer;border:none;transition:all .15s}
.notify-dl{background:#1565c0;color:#fff}.notify-dl:active{background:#0d47a1}
.notify-ignore{background:#f5f5f5;color:#666}.notify-ignore:active{background:#e0e0e0}
</style></head><body>
<div class="notification" id="notifications"></div>
<div class="card">
<h1>Convert Printers</h1>
<div class="section">
<div class="section-title">Send Text</div>
<textarea id="textInput" placeholder="Type article..."></textarea>
<button class="btn btn-primary" id="btnSendText" style="margin-top:6px;width:100%">Send to PC</button>
<span class="status" id="status"></span>
</div>
<div class="section">
<div class="section-title">Upload Files to PC</div>
<input type="file" id="fileInput" multiple accept="image/*,audio/*,.txt,.md,.json,.csv,.xml,.html,.log,.pdf">
<div id="fileSelected" style="font-size:11px;color:#666;margin:4px 0"></div>
<button class="btn btn-primary" id="btnUpload" style="width:100%">Upload to PC</button>
<span class="status" id="uploadStatus"></span>
</div>
<div class="section">
<div class="section-title">PC Editor Preview</div>
<button class="btn btn-sm" id="btnRefreshPreview">Refresh</button>
<div class="preview" id="preview" style="background:#fafafa;border:2px solid #e0e0e0;border-radius:8px;padding:10px;min-height:40px;max-height:160px;overflow-y:auto;font-size:12px;white-space:pre-wrap;color:#555">Tap Refresh...</div>
</div>
<div class="section">
<button class="btn btn-primary" id="btnDownloadPdf" style="width:100%">Download PDF</button>
</div>
</div>
<script>
var ws;
function dlog(m){}
function c(id){return document.getElementById(id)}

function connectWs(){
  var proto=location.protocol==='https:'?'wss':'ws';
  try{ws=new WebSocket(proto+'://'+location.host+'/ws');dlog('WS connecting')}catch(e){dlog('WS error '+e)}
  ws.onopen=function(){dlog('WS connected')};
  ws.onmessage=function(e){try{var j=JSON.parse(e.data);dlog('WS msg: '+j.name);showNotification(j)}catch(ex){}}
  ws.onclose=function(){dlog('WS closed');setTimeout(connectWs,3000)}
  ws.onerror=function(){dlog('WS err');setTimeout(connectWs,3000)}
}
function showNotification(j){
  var icon=j.ftype==='image'?'[IMG]':j.ftype==='audio'?'[AUD]':j.ftype==='text'?'[TXT]':'[FILE]';
  var n=c('notifications'),id='n'+Date.now(),card=document.createElement('div');
  card.className='notify-card';card.id=id;
  card.innerHTML='<div class="notify-title">'+icon+' PC sent: '+j.name+'</div><div class="notify-meta">'+fsize(j.size)+'</div><div class="notify-actions"><button class="notify-btn notify-dl" id="dl-'+id+'">Download</button><button class="notify-btn notify-ignore" id="ig-'+id+'">Ignore</button></div>';
  n.appendChild(card);
  c('dl-'+id).addEventListener('click',function(){downloadFile(j.name);card.remove()});
  c('ig-'+id).addEventListener('click',function(){card.remove()});
  setTimeout(function(){if(c(id))c(id).remove()},15000)
}
function downloadFile(name){dlog('DL '+name);window.open('/file/'+encodeURIComponent(name))}
function fsize(s){if(s<1024)return s+' B';if(s<1048576)return (s/1024).toFixed(1)+' KB';return (s/1048576).toFixed(1)+' MB'}

function sendText(){
  var t=c('textInput').value,s=c('status');
  if(!t){s.textContent='Enter text first';return}
  s.textContent='Sending...';s.style.color='#999';dlog('sendText: '+t.substring(0,40));
  fetch('/text',{method:'POST',body:JSON.stringify({text:t}),headers:{'Content-Type':'application/json'}})
  .then(function(r){dlog('sendText HTTP '+r.status);s.textContent='Sent!';s.style.color='#4caf50'})
  .catch(function(e){dlog('sendText ERR: '+e.message);s.textContent='Error';s.style.color='red'})
}
function uploadFiles(){
  var inp=c('fileInput'),s=c('uploadStatus');
  if(!inp.files.length){s.textContent='No files';return}
  s.textContent='Uploading...';s.style.color='#999';dlog('uploadFiles: '+inp.files.length);
  var files=[],total=inp.files.length,done=0;
  function tryNext(){
    if(done>=total){
      if(!files.length){s.textContent='Read failed';return}
      fetch('/upload',{method:'POST',body:JSON.stringify({files:files}),headers:{'Content-Type':'application/json'}})
      .then(function(r){return r.json()})
      .then(function(j){dlog('upload HTTP 200');s.textContent='Done '+j.saved.length+' file(s)';s.style.color='#4caf50';inp.value='';c('fileSelected').textContent=''})
      .catch(function(e){dlog('upload ERR: '+e.message);s.textContent='Error';s.style.color='red'})
      return
    }
    var f=inp.files[done];done++;
    var reader=new FileReader();
    reader.onload=function(e){
      var arr=new Uint8Array(e.target.result),bin='';
      for(var i=0;i<arr.length;i++)bin+=String.fromCharCode(arr[i]);
      files.push({name:f.name,data:btoa(bin)});tryNext()
    };
    reader.onerror=function(){dlog('read ERR: '+f.name);tryNext()};
    reader.readAsArrayBuffer(f)
  }
  tryNext()
}
function refreshPreview(){
  fetch('/status').then(function(r){return r.json()}).then(function(j){c('preview').textContent=j.text||'(empty)';dlog('preview OK')}).catch(function(e){dlog('preview ERR: '+e.message)})
}

c('btnSendText').addEventListener('click',sendText);
c('btnUpload').addEventListener('click',uploadFiles);
c('btnRefreshPreview').addEventListener('click',refreshPreview);
c('btnDownloadPdf').addEventListener('click',function(){window.open('/pdf')});
c('fileInput').addEventListener('change',function(){var n=[];for(var i=0;i<this.files.length;i++)n.push(this.files[i].name);c('fileSelected').textContent=n.join(', ')});

connectWs();refreshPreview()
</script></body></html>''';
}
