import 'package:flutter/painting.dart';

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
      // Keep a plain space before the sign (it is already in the text) and
      // draw the sign + number in the marker colour.
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

  /// Base style for DigitalKhatt text. Callers merge size and height.
  static TextStyle style({double? fontSize, double? height}) => TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: fontSize,
    height: height,
  );
}
