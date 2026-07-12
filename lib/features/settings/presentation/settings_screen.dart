import 'package:everything_notes_offline/core/services/security_service.dart';
import 'package:everything_notes_offline/core/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _accentColors = [
    Color(0xFF00C853),
    Color(0xFF1565C0),
    Color(0xFF7B1FA2),
    Color(0xFFE65100),
    Color(0xFF00897B),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(settings.themeMode.name),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.setThemeMode(value);
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Accent color'),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      for (final color in _accentColors)
                        ChoiceChip(
                          label: const Text(''),
                          selected: color.value == settings.accentColor.value,
                          avatar: CircleAvatar(backgroundColor: color),
                          onSelected: (_) => controller.setAccentColor(color),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Editor font size'),
                  subtitle: Slider(
                    value: settings.editorFontSize,
                    min: 14,
                    max: 28,
                    divisions: 14,
                    label: settings.editorFontSize.toStringAsFixed(0),
                    onChanged: controller.setEditorFontSize,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Language', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('App language'),
              subtitle: const Text('English, Arabic, Spanish, French, Hindi'),
              trailing: DropdownButton<Locale>(
                value: settings.locale,
                items: const [
                  DropdownMenuItem(value: Locale('en'), child: Text('English')),
                  DropdownMenuItem(
                    value: Locale('ar'),
                    child: Text('Arabic RTL'),
                  ),
                  DropdownMenuItem(value: Locale('es'), child: Text('Spanish')),
                  DropdownMenuItem(value: Locale('fr'), child: Text('French')),
                  DropdownMenuItem(value: Locale('hi'), child: Text('Hindi')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.setLocale(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Security', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.pinLockEnabled,
                  title: const Text('PIN lock'),
                  subtitle: const Text(
                    'Protect local notes with a device-only PIN hash.',
                  ),
                  onChanged: (enabled) async {
                    if (enabled) {
                      final pin = await _askForPin(context);
                      if (pin == null || pin.length < 4) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN must be at least 4 digits.'),
                            ),
                          );
                        }
                        return;
                      }
                      await ref.read(securityServiceProvider).setPin(pin);
                    }
                    await controller.setPinLockEnabled(enabled);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('Biometric unlock'),
                  subtitle: const Text(
                    'Uses Android/iOS biometric APIs; no cloud account required.',
                  ),
                  trailing: FilledButton(
                    onPressed: () async {
                      final ok = await ref
                          .read(securityServiceProvider)
                          .authenticateWithBiometrics();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Biometrics ready.'
                                  : 'Biometrics unavailable.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Test'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Backup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              value: settings.autoBackupEnabled,
              title: const Text('Automatic local backup'),
              subtitle: const Text(
                'Keeps scheduled backup preference on device.',
              ),
              onChanged: controller.setAutoBackupEnabled,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _askForPin(BuildContext context) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set PIN'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return pin;
  }
}
