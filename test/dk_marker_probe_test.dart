import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

void main() {
  testWidgets('marker probe', (tester) async {
    final bytes = File('assets/fonts/digitalkhatt/DigitalKhattV2.otf').readAsBytesSync();
    await (FontLoader('packages/qcf_quran_plus/DigitalKhatt')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
    tester.view.physicalSize = const Size(1320, 1200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const ink = Color(0xFF191718), grey = Color(0xFF8A8C8C);
    final st = DkQuran.style(fontSize: 26, height: 1.75);
    Widget row(String label, Widget w) => Row(children: [SizedBox(width: 90, child: Text(label, textDirection: TextDirection.ltr)), Expanded(child: w)]);
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.rtl,
      child: RepaintBoundary(key: key, child: Container(color: const Color(0xFFFFF7EB), child: Column(children: [
        for (final v in const [
          ['space', ' '],
          ['nbsp', '\u00A0'],
          ['zwnj+sp', ' \u200C'],
          ['sp+zwnj', '\u200C '],
          ['zwsp', ' \u200B'],
          ['en', '\u2002'],
        ])
          row(v[0], Text.rich(TextSpan(children: [TextSpan(text: 'لَا يُؤْمِنُونَ${v[1]}', style: const TextStyle(color: ink)), const TextSpan(text: '\u06DD٦', style: TextStyle(color: grey))]), style: st.copyWith(wordSpacing: 12))),
      ]))),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/dk_render').createSync(recursive: true);
      File('build/dk_render/marker_probe.png').writeAsBytesSync(bd!.buffer.asUint8List());
    });
  });
}
