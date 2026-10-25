import 'package:recase/recase.dart';

import '/metro/playbook_routes.dart';

/// This stub is used to create a new Playbook.
///
/// With [routes], the playbook visits each page and takes a screenshot of
/// it, as `metro make:playbook <name> --from-routes` makes.
String playbookStub({
  required ReCase playbook,
  String? description,
  List<PlaybookRoute> routes = const [],
}) {
  final String text = (description == null || description.trim().isEmpty)
      ? routes.isEmpty
            ? 'Describe the journey this playbook walks through'
            : 'Visits every page and takes a screenshot'
      : description.trim();
  final String escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');

  final String imports = [
    if (routes.isNotEmpty) '\n',
    for (final PlaybookRoute route in routes) "\nimport '${route.import}';",
  ].join();
  final String steps = routes.isEmpty
      ? '''
    // Find things by the text a person reads on screen, for example:
    // tap('Get started'),
    // type('Email', data['email']),
    // tap('Create account'),
    // waitForPage('/dashboard'),
    // see('Welcome'),
    pause(seconds: 1),'''
      : [
          for (final PlaybookRoute route in routes) _visitAndCapture(route),
        ].join('\n');

  return '''
import 'package:nylo_framework/nylo_framework.dart';
import 'package:nylo_framework/playbook.dart';$imports

/// ${playbook.titleCase} Playbook
///
/// A user journey your app performs on itself while it's running in debug
/// mode: the taps, typing, scrolling and page changes listed in steps.
///
/// Play it:                metro live:run playbook ${playbook.snakeCase}
/// Change the pace:        metro live:run playbook ${playbook.snakeCase} --speed fast
/// Record a video:         metro live:run playbook ${playbook.snakeCase} --record
/// Inside metro live:      playbook ${playbook.snakeCase}
class ${playbook.pascalCase}Playbook extends Playbook {
  @override
  String get description => '$escaped';

  @override
  PlaybookSpeed get speed => PlaybookSpeed.natural;

  // Draw a finger where each step touches the screen.
  @override
  bool get showFinger => false;

  // Show each step as a caption: PlaybookCaption.bottom or .top.
  @override
  PlaybookCaption get caption => PlaybookCaption.hidden;

  @override
  Map<String, dynamic> get defaults => {
    // 'email': 'demo@nylo.dev',
  };

  @override
  List<PlaybookStep> get steps => [
$steps
  ];
}
''';
}

/// The steps that visit [route] and capture it, after a comment when it may
/// need setUp to reach.
String _visitAndCapture(PlaybookRoute route) {
  final List<String> parameters = route.parameters;
  final String example = (route.path ?? '').replaceAllMapped(
    RegExp(r'\{[^}]+\}'),
    (_) => '1',
  );
  return [
    if (route.guarded)
      '    // Behind a route guard, so setUp may need to sign in first.',
    if (parameters.isNotEmpty)
      "    // Takes {${parameters.join('}, {')}}, so setUp may need data for it, "
          "or visit e.g. '$example'.",
    '    visit(${route.page}.path),',
    "    screenshot('${route.name}'),",
  ].join('\n');
}
