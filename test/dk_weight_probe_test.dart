import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

void main() {
  testWidgets('weight probe', (tester) async {
    final bytes = File('assets/fonts/digitalkhatt/DigitalKhattV2.otf').readAsBytesSync();
    await (FontLoader('packages/qcf_quran_plus/DigitalKhatt')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    tester.view.physicalSize = const Size(1320, 2100);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    TextSpan versesWith(Color ink, Color mk, {double? stroke}) => TextSpan(children: [
      for (final a in [6, 7])
        for (final sp in DkQuran.spans(index: DkQuran.indexOf(2, a), tajweed: false, ink: ink, markerColor: mk))
          TextSpan(
            text: (sp as TextSpan).text,
            style: stroke == null
                ? sp.style
                : TextStyle(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeJoin = StrokeJoin.round..color = sp.style!.color!),
          ),
    ]);
    const fs = 24.0;
    final st = DkQuran.style(fontSize: fs, height: 1.75);
    Widget block(double? em) => Stack(children: [
      Text.rich(versesWith(const Color(0xFF191718), const Color(0xFF3F4343)), style: st, textAlign: TextAlign.justify),
      if (em != null) Text.rich(versesWith(const Color(0xFF191718), const Color(0xFF3F4343), stroke: em * fs), style: st, textAlign: TextAlign.justify),
    ]);
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.rtl,
      child: RepaintBoundary(key: key, child: Container(color: const Color(0xFFFFF7EB), padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        block(null), const Divider(), block(0.02), const Divider(), block(0.035),
      ]))),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/dk_render/weight_probe.png').writeAsBytesSync(bd!.buffer.asUint8List());
    });
  });
}
