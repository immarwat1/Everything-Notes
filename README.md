# Everything Notes Offline

Everything Notes Offline is an offline-first Flutter document editor and
note-taking application for Android and iOS. It stores user data locally, uses
SQLite for structured note data and full-text search, and uses Hive for
lightweight preferences such as theme, language, editor font size, backups, and
security settings.

## Implemented baseline

- Material 3 Android/iOS Flutter app scaffold.
- Clean, feature-first `lib/` layout with `core/`, `features/`, and `shared/`.
- Riverpod state management and repository boundaries.
- Local SQLite schema for notes, folders, attachments, history, templates,
  backups, settings, plus FTS5 search triggers with a LIKE fallback.
- Hive-backed settings.
- Home screen with recent, pinned, favorite, archive, trash, statistics, sort,
  grid/list view, and note actions.
- Autosaving editor with formatting toolbar, tables via Markdown syntax,
  attachments, image references, templates, import, find/replace, counters, and
  PDF/TXT/Markdown/HTML/JSON export.
- Folder management with nested folders.
- Instant local search with highlighted snippets.
- Local backup and restore.
- Theme, language, font-size, accent-color, PIN, and biometric settings.
- Focused unit tests for document metrics and search helpers.

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
flutter run
```

The app is designed to avoid Firebase, Supabase, cloud services, authentication
servers, or internet requirements for primary functionality.
