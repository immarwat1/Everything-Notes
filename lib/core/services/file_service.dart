import 'dart:convert';
import 'dart:io';

import 'package:everything_notes_offline/core/database/app_database.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService(ref.watch(appDatabaseProvider));
});

class FileService {
  FileService(this._database);

  final AppDatabase _database;

  Future<String?> importTextFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'markdown', 'html', 'rtf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).readAsString();
    }
    return null;
  }

  Future<File> exportNote(Note note, ExportFormat format) async {
    final directory = await _exportsDirectory();
    final fileName = _safeFileName(
      note.title.isEmpty ? 'Untitled' : note.title,
    );
    final extension = format.extension;
    final file = File(p.join(directory.path, '$fileName.$extension'));

    switch (format) {
      case ExportFormat.txt:
      case ExportFormat.markdown:
        return file.writeAsString(note.content);
      case ExportFormat.html:
        return file.writeAsString(_toHtml(note));
      case ExportFormat.json:
        return file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(note.toJson()),
        );
      case ExportFormat.pdf:
        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            build: (context) => [
              pw.Header(level: 0, child: pw.Text(note.title)),
              pw.Paragraph(text: note.content),
            ],
          ),
        );
        return file.writeAsBytes(await pdf.save());
    }
  }

  Future<File> createBackup() async {
    final directory = await _backupDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File(
      p.join(directory.path, 'everything_notes_backup_$timestamp.json'),
    );
    final payload = {
      'schemaVersion': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'tables': await _database.exportAllTables(),
    };
    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<void> restoreNotesFromBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final content = file.bytes != null
        ? utf8.decode(file.bytes!)
        : await File(file.path!).readAsString();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final tables = decoded['tables'] as List<dynamic>;
    final notesTable = tables.cast<Map<String, dynamic>>().firstWhere(
      (table) => table['table'] == 'notes',
      orElse: () => {'rows': <dynamic>[]},
    );
    final rows = notesTable['rows'] as List<dynamic>;
    final notes = rows
        .cast<Map<String, dynamic>>()
        .map((row) => Note.fromMap(Map<String, Object?>.from(row)))
        .toList();
    await _database.importNotes(notes);
  }

  Future<Directory> _exportsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'exports'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _backupDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'backups'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _toHtml(Note note) {
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>${_escapeHtml(note.title)}</title>
</head>
<body>
  <article>
    <h1>${_escapeHtml(note.title)}</h1>
    <pre>${_escapeHtml(note.content)}</pre>
  </article>
</body>
</html>
''';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _safeFileName(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^\w\-. ]+'), '_').trim();
    return sanitized.isEmpty ? 'Untitled' : sanitized;
  }
}

enum ExportFormat {
  pdf('PDF', 'pdf'),
  txt('Text', 'txt'),
  markdown('Markdown', 'md'),
  html('HTML', 'html'),
  json('JSON', 'json');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}
