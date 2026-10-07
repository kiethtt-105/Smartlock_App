import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../widgets/ui.dart';
import 'form_pages.dart' show ErrorBox;

class _Perm {
  final String code, name, desc, scopeText;
  final bool sensitive;
  _Perm(Map<String, dynamic> j)
      : code = '${j['code']}',
        name = '${j['name'] ?? j['code']}',
        desc = '${j['description'] ?? ''}',
        scopeText = '${j['scope_text'] ?? ''}',
        sensitive = j['sensitive'] == true;
}

class _Group {
  final String name, desc;
  final List<_Perm> items;
  _Group(Map<String, dynamic> j)
      : name = '${j['name'] ?? ''}',
        desc = '${j['description'] ?? ''}',
        items = ((j['items'] as List?) ?? const []).whereType<Map>().map((e) => _Perm(e.cast<String, dynamic>())).toList();
}

class _Preset {
  final String key, label, desc;
  final List<String> codes;
  _Preset(Map<String, dynamic> j)
      : key = '${j['key']}',
        label = '${j['label'] ?? j['key']}',
        desc = '${j['desc'] ?? ''}',
        codes = ((j['codes'] as List?) ?? const []).map((e) => '$e').toList();
}

/// Chia sẻ khóa mới ([edit] == null) hoặc sửa quyền của một người đã được chia sẻ.
/// Dùng danh mục quyền từ GET /permissions/. Chỉ chủ khóa gọi được.
class ShareFormScreen extends StatefulWidget {
  final String deviceId;
  final ShareItem? edit;
  const ShareFormScreen({super.key, required this.deviceId, this.edit});
  @override
  State<ShareFormScreen> createState() => _ShareFormState();
}

class _ShareFormState extends State<ShareFormScreen> {
  final _who = TextEditingController();
  List<_Group> _groups = [];
  List<_Preset> _presets = [];
  List<String> _ownerOnly = [];
  final _sel = <String>{};
  String? _preset;
  DateTime? _expires;
  bool _loading = true, _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    if (widget.edit != null) _sel.addAll(widget.edit!.permissions);
    _loadCatalog();
  }

  @override
  void dispose() {
    _who.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final r = await api.request('GET', Endpoints.permissions);
      List<Map<String, dynamic>> list(String k) =>
          ((r[k] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      _groups = list('groups').map(_Group.new).toList();
      _presets = list('role_presets').map(_Preset.new).toList();
      _ownerOnly = ((r['owner_only_actions'] as List?) ?? const []).map((e) => '$e').toList();
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _pickPreset(_Preset p) => setState(() {
        _preset = p.key;
        _sel
          ..clear()
          ..addAll(p.codes);
      });

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: _expires ?? now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 3650)));
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 23, minute: 59));
    if (tm == null) return;
    setState(() => _expires = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
  }

  Future<void> _submit() async {
    final edit = widget.edit;
    if (edit == null && _who.text.trim().isEmpty) return setState(() => _err = 'Nhập email hoặc tên đăng nhập.');
    if (_sel.isEmpty) return setState(() => _err = 'Hãy chọn ít nhất một quyền.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (edit == null) {
        await api.request('POST', Endpoints.deviceShares(widget.deviceId), body: {
          'identifier': _who.text.trim(),
          'permissions': _sel.toList(),
          if (_expires != null) 'expires_at': _expires!.toUtc().toIso8601String(),
        });
      } else {
        await api.request('PATCH', Endpoints.share(edit.id), body: {'permissions': _sel.toList()});
      }
      await store.refresh(force: true).catchError((_) {});
      if (!mounted) return;
      toast(edit == null ? 'Đã chia sẻ khóa.' : 'Đã cập nhật quyền.');
      context.pop();
      return;
    } on ApiException catch (e) {
      _err = e.message;
    } catch (_) {
      _err = 'Đã có lỗi xảy ra, vui lòng thử lại.';
    }
    if (mounted) setState(() => _busy = false);
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final edit = widget.edit;
    return Scaffold(
      body: GlowBg(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
            Row(children: [
              RoundBtn(Icons.arrow_back_rounded, onTap: () => context.pop()),
              const SizedBox(width: 16),
              Expanded(
                  child: Text(edit == null ? 'Chia sẻ khóa' : 'Sửa quyền: ${edit.who}',
                      style: t(22, w: FontWeight.w800, ls: -.5), maxLines: 2)),
            ]),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else ...[
              if (edit == null) ...[
                TextField(
                  controller: _who,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email hoặc tên đăng nhập'),
                ),
                const SizedBox(height: 18),
              ],
              if (_presets.isNotEmpty) ...[
                Text('Vai trò mẫu', style: t(15, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in _presets)
                    ChoiceChip(label: Text(p.label), selected: _preset == p.key, onSelected: (_) => _pickPreset(p)),
                ]),
                if (_presets.any((p) => p.key == _preset))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_presets.firstWhere((p) => p.key == _preset).desc, style: t(13, color: C.sub, h: 1.4)),
                  ),
                const SizedBox(height: 18),
              ],
              Text('Quyền chi tiết (${_sel.length})', style: t(15, w: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final g in _groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Glass(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                    radius: 18,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(g.name, style: t(14.5, w: FontWeight.w700))),
                      for (final p in g.items)
                        CheckboxListTile(
                          dense: true,
                          value: _sel.contains(p.code),
                          onChanged: (v) => setState(() {
                            v == true ? _sel.add(p.code) : _sel.remove(p.code);
                            _preset = null;
                          }),
                          title: Text(p.name, style: t(14, w: FontWeight.w600, color: p.sensitive ? C.amber : C.text)),
                          subtitle: Text('${p.desc}${p.scopeText.isEmpty ? '' : ' (${p.scopeText})'}',
                              style: t(12, color: C.sub)),
                        ),
                    ]),
                  ),
                ),
              if (edit == null) ...[
                const SizedBox(height: 6),
                Glass(
                  padding: EdgeInsets.zero,
                  radius: 18,
                  child: ListTile(
                    leading: const Icon(Icons.event_rounded),
                    title: Text(_expires == null ? 'Không giới hạn thời gian' : 'Hết hạn: ${_fmt(_expires!)}',
                        style: t(14.5, w: FontWeight.w600)),
                    trailing: _expires == null
                        ? const Icon(Icons.chevron_right_rounded)
                        : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _expires = null)),
                    onTap: _pickExpiry,
                  ),
                ),
              ],
              if (_ownerOnly.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Chỉ chủ khóa làm được:\n• ${_ownerOnly.join('\n• ')}', style: t(12.5, color: C.sub, h: 1.5)),
              ],
              const SizedBox(height: 22),
              if (_err != null) ErrorBox(_err!),
              GradBtn(edit == null ? 'Chia sẻ' : 'Lưu quyền', loading: _busy, onTap: _submit),
            ],
          ]),
        ),
      ),
    );
  }
}
