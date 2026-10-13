import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/stubs/playbook_stub.dart';
import 'package:recase/recase.dart';

void main() {
  group('playbookStub', () {
    test('creates a public playbook class with steps', () {
      final String stub = playbookStub(
        playbook: ReCase('sign_up_to_dashboard'),
      );

      expect(
        stub,
        contains('class SignUpToDashboardPlaybook extends Playbook'),
      );
      expect(
        stub,
        contains('PlaybookSpeed get speed => PlaybookSpeed.natural;'),
      );
      expect(stub, contains('Map<String, dynamic> get defaults => {'));
      expect(stub, contains('List<PlaybookStep> get steps => ['));
      expect(stub, contains('pause(seconds: 1),'));
      expect(stub, isNot(contains('class _')));
    });

    test('imports the framework and the playbook library', () {
      final String stub = playbookStub(playbook: ReCase('log_out'));

      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart';"),
      );
      expect(stub, contains("import 'package:nylo_framework/playbook.dart';"));
    });

    test('documents how to play it', () {
      final String stub = playbookStub(playbook: ReCase('log_out'));

      expect(stub, contains('/// Log Out Playbook'));
      expect(stub, contains('metro live:run playbook log_out\n'));
      expect(stub, contains('metro live:run playbook log_out --speed fast\n'));
      expect(stub, contains('/// Inside metro live:      playbook log_out\n'));
    });

    test('uses the description, escaped for a Dart string', () {
      expect(
        playbookStub(playbook: ReCase('log_out')),
        contains(
          "description => 'Describe the journey this playbook walks through';",
        ),
      );
      expect(
        playbookStub(
          playbook: ReCase('log_out'),
          description: r"Jane's checkout, $5 off",
        ),
        contains(r"description => 'Jane\'s checkout, \$5 off';"),
      );
    });
  });
}
