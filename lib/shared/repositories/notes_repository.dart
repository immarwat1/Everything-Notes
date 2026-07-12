import 'package:everything_notes_offline/core/database/app_database.dart';
import 'package:everything_notes_offline/shared/models/attachment.dart';
import 'package:everything_notes_offline/shared/models/folder.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:everything_notes_offline/shared/models/note_statistics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => throw UnimplementedError('NotesRepository must be overridden.'),
);

final notesControllerProvider =
    StateNotifierProvider<NotesController, AsyncValue<List<Note>>>((ref) {
      return NotesController(ref.watch(notesRepositoryProvider))..load();
    });

final foldersControllerProvider =
    StateNotifierProvider<FoldersController, AsyncValue<List<Folder>>>((ref) {
      return FoldersController(ref.watch(notesRepositoryProvider))..load();
    });

final statisticsProvider = FutureProvider<NoteStatistics>((ref) {
  ref.watch(notesControllerProvider);
  ref.watch(foldersControllerProvider);
  return ref.watch(notesRepositoryProvider).statistics();
});

final searchProvider = FutureProvider.family<List<Note>, String>((ref, query) {
  ref.watch(notesControllerProvider);
  return ref.watch(notesRepositoryProvider).search(query);
});

class NotesRepository {
  NotesRepository(this._database);

  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  Future<List<Note>> listNotes({
    bool includeArchived = false,
    bool includeTrashed = false,
    String? folderId,
  }) {
    return _database.listNotes(
      includeArchived: includeArchived,
      includeTrashed: includeTrashed,
      folderId: folderId,
    );
  }

  Future<Note?> getNote(String id) => _database.getNote(id);

  Future<Note> createNote({
    String? title,
    String content = '',
    String? folderId,
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      title: title ?? 'Untitled note',
      content: content,
      folderId: folderId,
      createdAt: now,
      updatedAt: now,
    );
    await _database.upsertNote(note);
    return note;
  }

  Future<void> saveNote(Note note) async {
    await _database.upsertNote(note.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> snapshot(Note note) => _database.snapshotNote(note);

  Future<void> moveToTrash(Note note) {
    return saveNote(note.copyWith(isTrashed: true, isArchived: false));
  }

  Future<void> restore(Note note) {
    return saveNote(note.copyWith(isTrashed: false, isArchived: false));
  }

  Future<void> archive(Note note) {
    return saveNote(note.copyWith(isArchived: true));
  }

  Future<void> duplicate(Note note) {
    return createNote(
      title: '${note.title} copy',
      content: note.content,
      folderId: note.folderId,
    );
  }

  Future<void> deletePermanently(String id) =>
      _database.deleteNotePermanently(id);

  Future<List<Note>> search(String query) => _database.searchNotes(query);

  Future<List<Folder>> listFolders() => _database.listFolders();

  Future<Folder> createFolder({
    required String name,
    String? parentId,
    int colorHex = 0xFF1565C0,
    String icon = 'folder',
  }) async {
    final now = DateTime.now();
    final folder = Folder(
      id: _uuid.v4(),
      name: name,
      parentId: parentId,
      colorHex: colorHex,
      icon: icon,
      createdAt: now,
      updatedAt: now,
    );
    await _database.upsertFolder(folder);
    return folder;
  }

  Future<void> saveFolder(Folder folder) {
    return _database.upsertFolder(folder.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> deleteFolder(String id) => _database.deleteFolder(id);

  Future<void> attachFile(NoteAttachment attachment) =>
      _database.addAttachment(attachment);

  Future<void> recordImageReference({
    required String id,
    required String noteId,
    required String path,
    required String caption,
    required int bytes,
  }) {
    return _database.addImageReference(
      id: id,
      noteId: noteId,
      path: path,
      caption: caption,
      bytes: bytes,
    );
  }

  Future<List<NoteAttachment>> attachmentsFor(String noteId) {
    return _database.attachmentsFor(noteId);
  }

  Future<NoteStatistics> statistics() => _database.statistics();
}

class NotesController extends StateNotifier<AsyncValue<List<Note>>> {
  NotesController(this._repository) : super(const AsyncValue.loading());

  final NotesRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.listNotes(includeArchived: true, includeTrashed: true),
    );
  }

  Future<Note> create({
    String? title,
    String content = '',
    String? folderId,
  }) async {
    final note = await _repository.createNote(
      title: title,
      content: content,
      folderId: folderId,
    );
    await load();
    return note;
  }

  Future<void> save(Note note) async {
    await _repository.saveNote(note);
    await load();
  }

  Future<void> togglePinned(Note note) {
    return save(note.copyWith(isPinned: !note.isPinned));
  }

  Future<void> toggleFavorite(Note note) {
    return save(note.copyWith(isFavorite: !note.isFavorite));
  }

  Future<void> archive(Note note) async {
    await _repository.archive(note);
    await load();
  }

  Future<void> moveToTrash(Note note) async {
    await _repository.moveToTrash(note);
    await load();
  }

  Future<void> restore(Note note) async {
    await _repository.restore(note);
    await load();
  }

  Future<void> duplicate(Note note) async {
    await _repository.duplicate(note);
    await load();
  }
}

class FoldersController extends StateNotifier<AsyncValue<List<Folder>>> {
  FoldersController(this._repository) : super(const AsyncValue.loading());

  final NotesRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.listFolders);
  }

  Future<void> create(String name, {String? parentId}) async {
    if (name.trim().isEmpty) {
      return;
    }
    await _repository.createFolder(name: name.trim(), parentId: parentId);
    await load();
  }

  Future<void> save(Folder folder) async {
    await _repository.saveFolder(folder);
    await load();
  }

  Future<void> delete(String id) async {
    await _repository.deleteFolder(id);
    await load();
  }
}
