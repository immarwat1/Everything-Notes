import 'package:everything_notes_offline/core/localization/app_localizations.dart';
import 'package:everything_notes_offline/core/navigation/app_router.dart';
import 'package:everything_notes_offline/core/services/security_service.dart';
import 'package:everything_notes_offline/core/services/settings_service.dart';
import 'package:everything_notes_offline/core/theme/app_theme.dart';
import 'package:everything_notes_offline/features/backup/presentation/backup_screen.dart';
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
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      onGenerateRoute: AppRoutes.onGenerateRoute,
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
    final strings = AppLocalizations.of(context);
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
                    strings.text('unlockTitle'),
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
                    child: Text(strings.text('unlock')),
                  ),
                  TextButton.icon(
                    onPressed: _unlockWithBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(strings.text('useBiometrics')),
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

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    FoldersScreen(),
    BackupScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        label: strings.text('home'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.search),
        label: strings.text('search'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.folder_outlined),
        label: strings.text('folders'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.backup_outlined),
        label: strings.text('backup'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        label: strings.text('settings'),
      ),
    ];
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
                  destinations: destinations
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
                  destinations: destinations,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                ),
          floatingActionButton: _index == 0
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.editor),
                  icon: const Icon(Icons.note_add_outlined),
                  label: Text(strings.text('newNote')),
                )
              : null,
        );
      },
    );
  }
}
