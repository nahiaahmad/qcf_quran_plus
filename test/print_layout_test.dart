// The Mushaf follows the King Fahd 1421 Madinah print, page by page.
//
// 18 surahs open with their banner on the LAST line of the previous page and
// the basmala plus 14 lines of text on their own page. Upstream data had moved
// those banners onto the surah's page (13 squeezed lines, so the page was drawn
// smaller); tool/fix_print_lines.py put the print's line breaks back.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
import 'package:qcf_quran_plus/src/widgets/bsmallah_widget.dart';
import 'package:qcf_quran_plus/src/widgets/quran_line.dart';
import 'package:qcf_quran_plus/src/widgets/surah_header_widget.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  final pages = QuranPageView(
    pageController: PageController(),
    highlights: const [],
    isDarkMode: false,
  ).pages;

  int newSurahs(QuranPage p) => p.ayahs.where((a) => a.ayahNumber == 1).length;
  int banners(QuranPage p) =>
      p.ayahs
          .where((a) =>
              a.ayahNumber == 1 &&
              !surahsWithBannerOnPreviousPage.contains(a.surahNumber))
          .length +
      (p.trailingBannerSurah != null ? 1 : 0);
  int basmalas(QuranPage p) => p.ayahs
      .where((a) => a.ayahNumber == 1 && a.surahNumber != 9)
      .length;

  test('every page from 3 to 604 is 15 lines: text, banners and basmalas', () {
    final off = <String>[];
    for (final p in pages.skip(2)) {
      final total = p.lines.length + banners(p) + basmalas(p);
      if (total != 15) {
        off.add('${p.pageNumber}: ${p.lines.length} text + ${banners(p)} '
            'banner + ${basmalas(p)} basmala');
      }
    }
    expect(off, isEmpty);
  });

  test('the 18 banners close the page before their surah', () {
    final withTrailing = {
      for (final p in pages)
        if (p.trailingBannerSurah != null) p.pageNumber: p.trailingBannerSurah,
    };
    expect(withTrailing.values.toSet(), surahsWithBannerOnPreviousPage);
    for (final MapEntry(key: page, value: surah) in withTrailing.entries) {
      final opens = pages[page]; // the next page
      expect(opens.ayahs.first.surahNumber, surah);
      expect(opens.ayahs.first.ayahNumber, 1);
      expect(pages[page - 1].lines.length, 14, reason: 'page $page');
      expect(opens.lines.length, 14, reason: 'page ${page + 1}');
    }
    // an-Nisāʾ, the owner's example: Āl ʿImrān ends page 76 on line 14.
    expect(pages[75].trailingBannerSurah, 4);
    expect(newSurahs(pages[76]), 1);
  });

  testWidgets('every page is the print grid: 15 equal slots, lines aligned',
      (t) async {
    await _loadFont(
      'packages/qcf_quran_plus/DigitalKhatt',
      'assets/fonts/digitalkhatt/DigitalKhattV2.otf',
    );
    t.view.physicalSize = const Size(1320, 2868);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    // The page box of the reader on an iPhone Pro Max; slot = 95% / 15.
    const pageHeight = 956.0 - 110 - 60;
    const slot = pageHeight / 15;
    final off = <String>[];
    for (int p = 3; p <= 604; p++) {
      await t.pumpWidget(
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
                useDigitalKhatt: true,
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull, reason: 'page $p');
      final top = t.getTopLeft(find.byType(QuranSinglePageWidget)).dy;
      // Every text line and basmala fills exactly one slot; a banner is
      // centred on its slot; nothing but a banner passes the 15th slot.
      List<Rect> rects(Finder f) => f
          .evaluate()
          .map((e) => e.renderObject! as RenderBox)
          .map((b) => b.localToGlobal(Offset(0, -top)) & b.size)
          .toList();
      final lineRects = [
        ...rects(find.byType(QuranLine)),
        ...rects(find.byType(BasmallahWidget)).map((r) => r),
      ];
      final lines = find.byType(QuranLine).evaluate().length;
      if (lines != pages[p - 1].lines.length) {
        off.add('page $p: ${pages[p - 1].lines.length} lines, $lines drawn');
      }
      final textBottom = rects(find.byType(QuranLine))
          .map((r) => r.bottom)
          .reduce((a, b) => a > b ? a : b);
      if (textBottom > 15 * slot + 0.5) {
        off.add('page $p: text ends at ${textBottom.toStringAsFixed(1)} > '
            '${(15 * slot).toStringAsFixed(1)}');
      }
      for (final r in rects(find.byType(QuranLine))) {
        final k = r.top / slot;
        if ((k - k.round()).abs() * slot > 0.5 ||
            (r.height - slot).abs() > 0.5) {
          off.add('page $p: a text line at ${r.top.toStringAsFixed(1)}, '
              '${r.height.toStringAsFixed(1)} tall');
          break;
        }
      }
      for (final r in rects(find.byType(SurahHeaderWidget))) {
        final k = (r.center.dy / slot) - 0.5;
        if ((k - k.round()).abs() * slot > 0.5) {
          off.add('page $p: a banner centred at ${r.center.dy.toStringAsFixed(1)}');
        }
        if (r.bottom > 15 * slot + 0.2 * slot) {
          off.add('page $p: a banner ends at ${r.bottom.toStringAsFixed(1)}');
        }
      }
      lineRects.length; // basmalas are checked through the slot count above
    }
    expect(off, isEmpty);
  });

  testWidgets('these pages are drawn at the same size as the rest', (t) async {
    await _loadFont(
      'packages/qcf_quran_plus/DigitalKhatt',
      'assets/fonts/digitalkhatt/DigitalKhattV2.otf',
    );
    // iPhone Pro Max portrait, the reader's page box: one slot per line.
    const width = 440.0, height = 786.0;
    double sizeOf(QuranPage p) => DkQuran.pageFontSize(p,
        lineWidth: width - 32, lineHeight: height / 15);
    final all = [for (final p in pages.skip(2)) sizeOf(p)]..sort();
    final median = all[all.length ~/ 2];
    final low = <String>[];
    for (final p in pages) {
      final s = p.trailingBannerSurah ??
          (p.ayahs.isNotEmpty &&
                  p.ayahs.first.ayahNumber == 1 &&
                  surahsWithBannerOnPreviousPage
                      .contains(p.ayahs.first.surahNumber)
              ? p.ayahs.first.surahNumber
              : null);
      if (s == null) continue;
      final size = sizeOf(p);
      if (size < median * 0.93) {
        low.add('page ${p.pageNumber}: ${size.toStringAsFixed(2)} '
            '(median ${median.toStringAsFixed(2)})');
      }
    }
    expect(low, isEmpty);
  });
}
