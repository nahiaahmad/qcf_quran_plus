import 'package:flutter/material.dart';
import '../utils/quran_text_styles.dart';

/// A responsive widget that displays the Surah name/number inside a decorative banner.
///
/// It uses [LayoutBuilder] to calculate font size dynamically, ensuring the
/// text always fits perfectly within the banner image across different screen sizes.
class SurahHeaderWidget extends StatelessWidget {
  /// The index of the Surah (1-114).
  final int suraNumber;

  const SurahHeaderWidget({super.key, required this.suraNumber});

  /// Width / height of assets/surah_banner.png (3421 × 403).
  static const double bannerAspect = 3421 / 403;

  @override
  Widget build(BuildContext context) {
    // The path to the decorative frame used as a background for the Surah name.
    const String imagePath = "assets/surah_banner.png";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;

        // On a Mushaf page (bounded height) the banner spans the text width,
        // as in the print, within the height it is given; elsewhere it is 90%
        // of the width.
        final bool inSlot = constraints.maxHeight.isFinite;
        final double pad = inSlot ? 2 : 8;
        double headerWidth = availableWidth * (inSlot ? 0.95 : 0.9);
        if (inSlot) {
          final byHeight = (constraints.maxHeight - 2 * pad) * bannerAspect;
          if (byHeight < headerWidth) headerWidth = byHeight;
        }

        // Dynamically calculate font size based on the width to prevent text overflow.
        final double dynamicFontSize = headerWidth * 0.085;

        return Container(
          padding: EdgeInsets.symmetric(vertical: pad),
          width: double.infinity,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background banner image from the package assets.
              Image(
                image: const AssetImage(imagePath, package: 'qcf_quran_plus'),
                width: headerWidth,
                fit: BoxFit.contain,
              ),
              // The Surah number rendered using the specialized 'arsura' font.
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: "$suraNumber",
                  style: QuranTextStyles.surahHeaderStyle(
                    fontSize: dynamicFontSize,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
