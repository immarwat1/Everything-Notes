class DocumentMetrics {
  const DocumentMetrics({
    required this.characters,
    required this.words,
    required this.pages,
    required this.readingMinutes,
  });

  final int characters;
  final int words;
  final int pages;
  final int readingMinutes;

  static DocumentMetrics fromText(String text) {
    final trimmed = text.trim();
    final words = trimmed.isEmpty
        ? 0
        : RegExp(
            r"\b[\p{L}\p{N}'-]+\b",
            unicode: true,
          ).allMatches(trimmed).length;
    final pages = words == 0 ? 0 : (words / 500).ceil();
    final readingMinutes = words == 0 ? 0 : (words / 225).ceil();

    return DocumentMetrics(
      characters: text.runes.length,
      words: words,
      pages: pages,
      readingMinutes: readingMinutes,
    );
  }
}
