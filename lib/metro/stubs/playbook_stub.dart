import 'package:recase/recase.dart';

/// This stub is used to create a new Playbook.
String playbookStub({required ReCase playbook, String? description}) {
  final String text = (description == null || description.trim().isEmpty)
      ? 'Describe the journey this playbook walks through'
      : description.trim();
  final String escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');

  return '''
import 'package:nylo_framework/nylo_framework.dart';
import 'package:nylo_framework/playbook.dart';

/// ${playbook.titleCase} Playbook
///
/// A user journey your app performs on itself while it's running in debug
/// mode: the taps, typing, scrolling and page changes listed in steps, with
/// a visible finger.
///
/// Play it:                metro live:run playbook ${playbook.snakeCase}
/// Change the pace:        metro live:run playbook ${playbook.snakeCase} --speed fast
/// Inside metro live:      playbook ${playbook.snakeCase}
class ${playbook.pascalCase}Playbook extends Playbook {
  @override
  String get description => '$escaped';

  @override
  PlaybookSpeed get speed => PlaybookSpeed.natural;

  @override
  Map<String, dynamic> get defaults => {
    // 'email': 'demo@nylo.dev',
  };

  @override
  List<PlaybookStep> get steps => [
    // Find things by the text a person reads on screen, for example:
    // tap('Get started'),
    // type('Email', data['email']),
    // tap('Create account'),
    // waitForPage('/dashboard'),
    // see('Welcome'),
    pause(seconds: 1),
  ];
}
''';
}
