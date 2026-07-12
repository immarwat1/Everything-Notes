import 'package:everything_notes_offline/core/utils/search_utils.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.note,
    required this.onTap,
    this.query = '',
    this.trailing,
    super.key,
  });

  final Note note;
  final VoidCallback onTap;
  final String query;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned) const Icon(Icons.push_pin, size: 18),
                  if (note.isFavorite) const Icon(Icons.star, size: 18),
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 8),
              _HighlightedSnippet(text: note.content, query: query),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(DateFormat.yMMMd().format(note.updatedAt)),
                  ),
                  Chip(
                    avatar: const Icon(Icons.notes, size: 16),
                    label: Text('${note.metrics.words} words'),
                  ),
                  if (note.tags.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.sell_outlined, size: 16),
                      label: Text(note.tags.join(', ')),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedSnippet extends StatelessWidget {
  const _HighlightedSnippet({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final snippet = SearchUtils.snippet(text, query);
    final parts = SearchUtils.highlights(snippet, query);
    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          for (final part in parts)
            TextSpan(
              text: part.text,
              style: part.isMatch
                  ? TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      fontWeight: FontWeight.w700,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
