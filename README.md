# Everything Notes Offline

Everything Notes Offline is an offline-first Flutter document editor and
note-taking application for Android and iOS. It stores user data locally, uses
SQLite for structured note data and full-text search, and uses Hive for
lightweight preferences such as theme, language, editor font size, backups, and
security settings.

## Implemented baseline

- Material 3 Android-first Flutter app scaffold.
- Clean, feature-first `lib/` layout with `core/`, `features/`, and `shared/`.
- Riverpod state management and repository boundaries.
- Local SQLite schema for notes, folders, attachments, images, tags, note/tag
  joins, history, templates, trash, favorites, backups, settings, plus FTS5
  search triggers with a LIKE fallback.
- Hive-backed settings.
- Home screen with recent, pinned, favorite, archive, trash, statistics, sort,
  grid/list view, and note actions.
- Autosaving editor with formatting toolbar, tables via Markdown syntax,
  attachments, image references, templates, DOCX/TXT/HTML/Markdown import,
  find/replace, counters, tags, and PDF/DOCX/TXT/Markdown/HTML/JSON export.
- Folder management with nested folders.
- Instant local search with highlighted snippets.
- Local full-data backup and restore.
- Theme, language, font-size, accent-color, PIN, and biometric settings.
- Focused unit tests for document metrics, search helpers, and DOCX round-trip.

## 12-part Android offline implementation map

1. **Project overview, architecture, stack, folder structure**: Flutter + Dart,
   Riverpod, SQLite through `sqflite`, Hive settings, feature-first modules.
2. **Database design**: `lib/core/database/app_database.dart` owns all tables,
   relationships, indexes, migrations, backup export, restore, and FTS rebuilds.
3. **UI/UX design system**: `lib/core/theme/app_theme.dart` defines Material 3
   light/dark themes, rounded inputs/cards, and the required color palette.
4. **Navigation & routing**: `lib/core/navigation/app_router.dart` centralizes
   named routes and editor route arguments.
5. **Home, notes & folders**: `features/home`, `features/folders`, and
   `shared/repositories/notes_repository.dart` handle CRUD, sorting, pinning,
   favorites, archive, trash, duplication, nested folders, and statistics.
6. **Rich text editor**: `features/editor` provides autosave, undo-compatible
   text editing, counters, find/replace, templates, tags, Markdown/HTML rich
   syntax toolbar, colors, alignment, indentation, checklist/list/code/table
   insertion, images, and attachments.
7. **Tables, images & attachments**: tables are inserted as portable Markdown;
   images and generic attachments are stored as local references and indexed in
   SQLite metadata tables.
8. **Import/export**: `core/services/file_service.dart` and
   `core/services/docx_service.dart` support offline DOCX, PDF, TXT, HTML,
   Markdown, and JSON flows.
9. **Search engine & indexing**: SQLite FTS5 indexes title/content/tags, with
   attachment/image fallback matching when FTS5 is unavailable.
10. **Backup & restore**: JSON backups include all app tables and restore in
    relationship-safe order from local files only.
11. **Localization & RTL support**: `core/localization/app_localizations.dart`
    supports English, Arabic, Spanish, French, and Hindi; Material localization
    provides RTL direction for Arabic.
12. **Settings**: `features/settings` controls theme, accent color, font size,
    language, PIN lock, biometric checks, and automatic backup preference.

## Project structure

```text
lib/
  core/
    constants/
    database/
    services/
    theme/
    utils/
  features/
    backup/
    editor/
    folders/
    home/
    search/
    settings/
    templates/
  shared/
    models/
    repositories/
    widgets/
```

## Run locally

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run
```

The app is designed to avoid Firebase, Supabase, cloud services, authentication
servers, or internet requirements for primary functionality.
