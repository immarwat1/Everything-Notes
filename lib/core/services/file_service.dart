import 'dart:convert';
import 'dart:io';

import 'package:everything_notes_offline/core/database/app_database.dart';
import 'package:everything_notes_offline/core/services/docx_service.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:file_selector/file_selector.dart';
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

  Future<String?> importDocumentFile() async {
    const documentTypes = XTypeGroup(
      label: 'Documents',
      extensions: ['docx', 'txt', 'md', 'markdown', 'html', 'htm', 'rtf'],
    );
    final file = await openFile(acceptedTypeGroups: [documentTypes]);
    if (file == null) {
      return null;
    }
    final extension = p.extension(file.name).toLowerCase();
    if (extension == '.docx') {
      final source = await _xFileAsFile(file);
      return DocxService.importDocx(source);
    }

    final content = await file.readAsString();
    if (extension == '.html' || extension == '.htm') {
      return _htmlToText(content);
    }
    if (extension == '.rtf') {
      return _rtfToText(content);
    }
    return content;
  }

  Future<String?> importTextFile() => importDocumentFile();

  Future<File> _xFileAsFile(XFile file) async {
    final existing = File(file.path);
    if (await existing.exists()) {
      return existing;
    }
    final directory = await getTemporaryDirectory();
    final copy = File(p.join(directory.path, file.name));
    await copy.writeAsBytes(await file.readAsBytes());
    return copy;
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
      case ExportFormat.docx:
        return file.writeAsBytes(DocxService.exportDocx(note));
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
    final written = await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    final stats = await _database.statistics();
    await _database.recordBackup(
      id: timestamp,
      path: written.path,
      noteCount: stats.totalNotes,
    );
    return written;
  }

  Future<void> restoreNotesFromBackup() async {
    const backupType = XTypeGroup(
      label: 'Everything Notes backup',
      extensions: ['json'],
    );
    final file = await openFile(acceptedTypeGroups: [backupType]);
    if (file == null) {
      return;
    }
    final content = await file.readAsString();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final tables = decoded['tables'] as List<dynamic>;
    await _database.restoreTables(
      tables
          .cast<Map<String, dynamic>>()
          .map((table) => Map<String, Object?>.from(table))
          .toList(),
    );
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

  String _htmlToText(String value) {
    return value
        .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</\s*(p|div|h[1-6]|li|tr)\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

  String _rtfToText(String value) {
    return value
        .replaceAll(RegExp(r'\\par[d]?'), '\n')
        .replaceAll(RegExp(r'\\[a-zA-Z]+\d* ?'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
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
  json('JSON', 'json'),
  docx('DOCX', 'docx');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}
