import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:everything_notes_offline/shared/models/note.dart';
import 'package:xml/xml.dart';

class DocxService {
  const DocxService._();

  static Future<String> importDocx(File file) async {
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final document = archive.findFile('word/document.xml');
    final bytes = document?.readBytes();
    if (bytes == null) {
      throw const FormatException(
        'DOCX file does not contain word/document.xml',
      );
    }

    final xml = XmlDocument.parse(utf8.decode(bytes));
    final blocks = <String>[];
    for (final node in xml.descendants.whereType<XmlElement>()) {
      if (node.name.local == 'p') {
        final text = node.descendants
            .whereType<XmlElement>()
            .where((element) => element.name.local == 't')
            .map((element) => element.innerText)
            .join();
        if (text.trim().isNotEmpty) {
          blocks.add(text);
        }
      }
      if (node.name.local == 'tr') {
        final cells = node.children
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'tc')
            .map((cell) {
              return cell.descendants
                  .whereType<XmlElement>()
                  .where((element) => element.name.local == 't')
                  .map((element) => element.innerText)
                  .join(' ');
            })
            .where((cell) => cell.trim().isNotEmpty)
            .toList();
        if (cells.isNotEmpty) {
          blocks.add('| ${cells.join(' | ')} |');
        }
      }
    }

    return blocks.join('\n\n');
  }

  static List<int> exportDocx(Note note) {
    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
      ..addFile(ArchiveFile.string('_rels/.rels', _relationships))
      ..addFile(
        ArchiveFile.string('word/_rels/document.xml.rels', _documentRels),
      )
      ..addFile(ArchiveFile.string('word/styles.xml', _styles))
      ..addFile(ArchiveFile.string('docProps/core.xml', _core(note)))
      ..addFile(ArchiveFile.string('docProps/app.xml', _appProps))
      ..addFile(ArchiveFile.string('word/document.xml', _documentXml(note)));
    return ZipEncoder().encode(archive);
  }

  static String _documentXml(Note note) {
    final blocks = <String>[
      _paragraph(note.title, style: 'Title'),
      for (final line in note.content.split('\n')) _paragraph(line),
    ];
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${blocks.join('\n    ')}
    <w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
  </w:body>
</w:document>
''';
  }

  static String _paragraph(String text, {String? style}) {
    final styleXml = style == null
        ? ''
        : '<w:pPr><w:pStyle w:val="${_escapeXml(style)}"/></w:pPr>';
    return '<w:p>$styleXml<w:r><w:t xml:space="preserve">${_escapeXml(text)}</w:t></w:r></w:p>';
  }

  static String _core(Note note) {
    return '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>${_escapeXml(note.title)}</dc:title>
  <dc:creator>Everything Notes Offline</dc:creator>
  <cp:lastModifiedBy>Everything Notes Offline</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">${note.createdAt.toUtc().toIso8601String()}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">${note.updatedAt.toUtc().toIso8601String()}</dcterms:modified>
</cp:coreProperties>
''';
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static const _contentTypes = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
''';

  static const _relationships = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
''';

  static const _documentRels = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
''';

  static const _styles = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:qFormat/></w:style>
</w:styles>
''';

  static const _appProps = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Everything Notes Offline</Application>
</Properties>
''';
}
