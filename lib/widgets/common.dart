import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.line),
          boxShadow: const [BoxShadow(color: Color(0x0F0F172A), blurRadius: 16, offset: Offset(0, 4), spreadRadius: -8)],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(padding: padding, child: child)),
        ),
      );
}

enum Kind { ok, bad, warn, info, mute }

extension KindX on Kind {
  Color get fg => switch (this) {
        Kind.ok => C.ok, Kind.bad => C.bad, Kind.warn => C.warn, Kind.info => C.info, Kind.mute => C.muted };
  Color get bg => switch (this) {
        Kind.ok => C.okBg, Kind.bad => C.badBg, Kind.warn => C.warnBg,
        Kind.info => C.infoBg, Kind.mute => const Color(0xFFEBF0F0) };
}

class StatusChip extends StatelessWidget {
  final String text;
  final Kind kind;
  final IconData? icon;
  const StatusChip(this.text, this.kind, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: kind.bg, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: kind.fg), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: kind.fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

(Color, IconData, String) lockInfo(String st) => switch (st) {
      'locked' => (C.ok, Icons.lock_rounded, 'Đã khóa'),
      'unlocked' => (C.bad, Icons.lock_open_rounded, 'Đang mở'),
      'jammed' => (C.warn, Icons.warning_amber_rounded, 'Bị kẹt'),
      _ => (C.muted, Icons.help_outline_rounded, 'Không rõ'),
    };

class LockRing extends StatelessWidget {
  final String state;
  final double size;
  const LockRing({super.key, required this.state, this.size = 96});

  @override
  Widget build(BuildContext context) {
    final (color, icon, _) = lockInfo(state);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(size * .1),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .07)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .13)),
        child: Icon(icon, size: size * .45, color: color),
      ),
    );
  }
}

class BatteryBar extends StatelessWidget {
  final int level;
  const BatteryBar(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = level < 20 ? C.bad : level < 50 ? C.warn : C.ok;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 44,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: LinearProgressIndicator(value: level / 100, minHeight: 6, color: c, backgroundColor: C.line),
        ),
      ),
      const SizedBox(width: 6),
      Text('$level%', style: const TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w600)),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: display(size: 16))),
          if (action != null)
            GestureDetector(
                onTap: onAction,
                child: Text(action!, style: const TextStyle(color: C.accent, fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const EmptyState(this.icon, this.title, {super.key, this.sub = ''});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(color: C.accentSoft, shape: BoxShape.circle),
                child: Icon(icon, color: C.accent, size: 28)),
            const SizedBox(height: 14),
            Text(title, style: display(size: 16)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sub, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
            ],
          ]),
        ),
      );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .28),
          gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.accent2, Color(0xFF0D9488)]),
          boxShadow: [BoxShadow(color: C.accent2.withValues(alpha: .5), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Icon(Icons.lock_outline_rounded, color: Colors.white, size: size * .5),
      );
}

Kind sevKind(String sev) => sev == 'critical' ? Kind.bad : sev == 'warning' ? Kind.warn : Kind.info;

class NoteTile extends StatelessWidget {
  final Note note;
  final VoidCallback? onTap;
  const NoteTile(this.note, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final k = sevKind(note.sev);
    final icon = note.sev == 'critical'
        ? Icons.gpp_maybe_rounded
        : note.sev == 'warning' ? Icons.battery_alert_rounded : Icons.info_outline_rounded;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: k.bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: k.fg, size: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(note.title,
                      style: TextStyle(fontWeight: note.read ? FontWeight.w500 : FontWeight.w700, fontSize: 14.5))),
              if (!note.read)
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.accent2, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text(note.body, style: const TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(height: 6),
            Text(ago(note.at), style: const TextStyle(color: C.muted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

class EventTile extends StatelessWidget {
  final AccessEvent e;
  const EventTile(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final icon = switch (e.method) {
      'NFC' => Icons.nfc_rounded, 'PIN' => Icons.dialpad_rounded,
      'FACE' => Icons.face_rounded, _ => Icons.phone_iphone_rounded };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: C.accentSoft, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: C.accent, size: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.who, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text('${e.method} · ${ago(e.at)}', style: const TextStyle(color: C.muted, fontSize: 12)),
          ]),
        ),
        e.success
            ? const StatusChip('Thành công', Kind.ok)
            : StatusChip(e.reason.isEmpty ? 'Từ chối' : e.reason, Kind.bad),
      ]),
    );
  }
}