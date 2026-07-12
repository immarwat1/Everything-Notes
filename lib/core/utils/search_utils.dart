class SearchUtils {
  const SearchUtils._();

  static List<TextHighlight> highlights(String source, String query) {
    if (query.trim().isEmpty || source.isEmpty) {
      return [TextHighlight(source, false)];
    }

    final normalizedSource = source.toLowerCase();
    final normalizedQuery = query.toLowerCase();
    final results = <TextHighlight>[];
    var start = 0;

    while (start < source.length) {
      final index = normalizedSource.indexOf(normalizedQuery, start);
      if (index == -1) {
        results.add(TextHighlight(source.substring(start), false));
        break;
      }
      if (index > start) {
        results.add(TextHighlight(source.substring(start, index), false));
      }
      results.add(
        TextHighlight(
          source.substring(index, index + normalizedQuery.length),
          true,
        ),
      );
      start = index + normalizedQuery.length;
    }

    return results.where((part) => part.text.isNotEmpty).toList();
  }

  static String snippet(String text, String query, {int radius = 64}) {
    if (text.isEmpty) {
      return '';
    }
    final match = text.toLowerCase().indexOf(query.toLowerCase());
    if (query.isEmpty || match < 0) {
      return text.length <= radius * 2
          ? text
          : '${text.substring(0, radius * 2)}...';
    }
    final start = (match - radius).clamp(0, text.length);
    final end = (match + query.length + radius).clamp(0, text.length);
    final prefix = start == 0 ? '' : '...';
    final suffix = end == text.length ? '' : '...';
    return '$prefix${text.substring(start, end)}$suffix';
  }
}

class TextHighlight {
  const TextHighlight(this.text, this.isMatch);

  final String text;
  final bool isMatch;
}
