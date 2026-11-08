import 'package:flutter/painting.dart';

import '../models/quran_page.dart';

import '../data/dk_data.dart';
import '../data/quran_data.dart' show quran;

/// DigitalKhatt (Madinah calligraphy) rendering of the Qurʾān text, with
/// optional tajwīd colouring.
///
/// The text ([dkAyahText]) is the QUL "Digital Khatt V2" script, re-cut so its
/// line breaks fall on exactly the same words as [quran]'s `aya_text`. Every
/// page therefore keeps the same 15 lines and the same verses as before.
///
/// The colours ([dkTajweedRuns]) come from QUL "QPC Hafs Tajweed" (King Fahd
/// Complex rule names), mapped letter by letter onto the DigitalKhatt text by
/// `tool/gen_dk_data.py`. A colour can sit on a single mark (e.g. the small
/// alif of a natural madd) without colouring the letter beneath it.
class DkQuran {
  DkQuran._();

  /// Font family declared in this package's pubspec.
  static const String fontFamily = 'DigitalKhatt';

  /// Package that ships [fontFamily]; pass it to [TextStyle.package].
  static const String fontPackage = 'qcf_quran_plus';

  /// End-of-verse sign; the DigitalKhatt font draws it around the number
  /// that follows.
  static const String verseEndSign = '۝';

  /// Tajwīd colours by rule group, in the order used by [dkTajweedRuns]:
  /// 0 madd muttaṣil / munfaṣil, 1 madd ʿāriḍ, 2 madd lāzim,
  /// 3 natural madd on the small letters, 4 qalqala,
  /// 5 ghunna / ikhfāʾ / iqlāb / idghām with ghunna,
  /// 6 silent or assimilated letters.
  ///
  /// These are the light-mode swatches of the King Fahd tajwīd colour font
  /// (CPAL palette 0) that the Mushaf used before, so readers keep the colours
  /// they know.
  static const List<Color> tajweedPalette = [
    Color(0xFFF40000),
    Color(0xFFFF7B00),
    Color(0xFFB50000),
    Color(0xFFCE9E00),
    Color(0xFF2FADFF),
    Color(0xFF09B000),
    Color(0xFFA5A5A5),
  ];

  static List<int>? _surahStart;

  /// Index into [dkAyahText] for [surah]:[ayah] (both 1-based).
  static int indexOf(int surah, int ayah) {
    final starts = _surahStart ??= _buildSurahStarts();
    if (surah < 1 || surah > 114) {
      throw RangeError.range(surah, 1, 114, 'surah');
    }
    final index = starts[surah - 1] + ayah - 1;
    final next = surah < 114 ? starts[surah] : dkAyahText.length;
    if (ayah < 1 || index >= next) {
      throw RangeError('No verse $surah:$ayah');
    }
    return index;
  }

  static List<int> _buildSurahStarts() {
    final starts = List<int>.filled(114, 0);
    int last = 0;
    for (int i = 0; i < quran.length; i++) {
      final sora = quran[i]['sora'] as int;
      if (sora != last) {
        starts[sora - 1] = i;
        last = sora;
      }
    }
    return starts;
  }

  /// The whole verse as one line (line breaks replaced by spaces).
  /// [withNumber] keeps the end-of-verse sign and number.
  static String verseText(int surah, int ayah, {bool withNumber = true}) {
    final text = dkAyahText[indexOf(surah, ayah)].replaceAll('\n', ' ');
    if (withNumber) return text;
    final cut = text.indexOf(verseEndSign);
    return cut < 0 ? text : text.substring(0, cut).trimRight();
  }

  /// Builds the styled spans of a verse, or of one line piece of it.
  ///
  /// [index] is the verse index (see [indexOf]); [part] selects a line piece
  /// (`Ayah.linePart`); `null` renders the whole verse on one line.
  /// [ink] colours the uncoloured text, [markerColor] the end-of-verse sign.
  /// With [tajweed] false every letter is drawn in [ink].
  static List<InlineSpan> spans({
    required int index,
    int? part,
    required bool tajweed,
    required Color ink,
    Color? markerColor,
    bool withNumber = true,
  }) {
    final full = dkAyahText[index];
    int start = 0;
    int end = full.length;
    if (part != null) {
      // Locate piece [part] between line breaks.
      int p = 0;
      int s = 0;
      while (p < part) {
        final nl = full.indexOf('\n', s);
        if (nl < 0) {
          s = full.length;
          break;
        }
        s = nl + 1;
        p++;
      }
      final e = full.indexOf('\n', s);
      start = s;
      end = e < 0 ? full.length : e;
    }

    // The verse-end sign + number, if it falls inside this piece.
    int markerAt = full.indexOf(verseEndSign);
    if (markerAt < start || markerAt >= end) markerAt = -1;
    final textEnd = markerAt < 0 ? end : markerAt;

    final out = <InlineSpan>[];
    void addText(int a, int b, Color c) {
      if (b <= a) return;
      out.add(
        TextSpan(
          text: full.substring(a, b).replaceAll('\n', ' '),
          style: TextStyle(color: c),
        ),
      );
    }

    if (tajweed) {
      final runs = dkTajweedRuns[index];
      int cursor = start;
      for (int r = 0; r + 2 < runs.length; r += 3) {
        final rs = runs[r] < start ? start : runs[r];
        final re = runs[r + 1] > textEnd ? textEnd : runs[r + 1];
        if (re <= rs || rs >= textEnd || re <= start) continue;
        addText(cursor, rs, ink);
        addText(rs, re, tajweedPalette[runs[r + 2]]);
        cursor = re;
      }
      addText(cursor, textEnd, ink);
    } else {
      addText(start, textEnd, ink);
    }

    if (markerAt >= 0 && withNumber) {
      // DigitalKhatt pulls a plain space before the verse-end sign to zero
      // width (its own layout engine adds the gap). In flowing text use an
      // en space, which the font leaves alone.
      if (out.isNotEmpty) {
        final last = out.last as TextSpan;
        final t = last.text!;
        if (t.endsWith(' ')) {
          out[out.length - 1] = TextSpan(
            text: '${t.substring(0, t.length - 1)}\u2002',
            style: last.style,
          );
        }
      }
      out.add(
        TextSpan(
          text: full.substring(markerAt, end),
          style: TextStyle(color: markerColor ?? ink),
        ),
      );
    } else if (!withNumber && out.isNotEmpty) {
      // Drop the space left before the removed number.
      final last = out.last as TextSpan;
      final t = last.text!.trimRight();
      out[out.length - 1] = TextSpan(text: t, style: last.style);
    }
    return out;
  }

  /// One verse piece of a Mushaf line: its text and, when the verse ends on
  /// this line, the end-of-verse sign + number as a separate word. Drawing
  /// the sign apart gives it the same justified gap as any other word gap
  /// (DigitalKhatt would otherwise pull the space before it to zero).
  static ({List<InlineSpan> body, String? marker, Color markerColor}) piece({
    required int index,
    required int part,
    required bool tajweed,
    required Color ink,
    Color? markerColor,
  }) {
    final all = spans(
      index: index,
      part: part,
      tajweed: tajweed,
      ink: ink,
      markerColor: markerColor,
    );
    String? marker;
    final body = <InlineSpan>[...all];
    if (body.isNotEmpty) {
      final last = body.last as TextSpan;
      if (last.text!.startsWith(verseEndSign)) {
        marker = last.text;
        body.removeLast();
        if (body.isNotEmpty) {
          final b = body.last as TextSpan;
          final t = b.text!.trimRight();
          if (t.isEmpty) {
            body.removeLast();
          } else {
            body[body.length - 1] = TextSpan(text: t, style: b.style);
          }
        }
      }
    }
    return (body: body, marker: marker, markerColor: markerColor ?? ink);
  }

  /// Natural width of a Mushaf line made of [pieces] at [fontSize], and the
  /// number of word gaps that justification may widen (spaces inside the
  /// text, the gap before each verse sign, the gap between pieces). Also
  /// returns the width of one plain space.
  static ({double width, int gaps, double space}) measureLine(
    List<({List<InlineSpan> body, String? marker, Color markerColor})> pieces,
    double fontSize,
  ) {
    final st = style(fontSize: fontSize, height: pageLineHeightEm);
    double measure(InlineSpan span) {
      final tp = TextPainter(
        textDirection: TextDirection.rtl,
        text: TextSpan(style: st, children: [span]),
      )..layout();
      final w = tp.maxIntrinsicWidth;
      tp.dispose();
      return w;
    }

    final space = measure(const TextSpan(text: ' '));
    double width = 0;
    int gaps = 0;
    for (int i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      if (p.body.isNotEmpty) {
        final body = TextSpan(children: p.body);
        width += measure(body);
        gaps += ' '.allMatches(body.toPlainText()).length;
      }
      if (p.marker != null) {
        width += measure(TextSpan(text: p.marker));
        if (p.body.isNotEmpty) {
          width += space;
          gaps++;
        }
      }
      if (i < pieces.length - 1) {
        width += space;
        gaps++;
      }
    }
    return (width: width, gaps: gaps, space: space);
  }

  /// Line height (as a multiple of the font size) used on Mushaf pages.
  /// DigitalKhatt's own line box is 2.4 em; marks may reach into the gap
  /// between lines exactly as on the printed page.
  static const double pageLineHeightEm = 1.75;

  /// Page font size bounds as a fraction of the line width. One size per page
  /// keeps every line's letters the same size; the band keeps the size from
  /// jumping between pages (about 21–25 on a 6.1" phone).
  static const double _maxSizePerWidth = 0.0615;
  static const double _minSizePerWidth = 0.0515;

  /// Minimum extra space added to every word gap, as a fraction of the font
  /// size. DigitalKhatt's own space is narrow; without this the longest line
  /// of a page (which sets the page size) would look cramped next to the
  /// widened lines around it.
  static const double minWordGapEm = 0.25;

  static final Map<String, double> _pageSizeCache = {};

  /// The font size for every justified line of [page]: the largest size at
  /// which its longest line fits [lineWidth], kept within the band above and
  /// never taller than [lineHeight] allows. A line still too long at the
  /// minimum is shrunk on its own by the line widget.
  static double pageFontSize(
    QuranPage page, {
    required double lineWidth,
    required double lineHeight,
  }) {
    final key = '${page.pageNumber}|${lineWidth.round()}|${lineHeight.round()}';
    final cached = _pageSizeCache[key];
    if (cached != null) return cached;

    final maxSize = lineWidth * _maxSizePerWidth;
    final minSize = lineWidth * _minSizePerWidth;
    double size = maxSize;
    if (lineHeight > 0) {
      final byHeight = lineHeight / pageLineHeightEm;
      if (byHeight < size) size = byHeight;
    }
    const probe = 20.0;
    for (final line in page.lines) {
      if (line.ayahs.isEmpty || line.ayahs.last.centered) continue;
      final pieces = [
        for (final a in line.ayahs)
          piece(
            index: a.id - 1,
            part: a.linePart,
            tajweed: false,
            ink: const Color(0xFF000000),
          ),
      ];
      final m = measureLine(pieces, probe);
      if (m.width <= 0) continue;
      // Width at size f: m.width * f / probe + gaps * minWordGapEm * f.
      final fit = lineWidth / (m.width / probe + m.gaps * minWordGapEm);
      if (fit < size) size = fit;
    }
    if (size < minSize) size = minSize;
    return _pageSizeCache[key] = size;
  }

  /// Base style for DigitalKhatt text. Callers merge size and height.
  static TextStyle style({double? fontSize, double? height}) => TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: fontSize,
    height: height,
  );
}
