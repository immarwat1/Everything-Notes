import 'package:everything_notes_offline/core/utils/search_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('highlights case-insensitive matches', () {
    final highlights = SearchUtils.highlights(
      'Offline notes work offline',
      'OFFLINE',
    );

    expect(highlights.length, 3);
    expect(highlights[0].text, 'Offline');
    expect(highlights[0].isMatch, isTrue);
    expect(highlights[2].text, 'offline');
    expect(highlights[2].isMatch, isTrue);
  });

  test('creates centered snippets around matches', () {
    final snippet = SearchUtils.snippet(
      'Before before before target after after after',
      'target',
      radius: 7,
    );

    expect(snippet, '...before target after ...');
  });
}
