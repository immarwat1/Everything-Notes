import 'package:everything_notes_offline/core/services/file_service.dart';
import 'package:everything_notes_offline/shared/repositories/notes_repository.dart';
import 'package:everything_notes_offline/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  String? _lastMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_lastMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(_lastMessage!),
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Create local backup'),
              subtitle: const Text(
                'Writes an offline JSON backup into app storage.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _createBackup,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restore backup'),
              subtitle: const Text(
                'Imports notes from a previously exported JSON backup.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _restoreBackup,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Export notes as PDF/TXT/Markdown/HTML/JSON'),
              subtitle: const Text(
                'Open a note and use the menu to export that document.',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Open any note and choose Export from its menu.',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Offline by design',
            message:
                'Backups never leave this device unless you move the exported file yourself.',
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    await _run(() async {
      final file = await ref.read(fileServiceProvider).createBackup();
      _lastMessage = 'Backup created at ${file.path}';
    });
  }

  Future<void> _restoreBackup() async {
    await _run(() async {
      await ref.read(fileServiceProvider).restoreNotesFromBackup();
      await ref.read(notesControllerProvider.notifier).load();
      _lastMessage = 'Backup restored.';
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _lastMessage = null;
    });
    try {
      await action();
    } catch (error) {
      _lastMessage = 'Operation failed: $error';
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
