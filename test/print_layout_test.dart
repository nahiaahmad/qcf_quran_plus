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

  testWidgets('these pages are drawn at the same size as the rest', (t) async {
    await _loadFont(
      'packages/qcf_quran_plus/DigitalKhatt',
      'assets/fonts/digitalkhatt/DigitalKhattV2.otf',
    );
    // iPhone Pro Max portrait, the reader's page box.
    const width = 440.0, height = 786.0;
    double sizeOf(QuranPage p) {
      double off = 0;
      for (final a in p.ayahs) {
        if (a.ayahNumber != 1) continue;
        if (!surahsWithBannerOnPreviousPage.contains(a.surahNumber)) off += 80;
        if (a.surahNumber != 9) off += 30;
      }
      if (p.trailingBannerSurah != null) off += 80;
      final lineHeight = (height - off) * 0.95 / p.lines.length;
      return DkQuran.pageFontSize(p,
          lineWidth: width - 32, lineHeight: lineHeight);
    }

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
      if (size < median * 0.96) {
        low.add('page ${p.pageNumber}: ${size.toStringAsFixed(2)} '
            '(median ${median.toStringAsFixed(2)})');
      }
    }
    expect(low, isEmpty);
  });
}
