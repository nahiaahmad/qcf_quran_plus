// Measures every Mushaf line in DigitalKhatt at a phone page size and prints
// how many lines are wider than the line box (they get shrunk to fit).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

void main() {
  testWidgets('line widths', (tester) async {
    final bytes =
        File('assets/fonts/digitalkhatt/DigitalKhattV2.otf').readAsBytesSync();
    final loader = FontLoader('packages/qcf_quran_plus/DigitalKhatt')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    final pages = QuranPageView(
      pageController: PageController(),
      highlights: const [],
      isDarkMode: false,
    ).pages;
    const boxW = 408.0; // device width 440 - 32, as QuranSinglePageWidget
    const fontSize = 49.0 / 1.75; // a 15-line page on a 6.1" phone
    final ratios = <double>[];
    final worst = <String>[];
    for (final page in pages.skip(2)) {
      for (final line in page.lines) {
        final spans = <InlineSpan>[];
        for (int i = 0; i < line.ayahs.length; i++) {
          final a = line.ayahs[i];
          spans.addAll(DkQuran.spans(
              index: a.id - 1, part: a.linePart, tajweed: false, ink: Colors.black));
          if (i < line.ayahs.length - 1) spans.add(const TextSpan(text: ' '));
        }
        final tp = TextPainter(
          textDirection: TextDirection.rtl,
          text: TextSpan(style: DkQuran.style(fontSize: fontSize, height: 1.75), children: spans),
        )..layout();
        final r = tp.maxIntrinsicWidth / boxW;
        tp.dispose();
        if (line.ayahs.last.centered) continue;
        ratios.add(r);
        if (r > 1.0) worst.add('p${page.pageNumber}:${r.toStringAsFixed(3)}');
      }
    }
    // per page: the font size at which the longest line fits
    final pageFs = <double>[];
    for (final page in pages.skip(2)) {
      double maxR = 0;
      for (final line in page.lines) {
        if (line.ayahs.last.centered) continue;
        final spans = <InlineSpan>[];
        for (int i = 0; i < line.ayahs.length; i++) {
          final a = line.ayahs[i];
          spans.addAll(DkQuran.spans(index: a.id - 1, part: a.linePart, tajweed: false, ink: Colors.black));
          if (i < line.ayahs.length - 1) spans.add(const TextSpan(text: ' '));
        }
        final tp = TextPainter(textDirection: TextDirection.rtl,
          text: TextSpan(style: DkQuran.style(fontSize: fontSize, height: 1.75), children: spans))..layout();
        final r = tp.maxIntrinsicWidth / boxW; tp.dispose();
        if (r > maxR) maxR = r;
      }
      pageFs.add(maxR == 0 ? fontSize : (fontSize / maxR).clamp(0, fontSize));
    }
    pageFs.sort();
    String q(double x) => pageFs[(x * (pageFs.length - 1)).round()].toStringAsFixed(1);
    // ignore: avoid_print
    print('per-page font size: min=${q(0)} p5=${q(.05)} p25=${q(.25)} median=${q(.5)} p75=${q(.75)} p95=${q(.95)} max=${q(1)}');
    ratios.sort();
    String pct(double q) => ratios[(q * (ratios.length - 1)).round()].toStringAsFixed(3);
    // ignore: avoid_print
    print('lines=${ratios.length} min=${pct(0)} p10=${pct(.1)} median=${pct(.5)} p90=${pct(.9)} max=${pct(1)}');
    // ignore: avoid_print
    print('wider than box: ${worst.length}  e.g. ${worst.take(12).join(' ')}');
  });
}
