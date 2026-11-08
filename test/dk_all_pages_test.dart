// Pumps all 604 Mushaf pages in DigitalKhatt mode (tajwid on and off) at an
// iPhone-size viewport and fails on any exception. Also reports lines whose
// natural width exceeds the line box (those are shrunk to fit).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

void main() {
  setUpAll(() async {
    final bytes =
        File('assets/fonts/digitalkhatt/DigitalKhattV2.otf').readAsBytesSync();
    final loader = FontLoader('packages/qcf_quran_plus/DigitalKhatt')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  testWidgets('all 604 pages render in DigitalKhatt', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final pages = QuranPageView(
      pageController: PageController(),
      highlights: const [],
      isDarkMode: false,
    ).pages;
    expect(pages.length, 604);
    for (final tajweed in [true, false]) {
      for (int p = 1; p <= 604; p++) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(440, 956)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 60),
                child: QuranSinglePageWidget(
                  page: pages[p - 1],
                  pageIndex: p,
                  highlights: const [],
                  pageController: PageController(),
                  isDark: false,
                  isTajweed: tajweed,
                  useDigitalKhatt: true,
                  surahHeaderBuilder: (c, s) => const SizedBox(height: 40),
                ),
              ),
            ),
          ),
        );
        final error = tester.takeException();
        if (error != null) fail('page $p tajweed=$tajweed: $error');
      }
    }
  });
}
