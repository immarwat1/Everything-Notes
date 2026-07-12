import 'package:everything_notes_offline/core/services/security_service.dart';
import 'package:everything_notes_offline/core/services/settings_service.dart';
import 'package:everything_notes_offline/core/theme/app_theme.dart';
import 'package:everything_notes_offline/features/backup/presentation/backup_screen.dart';
import 'package:everything_notes_offline/features/editor/presentation/editor_screen.dart';
import 'package:everything_notes_offline/features/folders/presentation/folders_screen.dart';
import 'package:everything_notes_offline/features/home/presentation/home_screen.dart';
import 'package:everything_notes_offline/features/search/presentation/search_screen.dart';
import 'package:everything_notes_offline/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EverythingNotesOfflineApp extends ConsumerWidget {
  const EverythingNotesOfflineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Everything Notes Offline',
      theme: AppTheme.light(settings.accentColor),
      darkTheme: AppTheme.dark(settings.accentColor),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('es'),
        Locale('fr'),
        Locale('hi'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const AppLockGate(child: MainScaffold()),
    );
  }
}

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  bool _isUnlocked = false;
  String _pin = '';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsControllerProvider);
    _isUnlocked = !settings.pinLockEnabled;
  }

  Future<void> _unlockWithBiometrics() async {
    final security = ref.read(securityServiceProvider);
    final unlocked = await security.authenticateWithBiometrics();
    if (!mounted) {
      return;
    }
    if (unlocked) {
      setState(() => _isUnlocked = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric unlock was not approved.')),
      );
    }
  }

  Future<void> _unlockWithPin() async {
    final security = ref.read(securityServiceProvider);
    final unlocked = await security.verifyPin(_pin);
    if (!mounted) {
      return;
    }
    if (unlocked) {
      setState(() => _isUnlocked = true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect PIN.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    if (!settings.pinLockEnabled || _isUnlocked) {
      return widget.child;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Everything Notes Offline is locked',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _pin = value,
                    onSubmitted: (_) => _unlockWithPin(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _unlockWithPin,
                    child: const Text('Unlock'),
                  ),
                  TextButton.icon(
                    onPressed: _unlockWithBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Use biometrics'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
    NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Folders'),
    NavigationDestination(icon: Icon(Icons.backup_outlined), label: 'Backup'),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Settings',
    ),
  ];

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    FoldersScreen(),
    BackupScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 780;
        return Scaffold(
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: _index,
                  extended: constraints.maxWidth >= 1100,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  destinations: _destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: destination.icon,
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                ),
              Expanded(child: _screens[_index]),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  destinations: _destinations,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                ),
          floatingActionButton: _index == 0
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EditorScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('New note'),
                )
              : null,
        );
      },
    );
  }
}
