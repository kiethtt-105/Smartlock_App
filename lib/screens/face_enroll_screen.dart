import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/api_client.dart';
import '../core/config_service.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../widgets/ui.dart';
import 'form_pages.dart' show ErrorBox;

/// Đăng ký khuôn mặt bằng camera điện thoại.
///
/// Server (services.enroll_face) cần vector 128 chiều của face-api.js (dlib ResNet), cùng mô hình với bên so khớp
/// ở camera. Nên trang quét chạy ĐÚNG face-api.js như web (trong WebView, mô hình tải từ jsDelivr), chỉ gửi
/// vector về Flutter qua JavaScriptChannel; Flutter gọi POST /devices/<id>/faces/ bằng Bearer token.
/// Ảnh chỉ xử lý trong WebView, không rời máy.
class FaceEnrollScreen extends StatefulWidget {
  final String deviceId;
  const FaceEnrollScreen({super.key, required this.deviceId});
  @override
  State<FaceEnrollScreen> createState() => _FaceEnrollState();
}

class _FaceEnrollState extends State<FaceEnrollScreen> {
  final _name = TextEditingController();
  bool _consent = false, _scanning = false, _saving = false;
  String? _err, _status;
  WebViewController? _web;

  Device? get _dev {
    for (final d in store.devices) {
      if (d.id == widget.deviceId) return d;
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_consent) return setState(() => _err = 'Hãy tích xác nhận người được quét đã đồng ý.');
    final origin = ConfigService.baseUrl.isEmpty ? '' : Uri.parse(ConfigService.baseUrl).origin;
    if (!origin.startsWith('https://')) {
      return setState(() => _err = 'Camera chỉ dùng được khi server chạy HTTPS (hiện tại: ${origin.isEmpty ? 'chưa cấu hình' : origin}).');
    }
    var st = await Permission.camera.request();
    if (!st.isGranted) {
      if (st.isPermanentlyDenied) {
        await openAppSettings();
      }
      return setState(() => _err = 'Bạn chưa cho phép dùng camera. Bật quyền Camera cho app trong Cài đặt rồi thử lại.');
    }
    final need = store.faceMinFrames;
    final c = WebViewController(onPermissionRequest: (req) => req.grant())
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(C.bg)
      ..addJavaScriptChannel('Flutter', onMessageReceived: (m) => _onMessage(m.message))
      ..loadHtmlString(_html.replaceFirst('__NEED__', '$need'), baseUrl: origin);
    setState(() {
      _err = null;
      _status = 'Đang tải mô hình nhận diện (lần đầu mất vài giây)…';
      _web = c;
      _scanning = true;
    });
  }

  void _stop() => setState(() {
        _scanning = false;
        _web = null;
      });

  Future<void> _onMessage(String raw) async {
    Map<String, dynamic> m;
    try {
      m = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    switch (m['type']) {
      case 'status':
        setState(() => _status = '${m['text']}');
      case 'error':
        _stop();
        setState(() => _err = switch ('${m['code']}') {
              'DENIED' => 'Camera bị từ chối. Cấp quyền Camera cho app rồi thử lại.',
              'NO_LIB' => 'Không tải được thư viện nhận diện. Kiểm tra mạng rồi thử lại.',
              'NO_MEDIA' => 'WebView không mở được camera (cần HTTPS).',
              'TIMEOUT' => 'Không quét đủ khung hình. Lại gần camera, đủ sáng, chỉ một người trong khung.',
              final c => 'Lỗi khi quét: $c',
            });
      case 'vectors':
        _stop();
        await _save(m['data']);
    }
  }

  Future<void> _save(dynamic vectors) async {
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final name = _name.text.trim();
      await api.request('POST', Endpoints.deviceFaces(widget.deviceId), body: {
        if (name.isNotEmpty) 'name': name,
        'consent_confirmed': true,
        'embeddings': vectors,
      });
      await store.refresh(force: true).catchError((_) {});
      if (!mounted) return;
      toast('Đã đăng ký khuôn mặt.');
      context.pop();
      return;
    } on ApiException catch (e) {
      _err = e.message;
    } catch (_) {
      _err = 'Đã có lỗi xảy ra, vui lòng thử lại.';
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
              Row(children: [
                RoundBtn(Icons.arrow_back_rounded, onTap: () => context.pop()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Đăng ký khuôn mặt', style: t(22, w: FontWeight.w800, ls: -.5)),
                    if (_dev != null) Text(_dev!.name, style: t(12.5, color: C.sub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              if (_scanning && _web != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(height: 420, child: WebViewWidget(controller: _web!)),
                ),
                const SizedBox(height: 12),
                if (_status != null)
                  Text(_status!, style: t(14, color: C.sub), textAlign: TextAlign.center),
                const SizedBox(height: 14),
                GradBtn('Huỷ quét', filled: false, onTap: _stop),
              ] else ...[
                Text('Nhìn thẳng vào camera, đủ sáng, chỉ một người trong khung. Ảnh chỉ xử lý trên điện thoại; '
                    'chỉ vector đặc trưng được gửi lên server.',
                    style: t(14, color: C.sub, h: 1.45)),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị (vd: Bố, Khách phòng 2)', counterText: ''),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v == true),
                  title: Text('Người được quét đã đồng ý cho thu thập dữ liệu khuôn mặt (NĐ 13/2023).',
                      style: t(13.5, h: 1.35)),
                ),
                const SizedBox(height: 14),
                if (_err != null) ErrorBox(_err!),
                GradBtn('Quét khuôn mặt', icon: Icons.face_retouching_natural_rounded, loading: _saving, onTap: _start),
              ],
            ]),
          ),
        ),
      );
}

/// Trang quét chạy trong WebView. Cùng thông số với web (_face_enroll.html): TinyFaceDetector 320 / 0.6,
/// đúng 1 khuôn mặt chiếm >= 25% bề ngang khung hình, 25 giây tối đa. __NEED__ = số khung tối thiểu (meta.face_min_frames).
const _html = r'''<!doctype html>
<html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>
html,body{margin:0;height:100%;background:#0A0B10;color:#F2F4FA;font-family:-apple-system,Roboto,sans-serif}
#w{display:flex;flex-direction:column;align-items:center;justify-content:center;height:100%;padding:12px;box-sizing:border-box}
video{width:100%;max-height:82%;object-fit:cover;border-radius:16px;background:#000;transform:scaleX(-1)}
#s{padding:12px 6px;text-align:center;font-size:15px;line-height:1.4}
</style></head><body>
<div id="w"><video id="v" playsinline muted autoplay></video><div id="s">Đang tải mô hình nhận diện…</div></div>
<script src="https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.13/dist/face-api.js"></script>
<script>
(function () {
  var NEED = __NEED__;
  var MODEL_URL = 'https://cdn.jsdelivr.net/npm/@vladmandic/face-api@1.7.13/model/';
  var video = document.getElementById('v'), st = document.getElementById('s');
  function send(o) { try { Flutter.postMessage(JSON.stringify(o)); } catch (e) {} }
  function say(t) { st.textContent = t; send({type: 'status', text: t}); }
  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
  async function run() {
    var stream = null;
    try {
      if (typeof faceapi === 'undefined') throw new Error('NO_LIB');
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) throw new Error('NO_MEDIA');
      await Promise.all([
        faceapi.nets.tinyFaceDetector.loadFromUri(MODEL_URL),
        faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL),
        faceapi.nets.faceRecognitionNet.loadFromUri(MODEL_URL)
      ]);
      stream = await navigator.mediaDevices.getUserMedia({video: {facingMode: 'user', width: 640}});
      video.srcObject = stream;
      await video.play();
      var opts = new faceapi.TinyFaceDetectorOptions({inputSize: 320, scoreThreshold: 0.6});
      var vectors = [], deadline = Date.now() + 25000;
      say('Nhìn thẳng vào camera, giữ yên mặt…');
      while (vectors.length < NEED && Date.now() < deadline) {
        var found = await faceapi.detectAllFaces(video, opts).withFaceLandmarks().withFaceDescriptors();
        if (found.length === 1 && found[0].detection.box.width >= video.videoWidth * 0.25) {
          vectors.push(Array.from(found[0].descriptor).map(function (x) { return Math.round(x * 1e6) / 1e6; }));
          say('Đã lấy ' + vectors.length + '/' + NEED + ' khung hình…');
          await sleep(400);
        } else if (found.length > 1) {
          say('Có nhiều hơn một khuôn mặt trong khung, chỉ để một người.');
          await sleep(300);
        } else {
          say('Chưa thấy rõ mặt: lại gần camera, đủ sáng.');
          await sleep(300);
        }
      }
      if (vectors.length < NEED) { send({type: 'error', code: 'TIMEOUT'}); return; }
      send({type: 'vectors', data: vectors});
    } catch (e) {
      send({type: 'error', code: (e && e.name === 'NotAllowedError') ? 'DENIED' : ((e && e.message) || 'ERR')});
    } finally {
      if (stream) stream.getTracks().forEach(function (t) { t.stop(); });
    }
  }
  run();
})();
</script></body></html>''';
