import 'package:flutter/material.dart';
import '../../qcf_quran_plus.dart';

/// Renders a single line of Quran text using QCF fonts with highlight support.
///
/// **Performance optimizations applied:**
/// - All heavy text processing (trim, substring, glyph lookup) is moved
///   to `initState` and `didUpdateWidget`.
/// - Processing happens **once** per line instead of 60 times a second during UI rendering.
/// - Removed `Isolate` because package functions (like getaya_noQCF) may contain
///   unsendable objects (like Completers). Synchronous caching is fast enough to prevent jank.
class QuranLine extends StatefulWidget {
  const QuranLine(
    this.line,
    this.bookmarks, {
    super.key,
    this.boxFit = BoxFit.fill,
    this.onLongPress,
    this.ayahStyle,
    this.isTajweed = true,
    this.isDark = false,
    this.ayahNumberFilter,
    this.useDigitalKhatt = false,
    this.inkColor,
    this.markerColor,
    this.dkFontSize,
  });

  final Line line;
  final List<HighlightVerse> bookmarks;
  final BoxFit boxFit;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )?
  onLongPress;
  final TextStyle? ayahStyle;
  final bool isTajweed;
  final bool isDark;

  /// Optional [ColorFilter] applied to the end-of-verse number glyph.
  ///
  /// When non-null, this filter overrides the default light/dark behavior
  /// for the ayah-number glyph only. Pass any [ColorFilter] — for example
  /// [ColorFilter.mode] for a flat color, or [ColorFilter.matrix] for a
  /// hue rotation that preserves the glyph's internal shading.
  ///
  /// Defaults to `null` (preserves the original light/dark behavior).
  final ColorFilter? ayahNumberFilter;

  /// Draw the line in DigitalKhatt (see [DkQuran]) instead of the QCF page
  /// glyph fonts. Letters keep their true proportions; a justified line is
  /// filled by widening the space between words.
  final bool useDigitalKhatt;

  /// DigitalKhatt only: colour of uncoloured text. Defaults to a soft
  /// near-black (white in dark mode).
  final Color? inkColor;

  /// DigitalKhatt only: colour of the end-of-verse sign and number.
  final Color? markerColor;

  /// DigitalKhatt only: the page's font size (see [DkQuran.pageFontSize]) so
  /// every line of a page has the same letter size. Defaults to one that fills
  /// the line height.
  final double? dkFontSize;

  @override
  State<QuranLine> createState() => _QuranLineState();
}

class _QuranLineState extends State<QuranLine> {
  /// Pre-processed data (text, glyph, etc.) stored in memory
  late final List<_AyahDisplayData> _displayData;

  @override
  void initState() {
    super.initState();
    _displayData = _processData();
  }

  List<_AyahDisplayData> _processData() {
    return widget.line.ayahs.reversed.map((ayah) {
      final currentQcfText = ayah.qcfData.trimRight();
      final glyph = getaya_noQCF(ayah.surahNumber, ayah.ayahNumber);
      final hasGlyph = currentQcfText.endsWith(glyph);

      final textWithoutGlyph = hasGlyph
          ? currentQcfText.substring(0, currentQcfText.length - glyph.length)
          : currentQcfText;

      return _AyahDisplayData(
        textWithoutGlyph: textWithoutGlyph,
        glyph: glyph,
        hasGlyph: hasGlyph,
        surahNumber: ayah.surahNumber,
        ayahNumber: ayah.ayahNumber,
      );
    }).toList();
  }

  @override
  void didUpdateWidget(covariant QuranLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-process only if the actual line data has changed
    if (oldWidget.line != widget.line) {
      _processData();
    }
  }

  /// Processes text strings ONCE synchronously.
  /// This eliminates scroll jank without the need for Isolates.

  @override
  Widget build(BuildContext context) {
    // If empty (safety check), return invisible box
    if (_displayData.isEmpty) {
      return const SizedBox.shrink();
    }
    if (widget.useDigitalKhatt) return _buildDigitalKhatt(context);

    final defaultStyle = QuranTextStyles.qcfStyle(
      fontSize: 23.55,
      height: 1.45,
      pageNumber: widget.line.ayahs.first.page,
    );

    final finalStyle = widget.ayahStyle != null
        ? defaultStyle.merge(widget.ayahStyle!)
        : defaultStyle;

    ColorFilter? textFilter;
    if (widget.isDark && widget.isTajweed) {
      textFilter = const ColorFilter.matrix([
        -1,
        0,
        0,
        0,
        255,
        0,
        -1,
        0,
        0,
        255,
        0,
        0,
        -1,
        0,
        255,
        0,
        0,
        0,
        1,
        0,
      ]);
    } else if (widget.isDark && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);
    } else if (!widget.isDark && !widget.isTajweed) {
      textFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn);
    }
    final highlightMap = {
      for (var h in widget.bookmarks) '${h.surah}_${h.verseNumber}': h,
    };
    final textWidget = RichText(
      text: TextSpan(
        // Build is now ultra-light and fast!
        children: _displayData.map((data) {
          final highlight =
              highlightMap['${data.surahNumber}_${data.ayahNumber}'];

          final isHighlighted = highlight?.color != Colors.transparent;

          TextStyle mainTextStyle = finalStyle.copyWith(height: null);
          if (textFilter != null) {
            mainTextStyle = mainTextStyle
                .copyWith(color: null)
                .merge(
                  TextStyle(foreground: Paint()..colorFilter = textFilter),
                );
          }

          TextStyle numberTextStyle = finalStyle.copyWith(height: null);
          if (widget.ayahNumberFilter != null) {
            // Custom ayah-number filter overrides every other behavior so
            // host apps can recolor the glyph (e.g. via hue rotation) to
            // match their palette.
            numberTextStyle = numberTextStyle
                .copyWith(color: null)
                .merge(
                  TextStyle(
                    foreground: Paint()
                      ..colorFilter = widget.ayahNumberFilter!,
                  ),
                );
          } else if (widget.isDark) {
            numberTextStyle = numberTextStyle
                .copyWith(color: null)
                .merge(
                  TextStyle(
                    foreground: Paint()
                      ..colorFilter = const ColorFilter.matrix([
                        -1,
                        0,
                        0,
                        0,
                        255,
                        0,
                        -1,
                        0,
                        0,
                        255,
                        0,
                        0,
                        -1,
                        0,
                        255,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                  ),
                );
          }

          final ayahTextWidget = Text.rich(
            TextSpan(
              children: [
                TextSpan(text: data.textWithoutGlyph, style: mainTextStyle),
                if (data.hasGlyph)
                  TextSpan(text: data.glyph, style: numberTextStyle),
              ],
            ),
          );

          return WidgetSpan(
            child: GestureDetector(
              onLongPressStart: (details) => widget.onLongPress?.call(
                data.surahNumber,
                data.ayahNumber,
                details,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: isHighlighted
                      ? highlight?.color.withOpacity(0.4)
                      : null,
                ),
                child: ayahTextWidget,
              ),
            ),
          );
        }).toList(),
        style: finalStyle,
      ),
    );

    return FittedBox(fit: widget.boxFit, child: textWidget);
  }
}

extension _DigitalKhattLine on _QuranLineState {
  Widget _buildDigitalKhatt(BuildContext context) {
    final ink =
        widget.inkColor ??
        (widget.isDark ? const Color(0xFFF2EEE6) : const Color(0xFF191718));
    final marker = widget.markerColor ?? ink.withValues(alpha: 0.5);
    final justify = widget.boxFit == BoxFit.fill;
    final highlightMap = {
      for (var h in widget.bookmarks) '${h.surah}_${h.verseNumber}': h,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final boxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 44.0;
        final fontSize =
            widget.dkFontSize ??
            widget.ayahStyle?.fontSize ??
            boxH / DkQuran.pageLineHeightEm;
        final base = DkQuran.style(
          fontSize: fontSize,
          height: DkQuran.pageLineHeightEm,
        ).copyWith(leadingDistribution: TextLeadingDistribution.even);

        // Pieces in reading order (the line's ayahs are stored in order).
        final pieces = [
          for (final a in widget.line.ayahs)
            DkQuran.piece(
              index: a.id - 1,
              part: a.linePart,
              tajweed: widget.isTajweed,
              ink: ink,
              markerColor: marker,
            ),
        ];

        final m = DkQuran.measureLine(pieces, fontSize);
        final natural = m.width;
        final spaces = m.gaps;

        // Every gap gets at least the minimum extra space; a justified line
        // spreads the rest of the width over its gaps. The gap before a verse
        // sign counts as a word gap too.
        double wordSpacing = DkQuran.minWordGapEm * fontSize;
        if (justify && spaces > 0) {
          final fill = (maxW - natural) / spaces;
          if (fill > wordSpacing) wordSpacing = fill;
        }
        final style = base.copyWith(wordSpacing: wordSpacing);
        final markerGap = m.space + wordSpacing;

        // A Row lays the pieces out right-to-left in reading order. Gaps are
        // explicit boxes of exactly one justified word gap: DigitalKhatt would
        // pull a plain space next to a verse sign to zero width.
        final children = <Widget>[];
        for (int i = 0; i < pieces.length; i++) {
          final a = widget.line.ayahs[i];
          final highlight = highlightMap['${a.surahNumber}_${a.ayahNumber}'];
          final isHighlighted =
              highlight != null && highlight.color != Colors.transparent;
          if (i > 0) children.add(SizedBox(width: markerGap));
          children.add(
            GestureDetector(
              onLongPressStart: (details) => widget.onLongPress?.call(
                a.surahNumber,
                a.ayahNumber,
                details,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.0),
                  color: isHighlighted
                      ? highlight.color.withValues(alpha: 0.4)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    if (pieces[i].body.isNotEmpty)
                      DkText(pieces[i].body, style: style, softWrap: false),
                    if (pieces[i].marker != null) ...[
                      if (pieces[i].body.isNotEmpty)
                        SizedBox(width: markerGap),
                      DkText(
                        [
                          TextSpan(
                            text: pieces[i].marker,
                            style: TextStyle(color: pieces[i].markerColor),
                          ),
                        ],
                        style: style,
                        softWrap: false,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: maxW,
          height: boxH,
          child: FittedBox(
            // Never stretch letters; only shrink a line that is too long.
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

/// Lightweight immutable data class.
/// Contains everything needed to build the spans instantly.
class _AyahDisplayData {
  final String textWithoutGlyph;
  final String glyph;
  final bool hasGlyph;
  final int surahNumber;
  final int ayahNumber;

  const _AyahDisplayData({
    required this.textWithoutGlyph,
    required this.glyph,
    required this.hasGlyph,
    required this.surahNumber,
    required this.ayahNumber,
  });
}
