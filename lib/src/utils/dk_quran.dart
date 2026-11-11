import 'dart:ui' show FontFeature;

import 'package:flutter/widgets.dart';

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
    double fontSize, {
    List<FontFeature> features = const [],
  }) {
    final st = style(fontSize: fontSize, height: pageLineHeightEm)
        .copyWith(fontFeatures: features);
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

  /// Page letter size, as a fraction of the line width: aim for
  /// [pageSizePerWidth] (22.5 on a 398-wide line); a page goes smaller only
  /// when one of its lines would otherwise be shrunk by more than
  /// [maxLineShrink], and never below [minSizePerWidth] (21).
  static const double pageSizePerWidth = 0.0565;
  static const double minSizePerWidth = 0.0527;
  static const double maxLineShrink = 0.12;

  /// Word gaps, as a fraction of the font size: a line that has room keeps
  /// at least [comfortableGapEm]; a long line may close down to [tightGapEm]
  /// before it is shrunk.
  static const double comfortableGapEm = 0.15;
  static const double tightGapEm = 0.10;

  /// Kept for callers that still read it: the comfortable gap.
  static const double minWordGapEm = comfortableGapEm;

  /// DigitalKhatt's stretched (kashida) letter forms, used to fill a line
  /// that has room. Its narrow forms (shr1, shr2, shrr) are NOT used: applied
  /// outside DigitalKhatt's own engine they drop or merge letters (ٱلَّذِي
  /// drawn without its alif, أموالهم squashed), checked 2026-11-11.
  static const List<FontFeature> stretchedForms = [FontFeature('jalt')];

  static final Map<String, double> _pageSizeCache = {};

  /// The letter size of every line of [page] (see [pageSizePerWidth]),
  /// never taller than one line slot ([lineHeight]) allows.
  static double pageFontSize(
    QuranPage page, {
    required double lineWidth,
    required double lineHeight,
  }) {
    final key = '${page.pageNumber}|${lineWidth.round()}|${lineHeight.round()}';
    final cached = _pageSizeCache[key];
    if (cached != null) return cached;
    double size = lineWidth * pageSizePerWidth;
    if (lineHeight > 0) {
      final byHeight = lineHeight / pageLineHeightEm;
      if (byHeight < size) size = byHeight;
    }
    const probe = 20.0;
    for (final line in page.lines) {
      if (line.ayahs.isEmpty || line.ayahs.last.centered) continue;
      final m = measureLine([
        for (final a in line.ayahs)
          piece(
            index: a.id - 1,
            part: a.linePart,
            tajweed: false,
            ink: const Color(0xFF000000),
          ),
      ], probe);
      if (m.width <= 0) continue;
      final fits = lineWidth / (m.width / probe + m.gaps * tightGapEm);
      final allowed = fits / (1 - maxLineShrink);
      if (allowed < size) size = allowed;
    }
    final floor = lineWidth * minSizePerWidth;
    if (size < floor) size = floor;
    return _pageSizeCache[key] = size;
  }

  static final Map<String,
          ({List<FontFeature> features, double wordSpacing, Set<int> stretch})>
      _lineCache = {};

  /// [pieces] with the words numbered in [words] (counted across the whole
  /// line, verse signs not counted) drawn in their stretched forms.
  static List<({List<InlineSpan> body, String? marker, Color markerColor})>
      stretchWords(
    List<({List<InlineSpan> body, String? marker, Color markerColor})> pieces,
    Set<int> words,
  ) {
    if (words.isEmpty) return pieces;
    int word = 0;
    final out =
        <({List<InlineSpan> body, String? marker, Color markerColor})>[];
    for (int pi = 0; pi < pieces.length; pi++) {
      final p = pieces[pi];
      if (pi > 0) word++; // the gap between two pieces ends a word
      final body = <InlineSpan>[];
      bool inWord = false;
      for (final span in p.body) {
        final ts = span as TextSpan;
        final text = ts.text ?? '';
        final buf = StringBuffer();
        bool? bufStretch;
        void flush() {
          if (buf.isEmpty) return;
          body.add(TextSpan(
            text: buf.toString(),
            style: bufStretch == true
                ? (ts.style ?? const TextStyle())
                    .copyWith(fontFeatures: stretchedForms)
                : ts.style,
          ));
          buf.clear();
        }

        for (final ch in text.split('')) {
          final isSpace = ch == ' ' || ch == '\u2002';
          if (isSpace) {
            if (inWord) word++;
            inWord = false;
          } else {
            inWord = true;
          }
          final st = !isSpace && words.contains(word);
          if (bufStretch != null && st != bufStretch) flush();
          bufStretch = st;
          buf.write(ch);
        }
        flush();
      }
      out.add((body: body, marker: p.marker, markerColor: p.markerColor));
    }
    return out;
  }

  static int _wordCount(
      List<({List<InlineSpan> body, String? marker, Color markerColor})>
          pieces) {
    int n = 0;
    for (final p in pieces) {
      final t = TextSpan(children: p.body).toPlainText().trim();
      if (t.isNotEmpty) n += t.split(RegExp(r'[ \u2002]+')).length;
    }
    return n;
  }

  /// How a justified line of [pieces] fills [width] at [fontSize], the way
  /// a scribe does it: a line with room stretches its letters (kashida) —
  /// all of them, or as many words, spread along the line, as still leave a
  /// comfortable gap — then widens its word gaps; a long line closes its
  /// gaps to [tightGapEm]. A line still too long is shrunk by the line widget.
  /// [key] caches the answer (e.g. page:line:width:size).
  static ({List<FontFeature> features, double wordSpacing, Set<int> stretch})
      fitLine(
    List<({List<InlineSpan> body, String? marker, Color markerColor})> pieces,
    double fontSize,
    double width, {
    String? key,
  }) {
    if (key != null) {
      final hit = _lineCache[key];
      if (hit != null) return hit;
    }
    ({List<FontFeature> features, double wordSpacing, Set<int> stretch})
        done(List<FontFeature> f, double natural, int gaps, double minGapEm,
            [Set<int> stretch = const {}]) {
      double ws = minGapEm * fontSize;
      if (gaps > 0) {
        final fill = (width - natural) / gaps;
        if (fill > ws) ws = fill;
      }
      final r = (features: f, wordSpacing: ws, stretch: stretch);
      if (key != null) _lineCache[key] = r;
      return r;
    }

    final plain = measureLine(pieces, fontSize);
    final g = plain.gaps;
    final comfortable = g * comfortableGapEm * fontSize;
    if (plain.width + comfortable <= width) {
      final stretched =
          measureLine(pieces, fontSize, features: stretchedForms);
      if (stretched.width + comfortable <= width) {
        return done(stretchedForms, stretched.width, g, comfortableGapEm);
      }
      // Stretch only some words, spread along the line, as many as fit.
      final n = _wordCount(pieces);
      final extra = width - comfortable - plain.width;
      final per = (stretched.width - plain.width) / (n > 0 ? n : 1);
      int k = per > 0 ? (extra / per).floor() : 0;
      if (k >= n) k = n - 1;
      while (k > 0) {
        final chosen = <int>{
          for (int i = 0; i < k; i++) ((i + 0.5) * n / k).floor(),
        };
        final m = measureLine(stretchWords(pieces, chosen), fontSize);
        if (m.width + comfortable <= width) {
          return done(const [], m.width, g, comfortableGapEm, chosen);
        }
        k--;
      }
      return done(const [], plain.width, g, comfortableGapEm);
    }
    // A long line closes its gaps; if still too long, the line widget
    // shrinks it (by at most maxLineShrink above the page floor).
    return done(const [], plain.width, g, tightGapEm);
  }

  /// Fine outline drawn over Mushaf text in each letter's own colour, as a
  /// fraction of the font size. DigitalKhatt has a single weight; this makes
  /// the strokes slightly stronger without the heaviness of a bold face
  /// (owner 2026-11-08: «slightly stronger»). 0 disables it.
  static const double inkOutlineEm = 0.02;

  /// [spans] restyled as outlines of [width] in each span's own colour.
  static List<InlineSpan> outlined(List<InlineSpan> spans, double width) => [
    for (final s in spans)
      if (s is TextSpan)
        TextSpan(
          text: s.text,
          children: s.children == null ? null : outlined(s.children!, width),
          // The outline keeps each span's letter forms (a stretched word
          // stays stretched), so it lies exactly on the fill.
          style: TextStyle(
            fontFeatures: s.style?.fontFeatures,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = width
              ..strokeJoin = StrokeJoin.round
              ..color = s.style?.color ?? const Color(0xFF191718),
          ),
        )
      else
        s,
  ];

  /// Base style for DigitalKhatt text. Callers merge size and height.
  static TextStyle style({double? fontSize, double? height}) => TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: fontSize,
    height: height,
  );
}

/// DigitalKhatt text drawn with its fine ink outline ([DkQuran.inkOutlineEm]):
/// the same spans painted twice, filled then outlined, in identical layout.
class DkText extends StatelessWidget {
  const DkText(
    this.spans, {
    super.key,
    required this.style,
    this.textAlign,
    this.softWrap = true,
    this.outlineEm = DkQuran.inkOutlineEm,
  });

  final List<InlineSpan> spans;
  final TextStyle style;
  final TextAlign? textAlign;
  final bool softWrap;
  final double outlineEm;

  @override
  Widget build(BuildContext context) {
    Text text(List<InlineSpan> s) => Text.rich(
      TextSpan(children: s),
      style: style,
      textAlign: textAlign,
      textDirection: TextDirection.rtl,
      softWrap: softWrap,
    );
    final width = outlineEm * (style.fontSize ?? 14);
    if (width <= 0) return text(spans);
    return Stack(
      children: [text(spans), text(DkQuran.outlined(spans, width))],
    );
  }
}
