import 'package:recase/recase.dart';

/// This stub is used to create a new Seeder.
String seederStub({required ReCase seeder, String? description}) {
  final String text = (description == null || description.trim().isEmpty)
      ? 'Describe the state this seeder creates'
      : description.trim();
  final String escaped = text
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');

  return '''
import 'package:nylo_framework/nylo_framework.dart';
import 'package:nylo_framework/live.dart';

/// ${seeder.titleCase} Seeder
///
/// Runs inside your app while it's running in debug mode. Every storage and
/// Backpack value up() changes is recorded, so down() can put it back.
///
/// Run it in metro live:  seed ${seeder.snakeCase}
/// Undo it in metro live: seed:rollback ${seeder.snakeCase}
class ${seeder.pascalCase}Seeder extends Seeder {
  @override
  String get description => '$escaped';

  @override
  Future<void> up() async {
    // Save what the app should start with, for example:
    // await Auth.authenticate(data: {'name': 'Jane Doe'});
    // await saveToStorage({'onboarding_complete': true});

    success('${seeder.titleCase} seeded on \${Nylo.getCurrentRouteName()}');
  }

  @override
  Future<void> down() async {
    // Put back everything up() changed.
    await restore();
  }
}
''';
}
