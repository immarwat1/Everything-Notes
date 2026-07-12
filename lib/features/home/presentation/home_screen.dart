import 'package:everything_notes_offline/features/editor/presentation/editor_screen.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:everything_notes_offline/shared/repositories/notes_repository.dart';
import 'package:everything_notes_offline/shared/widgets/empty_state.dart';
import 'package:everything_notes_offline/shared/widgets/metric_card.dart';
import 'package:everything_notes_offline/shared/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomeFilter { all, pinned, favorites, archived, trash }

enum NoteSort { updated, title, created, words }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeFilter _filter = HomeFilter.all;
  NoteSort _sort = NoteSort.updated;
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesControllerProvider);
    final stats = ref.watch(statisticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Everything Notes Offline'),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(
              _grid ? Icons.view_agenda_outlined : Icons.grid_view_outlined,
            ),
          ),
          PopupMenuButton<NoteSort>(
            tooltip: 'Sort notes',
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (context) => const [
              PopupMenuItem(value: NoteSort.updated, child: Text('Updated')),
              PopupMenuItem(value: NoteSort.created, child: Text('Created')),
              PopupMenuItem(value: NoteSort.title, child: Text('Title')),
              PopupMenuItem(value: NoteSort.words, child: Text('Word count')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notesControllerProvider.notifier).load(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: stats.when(
                  data: (value) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          label: 'Notes',
                          value: '${value.totalNotes}',
                          icon: Icons.description_outlined,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          label: 'Favorites',
                          value: '${value.favoriteNotes}',
                          icon: Icons.star_outline,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          label: 'Folders',
                          value: '${value.folderCount}',
                          icon: Icons.folder_outlined,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: MetricCard(
                          label: 'Storage used',
                          value: value.storageLabel,
                          icon: Icons.storage_outlined,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) =>
                      Text('Could not load statistics: $error'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<HomeFilter>(
                  segments: const [
                    ButtonSegment(value: HomeFilter.all, label: Text('Recent')),
                    ButtonSegment(
                      value: HomeFilter.pinned,
                      label: Text('Pinned'),
                    ),
                    ButtonSegment(
                      value: HomeFilter.favorites,
                      label: Text('Favorites'),
                    ),
                    ButtonSegment(
                      value: HomeFilter.archived,
                      label: Text('Archive'),
                    ),
                    ButtonSegment(
                      value: HomeFilter.trash,
                      label: Text('Trash'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
            ),
            notes.when(
              data: (items) {
                final visible = _filtered(items);
                if (visible.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.note_alt_outlined,
                      title: 'No notes here yet',
                      message:
                          'Create a note, import a text file, or restore a backup.',
                      action: FilledButton.icon(
                        onPressed: _openNewNote,
                        icon: const Icon(Icons.add),
                        label: const Text('Create note'),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: _grid
                      ? SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 360,
                                mainAxisExtent: 220,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) =>
                              _NoteTile(note: visible[index]),
                        )
                      : SliverList.separated(
                          itemCount: visible.length,
                          itemBuilder: (context, index) =>
                              _NoteTile(note: visible[index]),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                        ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load notes',
                  message: '$error',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Note> _filtered(List<Note> notes) {
    final filtered = notes.where((note) {
      return switch (_filter) {
        HomeFilter.all => !note.isArchived && !note.isTrashed,
        HomeFilter.pinned => note.isPinned && !note.isTrashed,
        HomeFilter.favorites => note.isFavorite && !note.isTrashed,
        HomeFilter.archived => note.isArchived && !note.isTrashed,
        HomeFilter.trash => note.isTrashed,
      };
    }).toList();
    filtered.sort((a, b) {
      return switch (_sort) {
        NoteSort.updated => b.updatedAt.compareTo(a.updatedAt),
        NoteSort.created => b.createdAt.compareTo(a.createdAt),
        NoteSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        NoteSort.words => b.metrics.words.compareTo(a.metrics.words),
      };
    });
    return filtered;
  }

  void _openNewNote() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditorScreen()));
  }
}

class _NoteTile extends ConsumerWidget {
  const _NoteTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(notesControllerProvider.notifier);
    return NoteCard(
      note: note,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditorScreen(noteId: note.id)),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'pin':
              await controller.togglePinned(note);
            case 'favorite':
              await controller.toggleFavorite(note);
            case 'duplicate':
              await controller.duplicate(note);
            case 'archive':
              await controller.archive(note);
            case 'trash':
              await controller.moveToTrash(note);
            case 'restore':
              await controller.restore(note);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'pin',
            child: Text(note.isPinned ? 'Unpin' : 'Pin'),
          ),
          PopupMenuItem(
            value: 'favorite',
            child: Text(note.isFavorite ? 'Unfavorite' : 'Favorite'),
          ),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          if (!note.isArchived && !note.isTrashed)
            const PopupMenuItem(value: 'archive', child: Text('Archive')),
          if (note.isTrashed)
            const PopupMenuItem(value: 'restore', child: Text('Restore'))
          else
            const PopupMenuItem(value: 'trash', child: Text('Move to trash')),
        ],
      ),
    );
  }
}
