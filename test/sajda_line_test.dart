// The sajda line (owner 2026-11-26): the Madinah print draws a line over the
// words of each of the fifteen sajdas. DigitalKhatt's own patterns, matched
// line by line, find exactly these fifteen, each on one line.

import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/src/data/dk_data.dart';
import 'package:qcf_quran_plus/src/utils/dk_quran.dart';

void main() {
  test('exactly the fifteen sajdas, each on the expected words', () {
    final found = <int, String>{};
    for (var i = 0; i < dkAyahText.length; i++) {
      for (final line in dkAyahText[i].split('\n')) {
        final r = DkQuran.sajdaLetters(line);
        if (r == null) continue;
        // The lined text: base letters first..last, each with its marks.
        final buf = StringBuffer();
        var base = -1;
        for (final c in DkQuran.canonicalArabic(line).runes) {
          if (DkQuran.isBase(c)) base++;
          if (base >= r.first && base <= r.last) buf.writeCharCode(c);
        }
        found[i + 1] = buf.toString();
      }
    }
    // Verse ids (Mushaf order, 1-based) of 7:206 … 96:19.
    expect(found.keys.toList(), [
      1160, 1722, 1950, 2136, 2308, 2613, 2672, 2915,
      3184, 3518, 3994, 4255, 4846, 5905, 6125,
    ]);
    String c(String s) => DkQuran.canonicalArabic(s);
    expect(found[1160], c('يَسْجُدُونَ'), reason: 'the line stops before ۩');
    expect(found[5905], c('يَسْجُدُونَ'));
    expect(found[6125], c('وَٱسْجُدْ'));
    expect(found[4255], c('وَٱسْجُدُوا۟ لِلَّهِ'));
    expect(found[4846], c('فَٱسْجُدُوا۟ لِلَّهِ'));
    expect(found[3518], c('خَرُّوا۟ سُجَّدࣰا'));
  });

  test('the sajda range stops before ۩', () {
    const line = 'عَلَيْهِمُ ٱلْقُرْءَانُ لَا يَسْجُدُونَ۩';
    final r = DkQuran.sajdaRange(line)!;
    expect(line.substring(r.start, r.end), 'يَسْجُدُونَ');
  });

  test('the sajda range is the lined words only', () {
    const line = 'كَلَّا لَا تُطِعْهُ وَٱسْجُدْ وَٱقْتَرِب۩';
    final r = DkQuran.sajdaRange(line)!;
    expect(line.substring(r.start, r.end), 'وَٱسْجُدْ');
    const fussilat = 'وَلَا لِلْقَمَرِ وَٱسْجُدُوا۟ لِلَّهِ ٱلَّذِي خَلَقَهُنَّ';
    final f = DkQuran.sajdaRange(fussilat)!;
    expect(fussilat.substring(f.start, f.end), 'وَٱسْجُدُوا۟ لِلَّهِ');
  });

  test('a line without a sajda has no range', () {
    expect(DkQuran.sajdaRange('ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ'), isNull);
  });
}
