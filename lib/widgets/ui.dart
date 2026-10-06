import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/store.dart';
import '../core/theme.dart';

/// Nền tối có vệt sáng
class GlowBg extends StatelessWidget {
  final Widget child;
  const GlowBg({super.key, required this.child});

  Widget _g(Color c, double s) => IgnorePointer(
        child: Container(
          width: s, height: s,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)])),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        color: C.bg,
        child: Stack(children: [
          Positioned(top: -140, right: -100, child: _g(C.violet.withValues(alpha: .35), 380)),
          Positioned(top: 300, left: -180, child: _g(C.cyan.withValues(alpha: .14), 360)),
          Positioned.fill(child: child),
        ]),
      );
}

/// Bấm có hiệu ứng nhún
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Tap({super.key, required this.child, this.onTap, this.scale = .96});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;
  void _set(bool v) {
    if (widget.onTap != null) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: widget.child),
      );
}

/// Hiện dần + trượt lên, so le theo index
class Reveal extends StatefulWidget {
  final int index;
  final Widget child;
  const Reveal({super.key, this.index = 0, required this.child});
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 70 * widget.index.clamp(0, 8)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .1), end: Offset.zero).animate(_a),
            child: widget.child),
      );
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(16),
      this.radius = 22, this.onTap, this.tint});

  @override
  Widget build(BuildContext context) {
    final tc = tint ?? Colors.white;
    return Tap(
      onTap: onTap,
      scale: .98,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: C.stroke),
          gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [tc.withValues(alpha: .08), tc.withValues(alpha: .015)]),
        ),
        child: child,
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const Pill(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: t(11.5, w: FontWeight.w700, color: color)),
        ]),
      );
}

(Color, IconData, String) lockMeta(String st) => switch (st) {
      'locked' => (C.cyan, Icons.lock_rounded, 'Đã khóa'),
      'unlocked' => (C.amber, Icons.lock_open_rounded, 'Đang mở'),
      'jammed' => (C.red, Icons.warning_amber_rounded, 'Bị kẹt'),
      _ => (C.sub, Icons.help_outline_rounded, 'Không rõ'),
    };

/// Nút khóa tròn lớn: trung tâm của app
class LockOrb extends StatefulWidget {
  final Device d;
  final double size;
  final VoidCallback? onTap;
  const LockOrb({super.key, required this.d, this.size = 200, this.onTap});
  @override
  State<LockOrb> createState() => _LockOrbState();
}

class _LockOrbState extends State<LockOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant LockOrb old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final active = widget.d.busy || widget.d.lock == 'unlocked';
    if (active && !_c.isAnimating) {
      _c.repeat();
    } else if (!active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _ring(double s, Color c, double p) => Opacity(
        opacity: ((1 - p) * .55).clamp(0.0, 1.0),
        child: Container(
          width: s * (1 + .38 * p), height: s * (1 + .38 * p),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 2)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final d = widget.d, s = widget.size;
    final (c, icon, _) = lockMeta(d.lock);
    final rings = d.busy || d.lock == 'unlocked';

    final core = Stack(alignment: Alignment.center, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        width: s, height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withValues(alpha: .28), C.card], radius: .95),
          border: Border.all(color: c.withValues(alpha: .55), width: 1.6),
          boxShadow: [BoxShadow(color: c.withValues(alpha: .35), blurRadius: 56, spreadRadius: -8)],
        ),
      ),
      if (d.busy)
        SizedBox(
            width: s - 10, height: s - 10,
            child: CircularProgressIndicator(strokeWidth: 3, color: c, strokeCap: StrokeCap.round)),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (w, a) => ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: a, child: w)),
        child: Icon(d.busy ? Icons.sync_rounded : icon,
            key: ValueKey(d.busy ? 'busy' : d.lock), size: s * .36, color: c),
      ),
    ]);

    return Tap(
      onTap: widget.onTap,
      scale: .94,
      child: AnimatedBuilder(
        animation: _c,
        child: core,
        builder: (ctx, child) => SizedBox(
          width: s * 1.4, height: s * 1.4,
          child: Stack(alignment: Alignment.center, children: [
            if (rings) for (final k in const [0.0, .5]) _ring(s, c, (_c.value + k) % 1),
            child!,
          ]),
        ),
      ),
    );
  }
}

void toggleLock(BuildContext context, Device d) {
  if (!d.online) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${d.name} đang mất kết nối')));
    return;
  }
  HapticFeedback.mediumImpact();
  store.send(d, d.lock == 'locked' ? 'UNLOCK' : 'LOCK').then((_) => HapticFeedback.heavyImpact());
}

class GradBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled, loading;
  const GradBtn(this.label, {super.key, this.icon, this.onTap, this.filled = true, this.loading = false});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null && !loading ? .4 : 1,
        child: Tap(
          onTap: loading ? null : onTap,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: filled ? C.grad : null,
              color: filled ? null : C.card2,
              border: filled ? null : Border.all(color: C.stroke),
            ),
            child: loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                    Text(label, style: t(15.5, w: FontWeight.w700)),
                  ]),
          ),
        ),
      );
}

class RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  const RoundBtn(this.icon, {super.key, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) => Tap(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: C.card2, border: Border.all(color: C.stroke)),
            child: Icon(icon, color: C.text, size: 22),
          ),
          if (badge > 0)
            Positioned(
              right: -3, top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: C.red, borderRadius: BorderRadius.circular(99)),
                child: Text('$badge', style: t(10.5, w: FontWeight.w800)),
              ),
            ),
        ]),
      );
}

class Section extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const Section(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 28, 2, 14),
        child: Row(children: [
          Expanded(child: Text(text, style: t(18, w: FontWeight.w700, ls: -.3))),
          if (action != null)
            Tap(onTap: onAction, child: Text(action!, style: t(13, w: FontWeight.w600, color: C.violet))),
        ]),
      );
}

class MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const MiniStat(this.icon, this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Glass(
          padding: const EdgeInsets.all(14),
          radius: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(value, style: t(17, w: FontWeight.w800, ls: -.3)),
            const SizedBox(height: 2),
            Text(label, style: t(12, color: C.sub)),
          ]),
        ),
      );
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: C.grad,
          boxShadow: [BoxShadow(color: C.violet.withValues(alpha: .55), blurRadius: 40, spreadRadius: -4)],
        ),
        child: Icon(Icons.lock_rounded, color: Colors.white, size: size * .46),
      );
}

/// Dòng thời gian cho lịch sử ra vào
class EventRow extends StatelessWidget {
  final AccessEvent e;
  final bool last;
  const EventRow(this.e, {super.key, this.last = false});

  @override
  Widget build(BuildContext context) {
    final c = e.success ? C.cyan : C.red;
    final icon = switch (e.method) {
      'NFC' => Icons.nfc_rounded,
      'PIN' => Icons.dialpad_rounded,
      'FACE' => Icons.face_rounded,
      _ => Icons.phone_iphone_rounded,
    };
    final status = e.success ? 'Thành công' : (e.reason.isEmpty ? 'Từ chối' : e.reason);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .14)),
            child: Icon(icon, size: 19, color: c),
          ),
          if (!last)
            Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: C.stroke)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Text(e.who, style: t(15, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${e.method} · $status', style: t(12.5, color: e.success ? C.sub : C.red)),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(ago(e.at), style: t(12, color: C.sub))),
      ]),
    );
  }
}

Color sevColor(String s) => s == 'critical' ? C.red : s == 'warning' ? C.amber : C.violet;

class NoteCard extends StatelessWidget {
  final Note n;
  final VoidCallback? onTap;
  const NoteCard(this.n, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = sevColor(n.sev);
    final icon = n.sev == 'critical'
        ? Icons.gpp_maybe_rounded
        : n.sev == 'warning' ? Icons.battery_alert_rounded : Icons.notifications_active_rounded;
    return Glass(
      onTap: onTap,
      tint: c,
      radius: 20,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: c.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: c, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, style: t(15, w: n.read ? FontWeight.w500 : FontWeight.w700))),
              if (!n.read) Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 4),
            Text(n.body, style: t(13, color: C.sub, h: 1.35)),
            const SizedBox(height: 8),
            Text(ago(n.at), style: t(11.5, color: C.sub)),
          ]),
        ),
      ]),
    );
  }
}

class EmptyBox extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const EmptyBox(this.icon, this.title, {super.key, this.sub = ''});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: C.card2, border: Border.all(color: C.stroke)),
            child: Icon(icon, color: C.sub, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title, style: t(17, w: FontWeight.w700)),
          if (sub.isNotEmpty) ...[const SizedBox(height: 4), Text(sub, style: t(13.5, color: C.sub))],
        ]),
      );
}
