import 'dart:async';
import 'dart:io';

import 'package:everything_notes_offline/core/constants/app_constants.dart';
import 'package:everything_notes_offline/core/services/file_service.dart';
import 'package:everything_notes_offline/core/services/settings_service.dart';
import 'package:everything_notes_offline/core/utils/document_metrics.dart';
import 'package:everything_notes_offline/features/templates/data/templates.dart';
import 'package:everything_notes_offline/shared/models/attachment.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:everything_notes_offline/shared/repositories/notes_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({this.noteId, this.initialFolderId, super.key});

  final String? noteId;
  final String? initialFolderId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _autosaveTimer;
  Note? _note;
  bool _loading = true;
  bool _dirty = false;
  String _status = 'Saved locally';

  @override
  void initState() {
    super.initState();
    _load();
    _autosaveTimer = Timer.periodic(
      AppConstants.autosaveInterval,
      (_) => _autosave(),
    );
    _titleController.addListener(_markDirty);
    _tagsController.addListener(_markDirty);
    _contentController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _titleController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.noteId != null) {
      final repository = ref.read(notesRepositoryProvider);
      _note = await repository.getNote(widget.noteId!);
      if (_note != null) {
        _titleController.text = _note!.title;
        _tagsController.text = _note!.tags.join(', ');
        _contentController.text = _note!.content;
      }
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() {
        _dirty = true;
        _status = 'Unsaved changes';
      });
    }
  }

  Future<Note> _ensureNote() async {
    final controller = ref.read(notesControllerProvider.notifier);
    final title = _titleController.text.trim().isEmpty
        ? 'Untitled note'
        : _titleController.text.trim();
    _note ??= await controller.create(
      title: title,
      content: _contentController.text,
      folderId: widget.initialFolderId,
    );
    return _note!;
  }

  Future<void> _autosave({bool force = false}) async {
    if (!_dirty && !force) {
      return;
    }
    final controller = ref.read(notesControllerProvider.notifier);
    final current = await _ensureNote();
    final updated = current.copyWith(
      title: _titleController.text.trim().isEmpty
          ? 'Untitled note'
          : _titleController.text.trim(),
      content: _contentController.text,
      tags: _parseTags(_tagsController.text),
    );
    await controller.save(updated);
    _note = updated.copyWith(updatedAt: DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() {
      _dirty = false;
      _status = 'Saved locally';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final metrics = DocumentMetrics.fromText(_contentController.text);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _autosave(force: true);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.noteId == null ? 'New note' : 'Edit note'),
          actions: [
            IconButton(
              tooltip: 'Find and replace',
              onPressed: _showFindReplace,
              icon: const Icon(Icons.find_replace),
            ),
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'template',
                  child: Text('Apply template'),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import DOCX/TXT/HTML/Markdown'),
                ),
                const PopupMenuItem(
                  value: 'image',
                  child: Text('Insert image reference'),
                ),
                const PopupMenuItem(
                  value: 'camera',
                  child: Text('Capture image reference'),
                ),
                const PopupMenuDivider(),
                for (final format in ExportFormat.values)
                  PopupMenuItem(
                    value: 'export:${format.name}',
                    child: Text('Export ${format.label}'),
                  ),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _EditorToolbar(onCommand: _applyCommand),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        TextField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          style: Theme.of(context).textTheme.headlineSmall,
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            border: InputBorder.none,
                          ),
                        ),
                        TextField(
                          controller: _tagsController,
                          decoration: const InputDecoration(
                            hintText: 'Tags (comma separated)',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contentController,
                          focusNode: _contentFocus,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          minLines: 24,
                          style: TextStyle(
                            fontSize: settings.editorFontSize,
                            height: 1.45,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Start writing offline...',
                            alignLabelWithHint: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(_status),
                          Text('${metrics.characters} chars'),
                          Text('${metrics.words} words'),
                          Text('${metrics.pages} pages'),
                          Text('${metrics.readingMinutes} min read'),
                          FilledButton.icon(
                            onPressed: () => _autosave(force: true),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleMenuAction(String value) async {
    if (value == 'template') {
      await _showTemplatePicker();
      return;
    }
    if (value == 'import') {
      final text = await ref.read(fileServiceProvider).importDocumentFile();
      if (text != null) {
        _insertText(text);
      }
      return;
    }
    if (value == 'image') {
      await _insertImage(ImageSource.gallery);
      return;
    }
    if (value == 'camera') {
      await _insertImage(ImageSource.camera);
      return;
    }
    if (value.startsWith('export:')) {
      await _autosave(force: true);
      final note = await _ensureNote();
      final format = ExportFormat.values.byName(value.split(':').last);
      final file = await ref.read(fileServiceProvider).exportNote(note, format);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
    }
  }

  Future<void> _insertImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(source: source);
    if (image == null) {
      return;
    }
    final note = await _ensureNote();
    final imageId = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = await File(image.path).length();
    await ref
        .read(notesRepositoryProvider)
        .attachFile(
          NoteAttachment(
            id: imageId,
            noteId: note.id,
            name: p.basename(image.path),
            path: image.path,
            mimeType: 'image/${p.extension(image.path).replaceAll('.', '')}',
            bytes: bytes,
            createdAt: DateTime.now(),
          ),
        );
    await ref
        .read(notesRepositoryProvider)
        .recordImageReference(
          id: imageId,
          noteId: note.id,
          path: image.path,
          caption: p.basenameWithoutExtension(image.path),
          bytes: bytes,
        );
    _insertText('\n![${p.basename(image.path)}](${image.path})\n');
  }

  Future<void> _showTemplatePicker() async {
    final template = await showModalBottomSheet<NoteTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          for (final template in builtInTemplates)
            ListTile(
              title: Text(template.name),
              onTap: () => Navigator.of(context).pop(template),
            ),
        ],
      ),
    );
    if (template != null) {
      if (_contentController.text.trim().isEmpty) {
        _contentController.text = template.content;
      } else {
        _insertText('\n${template.content}');
      }
    }
  }

  Future<void> _showFindReplace() async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    final result = await showDialog<_FindReplaceResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find and replace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: findController,
              decoration: const InputDecoration(labelText: 'Find'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replaceController,
              decoration: const InputDecoration(labelText: 'Replace with'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              _FindReplaceResult(findController.text, replaceController.text),
            ),
            child: const Text('Replace all'),
          ),
        ],
      ),
    );
    findController.dispose();
    replaceController.dispose();
    if (result == null || result.find.isEmpty) {
      return;
    }
    _contentController.text = _contentController.text.replaceAll(
      result.find,
      result.replace,
    );
  }

  Future<void> _attachGenericFile() async {
    final result = await FilePicker.pickFiles();
    if (result == null || result.files.single.path == null) {
      return;
    }
    final note = await _ensureNote();
    final file = result.files.single;
    await ref
        .read(notesRepositoryProvider)
        .attachFile(
          NoteAttachment(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            noteId: note.id,
            name: file.name,
            path: file.path!,
            mimeType: 'application/octet-stream',
            bytes: file.size,
            createdAt: DateTime.now(),
          ),
        );
    _insertText('\n[Attachment: ${file.name}](${file.path})\n');
  }

  void _applyCommand(_EditorCommand command) {
    switch (command) {
      case _EditorCommand.bold:
        _wrapSelection('**', '**');
      case _EditorCommand.italic:
        _wrapSelection('_', '_');
      case _EditorCommand.underline:
        _wrapSelection('<u>', '</u>');
      case _EditorCommand.strike:
        _wrapSelection('~~', '~~');
      case _EditorCommand.highlight:
        _wrapSelection('==', '==');
      case _EditorCommand.superscript:
        _wrapSelection('<sup>', '</sup>');
      case _EditorCommand.subscript:
        _wrapSelection('<sub>', '</sub>');
      case _EditorCommand.textColor:
        _wrapSelection('<span style="color:#1565C0">', '</span>');
      case _EditorCommand.backgroundColor:
        _wrapSelection('<span style="background-color:#FFF59D">', '</span>');
      case _EditorCommand.h1:
        _prefixLine('# ');
      case _EditorCommand.h2:
        _prefixLine('## ');
      case _EditorCommand.h3:
        _prefixLine('### ');
      case _EditorCommand.quote:
        _prefixLine('> ');
      case _EditorCommand.code:
        _wrapSelection('```\n', '\n```');
      case _EditorCommand.checklist:
        _prefixLine('- [ ] ');
      case _EditorCommand.bullet:
        _prefixLine('- ');
      case _EditorCommand.numbered:
        _prefixLine('1. ');
      case _EditorCommand.alignLeft:
        _wrapSelection('<p align="left">', '</p>');
      case _EditorCommand.alignCenter:
        _wrapSelection('<p align="center">', '</p>');
      case _EditorCommand.alignRight:
        _wrapSelection('<p align="right">', '</p>');
      case _EditorCommand.indent:
        _prefixLine('    ');
      case _EditorCommand.table:
        _showTableDialog();
      case _EditorCommand.attach:
        _attachGenericFile();
    }
  }

  void _wrapSelection(String before, String after) {
    final selection = _contentController.selection;
    final text = _contentController.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final selected = text.substring(start, end);
    final replacement = '$before$selected$after';
    _contentController.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _contentFocus.requestFocus();
  }

  void _prefixLine(String prefix) {
    final selection = _contentController.selection;
    final text = _contentController.text;
    final caret = selection.start < 0 ? text.length : selection.start;
    final lineStart = text.lastIndexOf('\n', caret - 1) + 1;
    _contentController.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: caret + prefix.length),
    );
    _contentFocus.requestFocus();
  }

  void _insertText(String value) {
    final selection = _contentController.selection;
    final text = _contentController.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    _contentController.value = TextEditingValue(
      text: text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    _contentFocus.requestFocus();
  }

  Future<void> _showTableDialog() async {
    final result = await showDialog<_TableSize>(
      context: context,
      builder: (context) {
        var rows = 3;
        var columns = 3;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Insert table'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Rows'),
                  trailing: DropdownButton<int>(
                    value: rows,
                    items: [
                      for (var value = 2; value <= 10; value++)
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => rows = value ?? rows),
                  ),
                ),
                ListTile(
                  title: const Text('Columns'),
                  trailing: DropdownButton<int>(
                    value: columns,
                    items: [
                      for (var value = 2; value <= 8; value++)
                        DropdownMenuItem(value: value, child: Text('$value')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => columns = value ?? columns),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_TableSize(rows, columns)),
                child: const Text('Insert'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    final header =
        '| ${List.generate(result.columns, (index) => 'Column ${index + 1}').join(' | ')} |';
    final divider =
        '| ${List.generate(result.columns, (_) => '---').join(' | ')} |';
    final body = List.generate(
      result.rows - 1,
      (_) => '| ${List.generate(result.columns, (_) => '').join(' | ')} |',
    );
    _insertText('\n$header\n$divider\n${body.join('\n')}\n');
  }

  List<String> _parseTags(String value) {
    return value
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({required this.onCommand});

  final ValueChanged<_EditorCommand> onCommand;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _button(Icons.format_bold, 'Bold', _EditorCommand.bold),
            _button(Icons.format_italic, 'Italic', _EditorCommand.italic),
            _button(
              Icons.format_underlined,
              'Underline',
              _EditorCommand.underline,
            ),
            _button(
              Icons.format_strikethrough,
              'Strike',
              _EditorCommand.strike,
            ),
            _button(Icons.highlight, 'Highlight', _EditorCommand.highlight),
            _button(
              Icons.superscript,
              'Superscript',
              _EditorCommand.superscript,
            ),
            _button(Icons.subscript, 'Subscript', _EditorCommand.subscript),
            _button(
              Icons.format_color_text,
              'Text color',
              _EditorCommand.textColor,
            ),
            _button(
              Icons.format_color_fill,
              'Background color',
              _EditorCommand.backgroundColor,
            ),
            _button(Icons.title, 'H1', _EditorCommand.h1),
            _button(Icons.text_fields, 'H2', _EditorCommand.h2),
            _button(Icons.format_quote, 'Quote', _EditorCommand.quote),
            _button(Icons.code, 'Code', _EditorCommand.code),
            _button(
              Icons.check_box_outlined,
              'Checklist',
              _EditorCommand.checklist,
            ),
            _button(
              Icons.format_list_bulleted,
              'Bullets',
              _EditorCommand.bullet,
            ),
            _button(
              Icons.format_list_numbered,
              'Numbering',
              _EditorCommand.numbered,
            ),
            _button(
              Icons.format_align_left,
              'Align left',
              _EditorCommand.alignLeft,
            ),
            _button(
              Icons.format_align_center,
              'Align center',
              _EditorCommand.alignCenter,
            ),
            _button(
              Icons.format_align_right,
              'Align right',
              _EditorCommand.alignRight,
            ),
            _button(
              Icons.format_indent_increase,
              'Indent',
              _EditorCommand.indent,
            ),
            _button(Icons.table_chart_outlined, 'Table', _EditorCommand.table),
            _button(Icons.attach_file, 'Attachment', _EditorCommand.attach),
          ],
        ),
      ),
    );
  }

  Widget _button(IconData icon, String tooltip, _EditorCommand command) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: () => onCommand(command),
    );
  }
}

class _FindReplaceResult {
  const _FindReplaceResult(this.find, this.replace);

  final String find;
  final String replace;
}

class _TableSize {
  const _TableSize(this.rows, this.columns);

  final int rows;
  final int columns;
}

enum _EditorCommand {
  bold,
  italic,
  underline,
  strike,
  highlight,
  superscript,
  subscript,
  textColor,
  backgroundColor,
  h1,
  h2,
  h3,
  quote,
  code,
  checklist,
  bullet,
  numbered,
  alignLeft,
  alignCenter,
  alignRight,
  indent,
  table,
  attach,
}
