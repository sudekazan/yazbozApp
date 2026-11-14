import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_dimensions.dart';
import '../scoreboard/scoreboard_logic.dart';
import '../scoreboard/scoreboard_table.dart';

/// Paylaşılan görselin mantıksal genişliği.
const double shareImageWidth = 390;

/// Görselin keskinliği (fiziksel piksel / mantıksal piksel).
const double shareImagePixelRatio = 3;

/// Paylaşılacak görseli sistemin paylaşım menüsüne verir. Testlerde
/// değiştirilir. [origin] iPad'de paylaşım penceresinin bağlandığı yerdir.
final tableSharerProvider =
    Provider<
      Future<void> Function(Uint8List png, String fileName, Rect? origin)
    >(
      (ref) => (png, fileName, origin) async {
        // Geçici dizine yazılır, paylaşım bitince silinir.
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(png, flush: true);
        try {
          await SharePlus.instance.share(
            ShareParams(files: [XFile(file.path)], sharePositionOrigin: origin),
          );
        } finally {
          if (await file.exists()) await file.delete();
        }
      },
    );

/// Tablonun tamamı: sabit başlık ve ekrana sığmayanlar dahil bütün eller.
class ShareTableCard extends StatelessWidget {
  const ShareTableCard({required this.view, super.key});

  final ScoreboardView view;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: SizedBox(
        width: shareImageWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScoreHeader(view: view),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  for (final row in view.rows)
                    switch (row) {
                      final RoundScoreRow round => RoundTile(row: round),
                      final SeatChangeRow change => SeatChangeNote(row: change),
                    },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [view]'u ekran dışında çizip PNG'ye çevirir. Çizilemezse `null`.
Future<Uint8List?> renderTableImage(
  BuildContext context,
  ScoreboardView view,
) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      // Ekranın dışında çizilir, kullanıcı görmez.
      left: -10 * shareImageWidth,
      top: 0,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Material(
            type: MaterialType.transparency,
            child: RepaintBoundary(
              key: boundaryKey,
              child: ShareTableCard(view: view),
            ),
          ),
        ),
      ),
    ),
  );
  try {
    overlay.insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: shareImagePixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
