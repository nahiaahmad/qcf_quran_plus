// Renders real Mushaf pages in DigitalKhatt mode to PNG files under
// build/dk_render/ for visual review. Not a golden test: it only fails if
// rendering throws (overflow, missing data, etc.).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont(
      'packages/qcf_quran_plus/DigitalKhatt',
      'assets/fonts/digitalkhatt/DigitalKhattV2.otf',
    );
  });

  final cases = <(int, bool)>[
    (3, false), (3, true), (1, true), (2, true), (50, true), (604, true),
  ];
  for (final (page, tajweed) in cases) {
    testWidgets('page $page tajweed=$tajweed', (tester) async {
      tester.view.physicalSize = const Size(1320, 2868);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final pages = QuranPageView(
        pageController: PageController(),
        highlights: const [],
        isDarkMode: false,
      ).pages;
      final key = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(440, 956), devicePixelRatio: 3),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: const Color(0xFFFFF7EB),
                padding: const EdgeInsets.fromLTRB(16, 110, 16, 60),
                child: QuranSinglePageWidget(
                  page: pages[page - 1],
                  pageIndex: page,
                  highlights: const [],
                  pageController: PageController(),
                  isDark: false,
                  isTajweed: tajweed,
                  useDigitalKhatt: true,
                  inkColor: const Color(0xFF191718),
                  markerColor: const Color(0xFF8A8C8C),
                  surahHeaderBuilder: (c, s) => Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF7A5F49)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 3);
        final bd = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/dk_render').createSync(recursive: true);
        File('build/dk_render/p${page}_${tajweed ? 'tj' : 'plain'}.png')
            .writeAsBytesSync(bd!.buffer.asUint8List());
      });
    });
  }
}
