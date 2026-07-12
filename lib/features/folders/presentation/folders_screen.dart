import 'package:everything_notes_offline/core/navigation/app_router.dart';
import 'package:everything_notes_offline/shared/models/folder.dart';
import 'package:everything_notes_offline/shared/repositories/notes_repository.dart';
import 'package:everything_notes_offline/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Folders'),
        actions: [
          IconButton(
            tooltip: 'New folder',
            onPressed: () => _showFolderDialog(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      body: folders.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open,
              title: 'No folders yet',
              message: 'Organize unlimited notes with nested local folders.',
              action: FilledButton.icon(
                onPressed: () => _showFolderDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create folder'),
              ),
            );
          }
          final roots = items
              .where((folder) => folder.parentId == null)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final folder in roots)
                _FolderNode(folder: folder, allFolders: items, depth: 0),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.error_outline,
          title: 'Folders failed to load',
          message: '$error',
        ),
      ),
    );
  }

  static Future<void> _showFolderDialog(
    BuildContext context,
    WidgetRef ref, {
    Folder? parent,
    Folder? editing,
  }) async {
    final controller = TextEditingController(text: editing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editing == null ? 'New folder' : 'Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
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
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final folders = ref.read(foldersControllerProvider.notifier);
    if (editing == null) {
      await folders.create(name, parentId: parent?.id);
    } else {
      await folders.save(editing.copyWith(name: name.trim()));
    }
  }
}

class _FolderNode extends ConsumerWidget {
  const _FolderNode({
    required this.folder,
    required this.allFolders,
    required this.depth,
  });

  final Folder folder;
  final List<Folder> allFolders;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = allFolders
        .where((child) => child.parentId == folder.id)
        .toList();
    return Padding(
      padding: EdgeInsets.only(left: depth * 16),
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(folder.colorHex),
                child: const Icon(Icons.folder, color: Colors.white),
              ),
              title: Text(folder.name),
              subtitle: Text(
                children.isEmpty
                    ? 'No subfolders'
                    : '${children.length} subfolders',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'note':
                      Navigator.of(context).pushNamed(
                        AppRoutes.editor,
                        arguments: EditorRouteArgs(initialFolderId: folder.id),
                      );
                    case 'subfolder':
                      await FoldersScreen._showFolderDialog(
                        context,
                        ref,
                        parent: folder,
                      );
                    case 'rename':
                      await FoldersScreen._showFolderDialog(
                        context,
                        ref,
                        editing: folder,
                      );
                    case 'delete':
                      await ref
                          .read(foldersControllerProvider.notifier)
                          .delete(folder.id);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'note', child: Text('New note here')),
                  PopupMenuItem(
                    value: 'subfolder',
                    child: Text('New subfolder'),
                  ),
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ),
          for (final child in children)
            _FolderNode(
              folder: child,
              allFolders: allFolders,
              depth: depth + 1,
            ),
        ],
      ),
    );
  }
}
