import 'ayah.dart';

/// Represents a single page of the Holy Quran Mushaf.
///
/// This class aggregates [Ayah] and [Line] objects to facilitate the
/// structured rendering of a Quranic page in a digital interface.
class QuranPage {
  /// The physical page number in the Mushaf (typically 1-604).
  final int pageNumber;

  /// The count of Surah headers (start of a new chapter) present on this page.
  /// Useful for rendering "Bismillah" or Surah title banners.
  int numberOfNewSurahs;

  /// A flat list of all [Ayah] objects contained on this page.
  List<Ayah> ayahs;

  /// A structured list of [Line] objects representing the visual rows on the page.
  List<Line> lines;

  /// The Hizb number (part of a Juzz) that this page belongs to or starts with.
  int? hizb;

  /// Indicates if any Ayah on this page contains a prostration mark (Sajda).
  bool hasSajda;

  /// Indicates if this is the final line of a Surah or the Mushaf.
  bool lastLine;

  /// The surah whose banner the print draws on this page's last line, under
  /// the text, while the surah itself opens on the next page with its
  /// basmala (see [surahsWithBannerOnPreviousPage]). Null on most pages.
  int? trailingBannerSurah;

  /// Creates a [QuranPage] with the required layout and content data.
  QuranPage({
    required this.pageNumber,
    required this.ayahs,
    required this.lines,
    this.hizb,
    this.hasSajda = false,
    this.lastLine = false,
    this.numberOfNewSurahs = 0,
    this.trailingBannerSurah,
  });
}

/// Surahs whose banner the King Fahd 1421 Madinah print puts on the LAST line
/// of the previous page (14 lines of text there); the surah's own page opens
/// with the basmala and 14 lines of text. Checked against the print's line
/// table for all 604 pages (tool/print_lines_1421.json, tool/fix_print_lines.py).
const Set<int> surahsWithBannerOnPreviousPage = {
  4, 10, 22, 23, 24, 26, 27, 32, 33, 37, 38, 45, 47, 53, 60, 64, 65, 80,
};

/// Represents a single horizontal row of text on a Quranic page.
///
/// In high-quality Mushaf layouts, an Ayah can span across multiple lines,
/// and a single line can contain multiple short Ayahs.
class Line {
  /// The collection of [Ayah] segments or full verses present in this specific line.
  List<Ayah> ayahs;

  /// Whether the text in this line should be horizontally centered.
  /// Often true for the start of Surahs (like Al-Fatiha) or very short final lines.
  bool centered;

  /// Creates a [Line] instance containing a list of verses.
  Line(this.ayahs, {this.centered = false});
}
