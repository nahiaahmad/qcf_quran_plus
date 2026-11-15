// Every DigitalKhatt Mushaf line must lay out as ONE row, at any page size.
// Regression for the line that dropped its last word onto a second row and
// shrank (page 5 at 393×640, 499×646, 640×1016, 650×1016): TextPainter
// re-laid a right-aligned, unwrapped line at its under-measured intrinsic
// width. DkText now left-aligns unwrapped lines (laid out once, infinite).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

void main() {
  testWidgets('no Mushaf line wraps, every page, phone and iPad sizes', (tester) async {
    final bytes = File('assets/fonts/digitalkhatt/DigitalKhattV2.otf').readAsBytesSync();
    await (FontLoader('packages/qcf_quran_plus/DigitalKhatt')
          ..addFont(Future.value(ByteData.view(bytes.buffer))))
        .load();
    final pages = QuranPageView(pageController: PageController(), highlights: const [], isDarkMode: false).pages;
    const sizes = [
      Size(393, 640), // phone page box
      Size(499, 646), // failed: page 5 line 1
      Size(640, 1016), // failed: page 5 line 8
      Size(650, 1016), // failed: page 5 line 8
      Size(520, 650), // iPad open book, one page
    ];
    final failures = <String>[];
    for (final size in sizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final page in pages) {
        await tester.pumpWidget(MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: QuranSinglePageWidget(
              page: page,
              pageIndex: page.pageNumber,
              highlights: const [],
              pageController: PageController(),
              isDark: false,
              isTajweed: false,
              useDigitalKhatt: true,
            ),
          ),
        ));
        for (final e in find.byType(RichText).evaluate()) {
          final ro = e.renderObject as RenderParagraph;
          if (ro.softWrap) continue; // only the unwrapped Mushaf line pieces
          final tp = TextPainter(
            text: ro.text,
            textDirection: ro.textDirection,
            textAlign: ro.textAlign,
            textScaler: ro.textScaler,
          )..layout();
          final rows = tp.computeLineMetrics().length;
          tp.dispose();
          if (rows > 1) failures.add('p${page.pageNumber} @ ${size.width.toInt()}×${size.height.toInt()}: $rows rows');
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    expect(failures, isEmpty, reason: failures.take(20).join('\n'));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
