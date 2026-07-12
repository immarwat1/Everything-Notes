import 'package:everything_notes_offline/features/backup/presentation/backup_screen.dart';
import 'package:everything_notes_offline/features/editor/presentation/editor_screen.dart';
import 'package:everything_notes_offline/features/folders/presentation/folders_screen.dart';
import 'package:everything_notes_offline/features/home/presentation/home_screen.dart';
import 'package:everything_notes_offline/features/search/presentation/search_screen.dart';
import 'package:everything_notes_offline/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';

class AppRoutes {
  const AppRoutes._();

  static const root = '/';
  static const home = '/home';
  static const search = '/search';
  static const folders = '/folders';
  static const backup = '/backup';
  static const settings = '/settings';
  static const editor = '/editor';

  static Route<void> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        switch (settings.name) {
          case root:
          case home:
            return const HomeScreen();
          case search:
            return const SearchScreen();
          case folders:
            return const FoldersScreen();
          case backup:
            return const BackupScreen();
          case AppRoutes.settings:
            return const SettingsScreen();
          case editor:
            final args = settings.arguments;
            if (args is EditorRouteArgs) {
              return EditorScreen(
                noteId: args.noteId,
                initialFolderId: args.initialFolderId,
              );
            }
            return const EditorScreen();
          default:
            return const HomeScreen();
        }
      },
    );
  }
}

class EditorRouteArgs {
  const EditorRouteArgs({this.noteId, this.initialFolderId});

  final String? noteId;
  final String? initialFolderId;
}
