// The Mushaf may only switch on font features that cannot change the text.
//
// DigitalKhatt's stretched forms (jalt) and stretched basmala (basm) reach
// only one-for-one glyph substitutions (GSUB lookup type 1, possibly through
// chaining context), so no letter can be dropped, added or merged. Its narrow
// forms (shr1/shr2/shrr) are not used: outside DigitalKhatt's own engine they
// drew ٱلَّذِي without its alif (checked 2026-11-11).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

void main() {
  final d = ByteData.sublistView(
      File('assets/fonts/digitalkhatt/DigitalKhattV2.otf').readAsBytesSync());
  int u16(int o) => d.getUint16(o);
  int u32(int o) => d.getUint32(o);
  final tables = <String, int>{};
  for (int i = 0; i < u16(4); i++) {
    final b = 12 + 16 * i;
    tables[String.fromCharCodes(
        d.buffer.asUint8List(d.offsetInBytes + b, 4))] = u32(b + 8);
  }
  final gsub = tables['GSUB']!;
  final featureList = gsub + u16(gsub + 6);
  final lookupList = gsub + u16(gsub + 8);

  Set<int> lookupsOf(String tag) {
    final out = <int>{};
    for (int i = 0; i < u16(featureList); i++) {
      final r = featureList + 2 + 6 * i;
      final t = String.fromCharCodes(
          d.buffer.asUint8List(d.offsetInBytes + r, 4));
      if (t != tag) continue;
      final f = featureList + u16(r + 4);
      for (int j = 0; j < u16(f + 2); j++) {
        out.add(u16(f + 4 + 2 * j));
      }
    }
    return out;
  }

  // Lookup types reached from [li], following chaining-context records.
  Set<int> reached(int li, Set<int> seen) {
    if (!seen.add(li)) return {};
    final types = <int>{};
    final lo = lookupList + u16(lookupList + 2 + 2 * li);
    var type = u16(lo);
    for (int k = 0; k < u16(lo + 4); k++) {
      var st = lo + u16(lo + 6 + 2 * k);
      var t = type;
      if (type == 7) {
        t = u16(st + 2);
        st = st + u32(st + 4);
      }
      types.add(t);
      if (t == 6 && u16(st) == 3) {
        var o = st + 2;
        o += 2 + 2 * u16(o); // backtrack
        o += 2 + 2 * u16(o); // input
        o += 2 + 2 * u16(o); // lookahead
        final records = u16(o);
        o += 2;
        for (int r = 0; r < records; r++) {
          types.addAll(reached(u16(o + 4 * r + 2), seen));
        }
      } else if (t == 6) {
        fail('lookup $li: chaining format ${u16(st)} not checked here');
      }
    }
    return types;
  }

  for (final tag in ['jalt', 'basm']) {
    test('$tag only swaps one glyph for one glyph', () {
      final lookups = lookupsOf(tag);
      expect(lookups, isNotEmpty);
      final types = <int>{};
      for (final li in lookups) {
        types.addAll(reached(li, {}));
      }
      expect(types.difference({1, 6}), isEmpty,
          reason: '$tag reaches lookup types $types');
    });
  }

  test('the Mushaf switches on no other feature', () {
    expect(DkQuran.stretchedForms.map((f) => f.feature), ['jalt']);
  });
}
