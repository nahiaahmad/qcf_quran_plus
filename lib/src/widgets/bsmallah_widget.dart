import 'package:flutter/material.dart';
import '../utils/dk_quran.dart';
import '../utils/quran_text_styles.dart';

/// A widget that renders the Basmallah (Bismillah) with specific calligraphic styles.
class BasmallahWidget extends StatelessWidget {
  const BasmallahWidget(
    this.surahNumber, {
    super.key,
    this.useDigitalKhatt = false,
    this.isTajweed = false,
    this.inkColor,
  });

  /// The index of the Surah used to determine the correct Basmallah glyph.
  final int surahNumber;

  /// Draw the basmala in DigitalKhatt (the text of 1:1 without its number).
  final bool useDigitalKhatt;
  final bool isTajweed;
  final Color? inkColor;

  @override
  Widget build(BuildContext context) {
    if (useDigitalKhatt) {
      final ink =
          inkColor ??
          Theme.of(context).textTheme.bodyLarge?.color ??
          const Color(0xFF191718);
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 5.0),
          child: Text.rich(
            TextSpan(
              children: DkQuran.spans(
                index: 0,
                tajweed: isTajweed,
                ink: ink,
                withNumber: false,
              ),
            ),
            style: DkQuran.style(fontSize: 21, height: 1.75),
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: Text(
          // Some Surahs (like 97 and 95) require a specific glyph variant
          // depending on the font's character mapping for optimal layout.
          surahNumber == 97 || surahNumber == 95 ? "齃𧻓𥳐龎" : '齃𧻓𥳐𥉉',
          // Utilizing the helper class for consistent Quranic typography
          style: QuranTextStyles.basmallahStyle(
            fontSize: 20,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
}
