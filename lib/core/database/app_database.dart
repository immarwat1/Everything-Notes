import 'package:everything_notes_offline/shared/models/attachment.dart';
import 'package:everything_notes_offline/shared/models/folder.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:everything_notes_offline/shared/models/note_statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase must be overridden.'),
);

class AppDatabase {
  AppDatabase(this._database);

  final Database _database;
  static bool _webFactoryInitialized = false;

  static Future<AppDatabase> open() async {
    if (kIsWeb && !_webFactoryInitialized) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      _webFactoryInitialized = true;
    }
    final path = p.join(
      await getDatabasesPath(),
      'everything_notes_offline.db',
    );
    final database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createExtendedSchema(db);
          await _rebuildFts(db);
        }
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

    await _createExtendedSchema(db);
    await _createFts(db);
  }

  static Future<void> _createExtendedSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        color_hex INTEGER NOT NULL DEFAULT 4289366208,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_tags (
        note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        PRIMARY KEY (note_id, tag_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS images (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        width INTEGER NOT NULL DEFAULT 0,
        height INTEGER NOT NULL DEFAULT 0,
        caption TEXT NOT NULL DEFAULT '',
        bytes INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS trash (
        note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE,
        original_folder_id TEXT,
        deleted_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_note_tags_tag ON note_tags(tag_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_images_note ON images(note_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attachments_note ON attachments(note_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_history_note ON history(note_id, created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_backups_created ON backups(created_at DESC)',
    );
  }

  static Future<void> _rebuildFts(Database db) async {
    await db.execute('DROP TRIGGER IF EXISTS notes_ai');
    await db.execute('DROP TRIGGER IF EXISTS notes_ad');
    await db.execute('DROP TRIGGER IF EXISTS notes_au');
    await db.execute('DROP TABLE IF EXISTS notes_fts');
    await _createFts(db);
    try {
      await db.execute('''
        INSERT INTO notes_fts(rowid, id, title, content, tags)
        SELECT rowid, id, title, content, tags FROM notes
      ''');
    } on DatabaseException {
      // FTS can be unavailable on some SQLite builds; LIKE search still works.
    }
  }

  static Future<void> _createFts(Database db) async {
    try {
      await db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(id UNINDEXED, title, content, tags)',
      );
      await db.execute('''
        CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
          INSERT INTO notes_fts(rowid, id, title, content, tags)
          VALUES (new.rowid, new.id, new.title, new.content, new.tags);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, id, title, content, tags)
          VALUES ('delete', old.rowid, old.id, old.title, old.content, old.tags);
        END
      ''');
      await db.execute('''
        CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
          INSERT INTO notes_fts(notes_fts, rowid, id, title, content, tags)
          VALUES ('delete', old.rowid, old.id, old.title, old.content, old.tags);
          INSERT INTO notes_fts(rowid, id, title, content, tags)
          VALUES (new.rowid, new.id, new.title, new.content, new.tags);
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
    await _database.transaction((txn) async {
      await txn.insert(
        'notes',
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _syncTags(txn, note);
      await _syncMirrors(txn, note);
    });
  }

  Future<void> _syncTags(Transaction txn, Note note) async {
    await txn.delete('note_tags', where: 'note_id = ?', whereArgs: [note.id]);
    for (final rawTag in note.tags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) {
        continue;
      }
      final existing = await txn.query(
        'tags',
        columns: ['id'],
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [tag],
        limit: 1,
      );
      final tagId = existing.isEmpty
          ? 'tag_${DateTime.now().microsecondsSinceEpoch}_$tag'
          : existing.first['id'] as String;
      if (existing.isEmpty) {
        await txn.insert('tags', {
          'id': tagId,
          'name': tag,
          'color_hex': 0xFF1565C0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
      await txn.insert('note_tags', {
        'note_id': note.id,
        'tag_id': tagId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _syncMirrors(Transaction txn, Note note) async {
    if (note.isFavorite) {
      await txn.insert('favorites', {
        'note_id': note.id,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await txn.delete('favorites', where: 'note_id = ?', whereArgs: [note.id]);
    }

    if (note.isTrashed) {
      await txn.insert('trash', {
        'note_id': note.id,
        'original_folder_id': note.folderId,
        'deleted_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await txn.delete('trash', where: 'note_id = ?', whereArgs: [note.id]);
    }
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
        [_ftsQuery(trimmed)],
      );
      return rows.map(Note.fromMap).toList();
    } on DatabaseException {
      final like = '%$trimmed%';
      final rows = await _database.rawQuery(
        '''
        SELECT DISTINCT notes.*
        FROM notes
        LEFT JOIN attachments ON attachments.note_id = notes.id
        LEFT JOIN images ON images.note_id = notes.id
        WHERE (
          notes.title LIKE ?
          OR notes.content LIKE ?
          OR notes.tags LIKE ?
          OR attachments.name LIKE ?
          OR images.caption LIKE ?
        )
        AND notes.is_trashed = 0
        ORDER BY notes.updated_at DESC
        LIMIT 100
        ''',
        [like, like, like, like, like],
      );
      return rows.map(Note.fromMap).toList();
    }
  }

  String _ftsQuery(String query) {
    final tokens = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}_]+', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) => '$token*')
        .join(' ');
    return tokens.isEmpty ? query : tokens;
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

  Future<void> addImageReference({
    required String id,
    required String noteId,
    required String path,
    required String caption,
    required int bytes,
    int width = 0,
    int height = 0,
  }) async {
    await _database.insert('images', {
      'id': id,
      'note_id': noteId,
      'path': path,
      'width': width,
      'height': height,
      'caption': caption,
      'bytes': bytes,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    final tags = await _database.query('tags');
    final noteTags = await _database.query('note_tags');
    final images = await _database.query('images');
    final favorites = await _database.query('favorites');
    final trash = await _database.query('trash');
    final backups = await _database.query('backups');
    final settings = await _database.query('settings');
    return [
      {'table': 'notes', 'rows': notes},
      {'table': 'folders', 'rows': folders},
      {'table': 'attachments', 'rows': attachments},
      {'table': 'tags', 'rows': tags},
      {'table': 'note_tags', 'rows': noteTags},
      {'table': 'images', 'rows': images},
      {'table': 'favorites', 'rows': favorites},
      {'table': 'trash', 'rows': trash},
      {'table': 'backups', 'rows': backups},
      {'table': 'settings', 'rows': settings},
    ];
  }

  Future<void> recordBackup({
    required String id,
    required String path,
    required int noteCount,
  }) async {
    await _database.insert('backups', {
      'id': id,
      'path': path,
      'note_count': noteCount,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> importNotes(List<Note> notes) async {
    await _database.transaction((txn) async {
      for (final note in notes) {
        await txn.insert(
          'notes',
          note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _syncTags(txn, note);
        await _syncMirrors(txn, note);
      }
    });
  }

  Future<void> restoreTables(List<Map<String, Object?>> tables) async {
    final byName = {
      for (final table in tables)
        table['table'] as String: table['rows'] as List,
    };

    Future<void> restoreRows(String tableName) async {
      final rows = byName[tableName];
      if (rows == null) {
        return;
      }
      await _database.transaction((txn) async {
        for (final row in rows.cast<Map>()) {
          await txn.insert(
            tableName,
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    }

    await restoreRows('folders');

    final noteRows = byName['notes'];
    if (noteRows != null) {
      final notes = noteRows
          .cast<Map>()
          .map((row) => Note.fromMap(Map<String, Object?>.from(row)))
          .toList();
      await importNotes(notes);
    }

    for (final table in const [
      'tags',
      'note_tags',
      'attachments',
      'images',
      'favorites',
      'trash',
      'settings',
      'backups',
    ]) {
      await restoreRows(table);
    }
  }

  Future<void> close() => _database.close();
}
