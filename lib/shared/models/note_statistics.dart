class NoteStatistics {
  const NoteStatistics({
    required this.totalNotes,
    required this.pinnedNotes,
    required this.favoriteNotes,
    required this.folderCount,
    required this.trashedNotes,
    required this.storageBytes,
  });

  final int totalNotes;
  final int pinnedNotes;
  final int favoriteNotes;
  final int folderCount;
  final int trashedNotes;
  final int storageBytes;

  String get storageLabel {
    if (storageBytes >= 1024 * 1024) {
      return '${(storageBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (storageBytes >= 1024) {
      return '${(storageBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$storageBytes B';
  }
}
