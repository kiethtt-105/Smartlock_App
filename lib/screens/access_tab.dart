import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class AccessTab extends StatelessWidget {
  const AccessTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (ctx, _) {
          final evs = store.events;
          final items = [
            (Icons.nfc_rounded, 'Thẻ NFC', '${store.cardCount} thẻ', C.violet, '/access/cards'),
            (Icons.dialpad_rounded, 'Mã PIN', '${store.pinCount} mã', C.cyan, '/access/pins'),
            (Icons.face_rounded, 'Khuôn mặt', '${store.faceCount} hồ sơ', C.amber, '/access/faces'),
            (Icons.share_rounded, 'Chia sẻ khóa', '${store.shareCount} người', C.green, '/access/shares'),
          ];
          return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 130), children: [
            Reveal(index: 0, child: Text('Truy cập', style: t(32, w: FontWeight.w800, ls: -1))),
            const SizedBox(height: 4),
            Reveal(index: 0, child: Text('Ai được vào, bằng cách nào', style: t(14, color: C.sub))),
            const SizedBox(height: 22),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.08,
              children: [
                for (int i = 0; i < items.length; i++)
                  Reveal(
                    index: i + 1,
                    child: Glass(
                      tint: items[i].$4,
                      onTap: () => context.push(items[i].$5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                                color: items[i].$4.withValues(alpha: .16), borderRadius: BorderRadius.circular(15)),
                            child: Icon(items[i].$1, color: items[i].$4),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(items[i].$2, style: t(16, w: FontWeight.w700, ls: -.2)),
                            Text(items[i].$3, style: t(12.5, color: C.sub)),
                          ]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Section('Lịch sử ra vào'),
            for (int i = 0; i < evs.length; i++) EventRow(evs[i], last: i == evs.length - 1),
          ]);
        },
      ),
    );
  }
}
