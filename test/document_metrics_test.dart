import 'package:everything_notes_offline/core/utils/document_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts words, characters, pages, and reading time', () {
    final metrics = DocumentMetrics.fromText(
      'Hello world. Offline notes are private.',
    );

    expect(metrics.characters, 39);
    expect(metrics.words, 6);
    expect(metrics.pages, 1);
    expect(metrics.readingMinutes, 1);
  });

  test('handles empty documents', () {
    final metrics = DocumentMetrics.fromText('   ');

    expect(metrics.characters, 3);
    expect(metrics.words, 0);
    expect(metrics.pages, 0);
    expect(metrics.readingMinutes, 0);
  });
}
