import 'package:recase/recase.dart';

import '/metro/live/live_snapshot.dart';

/// This stub is used to create a Seeder from an exported storage snapshot.
String snapshotSeederStub({
  required ReCase seeder,
  required LiveSnapshot snapshot,
  String? description,
  DateTime? now,
}) {
  final DateTime when = (snapshot.exportedAt ?? now ?? DateTime.now())
      .toLocal();
  final String device = snapshot.device ?? 'the app';
  final String text = (description == null || description.trim().isEmpty)
      ? 'Storage from $device, ${_shortDate(when)}'
      : description.trim().replaceAll(RegExp(r'\s+'), ' ');
  final String escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');

  final String context = [
    snapshot.app,
    snapshot.env,
  ].whereType<String>().join(', ');
  final String origin = _comment(
    'Exported from $device${context.isEmpty ? '' : ' ($context)'} on '
    '${_longDate(when)} with export ${seeder.snakeCase} in metro live. Edit the '
    'snapshot below, or export again with --force to replace it.',
  );
  final String storage = dartLiteral(
    snapshot.storage,
    indent: '    ',
    expand: true,
  );
  final String backpack = dartLiteral(
    snapshot.backpack,
    indent: '    ',
    expand: true,
  );

  return '''
import 'package:nylo_framework/nylo_framework.dart';
import 'package:nylo_framework/live.dart';

/// ${seeder.titleCase} Seeder
///
/// $text
///
$origin
///
/// Run it in metro live:  seed ${seeder.snakeCase}
/// Undo it in metro live: seed:rollback ${seeder.snakeCase}
class ${seeder.pascalCase}Seeder extends Seeder {
  @override
  String get description => '$escaped';

  @override
  Future<void> up() async {
    await importSnapshot(snapshot);
    success('${seeder.titleCase} imported on \${Nylo.getCurrentRouteName()}');
  }

  @override
  Future<void> down() async {
    // Put back everything up() changed.
    await restore();
  }

  /// ${snapshot.summary.replaceFirst(',', ' and')}.
  static const Map<String, Object?> snapshot = {
    'storage': $storage,
    'backpack': $backpack,
  };
}
''';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// `15 Sep 20:41`
String _shortDate(DateTime time) =>
    '${time.day} ${_months[time.month - 1]} ${_two(time.hour)}:${_two(time.minute)}';

/// `15 Sep 2026 at 20:41`
String _longDate(DateTime time) =>
    '${time.day} ${_months[time.month - 1]} ${time.year} at '
    '${_two(time.hour)}:${_two(time.minute)}';

/// [text] wrapped into `/// ` comment lines of at most 78 columns.
String _comment(String text) {
  final List<String> lines = [];
  final StringBuffer line = StringBuffer();
  for (final String word in text.split(' ')) {
    if (line.isNotEmpty && line.length + 1 + word.length > 74) {
      lines.add(line.toString());
      line.clear();
    }
    if (line.isNotEmpty) line.write(' ');
    line.write(word);
  }
  if (line.isNotEmpty) lines.add(line.toString());
  return lines.map((String content) => '/// $content').join('\n');
}
