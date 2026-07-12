import 'package:everything_notes_offline/app.dart';
import 'package:everything_notes_offline/core/database/app_database.dart';
import 'package:everything_notes_offline/core/services/settings_service.dart';
import 'package:everything_notes_offline/shared/repositories/notes_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = await AppDatabase.open();
  final settings = await SettingsService.open();
  final repository = NotesRepository(database);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsServiceProvider.overrideWithValue(settings),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: const EverythingNotesOfflineApp(),
    ),
  );
}
