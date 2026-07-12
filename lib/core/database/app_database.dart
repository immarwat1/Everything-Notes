import 'package:everything_notes_offline/shared/models/attachment.dart';
import 'package:everything_notes_offline/shared/models/folder.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:everything_notes_offline/shared/models/note_statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase must be overridden.'),
);

class AppDatabase {
  AppDatabase(this._database);

  final Database _database;

  static Future<AppDatabase> open() async {
    final path = p.join(
      await getDatabasesPath(),
      'everything_notes_offline.db',
    );
    final database = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
    return AppDatabase(database);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT REFERENCES folders(id) ON DELETE CASCADE,
        color_hex INTEGER NOT NULL,
        icon TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_folders_parent ON folders(parent_id)');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        folder_id TEXT REFERENCES folders(id) ON DELETE SET NULL,
        tags TEXT NOT NULL DEFAULT '',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_trashed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_notes_updated ON notes(updated_at DESC)',
    );
    await db.execute('CREATE INDEX idx_notes_folder ON notes(folder_id)');
    await db.execute(
      'CREATE INDEX idx_notes_flags ON notes(is_pinned, is_favorite, is_trashed)',
    );

    await db.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        bytes INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE backups (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        note_count INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _createFts(db);
  }

  static Future<void> _createFts(Database db) async {
    try {
      await db.execute(
        'CREATE VIRTUAL TABLE notes_fts USING fts5(id UNINDEXED, title, content)',
      );
      await db.execute('''
        CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
          INSERT INTO notes_fts(rowid, id, title, content)
          VALUES (new.rowid, new.id, new.title, new.content);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, id, title, content)
          VALUES ('delete', old.rowid, old.id, old.title, old.content);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, id, title, content)
          VALUES ('delete', old.rowid, old.id, old.title, old.content);
          INSERT INTO notes_fts(rowid, id, title, content)
          VALUES (new.rowid, new.id, new.title, new.content);
        END
      ''');
    } on DatabaseException {
      // Older platform SQLite builds can omit FTS5. Search methods fall back to LIKE.
    }
  }

  Future<List<Note>> listNotes({
    bool includeArchived = false,
    bool includeTrashed = false,
    String? folderId,
  }) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (!includeArchived) {
      clauses.add('is_archived = 0');
    }
    if (!includeTrashed) {
      clauses.add('is_trashed = 0');
    }
    if (folderId != null) {
      clauses.add('folder_id = ?');
      args.add(folderId);
    }
    final rows = await _database.query(
      'notes',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'is_pinned DESC, updated_at DESC',
    );
    return rows.map(Note.fromMap).toList();
  }

  Future<Note?> getNote(String id) async {
    final rows = await _database.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Note.fromMap(rows.first);
  }

  Future<void> upsertNote(Note note) async {
    await _database.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> snapshotNote(Note note) async {
    await _database.insert('history', {
      'note_id': note.id,
      'title': note.title,
      'content': note.content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteNotePermanently(String id) async {
    await _database.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> searchNotes(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return listNotes();
    }
    try {
      final rows = await _database.rawQuery(
        '''
        SELECT notes.*
        FROM notes_fts
        JOIN notes ON notes_fts.id = notes.id
        WHERE notes_fts MATCH ? AND notes.is_trashed = 0
        ORDER BY rank, notes.updated_at DESC
        LIMIT 100
        ''',
        ['$trimmed*'],
      );
      return rows.map(Note.fromMap).toList();
    } on DatabaseException {
      final like = '%$trimmed%';
      final rows = await _database.query(
        'notes',
        where:
            '(title LIKE ? OR content LIKE ? OR tags LIKE ?) AND is_trashed = 0',
        whereArgs: [like, like, like],
        orderBy: 'updated_at DESC',
        limit: 100,
      );
      return rows.map(Note.fromMap).toList();
    }
  }

  Future<List<Folder>> listFolders() async {
    final rows = await _database.query(
      'folders',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Folder.fromMap).toList();
  }

  Future<void> upsertFolder(Folder folder) async {
    await _database.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFolder(String id) async {
    await _database.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addAttachment(NoteAttachment attachment) async {
    await _database.insert('attachments', attachment.toMap());
  }

  Future<List<NoteAttachment>> attachmentsFor(String noteId) async {
    final rows = await _database.query(
      'attachments',
      where: 'note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return rows.map(NoteAttachment.fromMap).toList();
  }

  Future<NoteStatistics> statistics() async {
    Future<int> count(String table, [String? where]) async {
      final rows = await _database.rawQuery(
        'SELECT COUNT(*) AS value FROM $table${where == null ? '' : ' WHERE $where'}',
      );
      return rows.first['value'] as int;
    }

    final bytesRows = await _database.rawQuery(
      'SELECT SUM(LENGTH(title) + LENGTH(content)) AS value FROM notes',
    );
    final attachmentRows = await _database.rawQuery(
      'SELECT SUM(bytes) AS value FROM attachments',
    );

    return NoteStatistics(
      totalNotes: await count('notes', 'is_trashed = 0'),
      pinnedNotes: await count('notes', 'is_pinned = 1 AND is_trashed = 0'),
      favoriteNotes: await count('notes', 'is_favorite = 1 AND is_trashed = 0'),
      folderCount: await count('folders'),
      trashedNotes: await count('notes', 'is_trashed = 1'),
      storageBytes:
          ((bytesRows.first['value'] as int?) ?? 0) +
          ((attachmentRows.first['value'] as int?) ?? 0),
    );
  }

  Future<List<Map<String, Object?>>> exportAllTables() async {
    final notes = await _database.query('notes');
    final folders = await _database.query('folders');
    final attachments = await _database.query('attachments');
    return [
      {'table': 'notes', 'rows': notes},
      {'table': 'folders', 'rows': folders},
      {'table': 'attachments', 'rows': attachments},
    ];
  }

  Future<void> importNotes(List<Note> notes) async {
    await _database.transaction((txn) async {
      for (final note in notes) {
        await txn.insert(
          'notes',
          note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> close() => _database.close();
}
