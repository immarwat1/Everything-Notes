class NoteTemplate {
  const NoteTemplate({required this.name, required this.content});

  final String name;
  final String content;
}

const builtInTemplates = [
  NoteTemplate(name: 'Blank', content: ''),
  NoteTemplate(
    name: 'Meeting Notes',
    content:
        '# Meeting Notes\n\nDate:\nAttendees:\n\n## Agenda\n- \n\n## Decisions\n- \n\n## Action Items\n- [ ] ',
  ),
  NoteTemplate(
    name: 'Diary',
    content: '# Diary\n\nToday I felt...\n\nHighlights:\n- \n\nGratitude:\n- ',
  ),
  NoteTemplate(
    name: 'Research Paper',
    content:
        '# Title\n\n## Abstract\n\n## Introduction\n\n## Methods\n\n## Findings\n\n## References\n',
  ),
  NoteTemplate(
    name: 'Lecture Notes',
    content:
        '# Lecture Notes\n\nCourse:\nTopic:\n\n## Key Ideas\n- \n\n## Questions\n- ',
  ),
  NoteTemplate(name: 'Shopping List', content: '# Shopping List\n\n- [ ] '),
  NoteTemplate(
    name: 'Expense Sheet',
    content:
        '# Expense Sheet\n\n| Date | Item | Amount |\n| --- | --- | --- |\n| | | |\n',
  ),
  NoteTemplate(name: 'To Do', content: '# To Do\n\n- [ ] '),
  NoteTemplate(
    name: 'Journal',
    content: '# Journal\n\n## Morning\n\n## Evening\n',
  ),
];
