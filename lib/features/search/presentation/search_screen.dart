import 'dart:async';

import 'package:everything_notes_offline/core/navigation/app_router.dart';
import 'package:everything_notes_offline/shared/repositories/notes_repository.dart';
import 'package:everything_notes_offline/shared/widgets/empty_state.dart';
import 'package:everything_notes_offline/shared/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _controller,
              hintText: 'Search notes, tags, tables, and attachments',
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 120), () {
                  setState(() => _query = value);
                });
              },
            ),
          ),
          Expanded(
            child: results.when(
              data: (notes) {
                if (_query.trim().isEmpty) {
                  return const EmptyState(
                    icon: Icons.search,
                    title: 'Instant offline search',
                    message:
                        'Type to search note titles, content, and tags using local SQLite.',
                  );
                }
                if (notes.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No results',
                    message: 'No local notes matched "$_query".',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return NoteCard(
                      note: note,
                      query: _query,
                      onTap: () => Navigator.of(context).pushNamed(
                        AppRoutes.editor,
                        arguments: EditorRouteArgs(noteId: note.id),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => EmptyState(
                icon: Icons.error_outline,
                title: 'Search failed',
                message: '$error',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
