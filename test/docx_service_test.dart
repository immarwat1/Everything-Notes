import 'dart:io';

import 'package:everything_notes_offline/core/services/docx_service.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports and imports a minimal DOCX document offline', () async {
    final now = DateTime(2026, 7, 12);
    final note = Note(
      id: 'note-1',
      title: 'Offline DOCX',
      content: 'First paragraph\nSecond paragraph',
      createdAt: now,
      updatedAt: now,
    );

    final bytes = DocxService.exportDocx(note);
    final file = File('${Directory.systemTemp.path}/offline_docx_test.docx');
    await file.writeAsBytes(bytes);
    addTearDown(() async {
      if (await file.exists()) {
        await file.delete();
      }
    });

    final imported = await DocxService.importDocx(file);

    expect(imported, contains('Offline DOCX'));
    expect(imported, contains('First paragraph'));
    expect(imported, contains('Second paragraph'));
  });
}
