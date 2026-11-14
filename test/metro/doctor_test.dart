import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/doctor.dart';

/// A page the way `metro make:page` writes it.
String page(String name, {String? controller}) =>
    '''
import 'package:nylo_framework/nylo_framework.dart';

class ${name}Page extends NyStatefulWidget${controller == null ? '' : '<$controller>'} {
  static RouteView path = ("/${name.toLowerCase()}", (_) => ${name}Page());

  ${name}Page({super.key}) : super(child: () => _${name}PageState());
}

class _${name}PageState extends NyPage<${name}Page> {}
''';

/// A router that adds [pages], the way `metro make:page` does.
String router(List<String> pages) =>
    '''
import 'package:nylo_framework/nylo_framework.dart';

NyRouter appRouter() => nyRoutes((NyRouter router) {
${pages.map((String page) => '  router.add(${page}Page.path);').join('\n')}
  // router.add(CommentedPage.path);
});
''';

const String decoders = '''
import '/app/models/user.dart';
import '/app/networking/api_service.dart';
import 'package:nylo_framework/nylo_framework.dart';

final Map<Type, dynamic> modelDecoders = decoders([
  Decode(User.fromJson),
  // Decode(Order.fromJson),
]);

final Map<Type, dynamic> apiDecoders = {
  ApiService: () => ApiService(),
};

final Map<Type, dynamic> controllers = {
  HomeController: () => HomeController(),
};
''';

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('nylo_doctor'));
  tearDown(() => project.deleteSync(recursive: true));

  void write(String path, String contents) => File('${project.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  DoctorCheck check(String label) =>
      runDoctor(projectRoot: project.path)
          .firstWhere((DoctorCheck check) => check.label == label);

  group('metro doctor', () {
    test('skips every check in an empty project and exits 0', () {
      final List<DoctorCheck> checks = runDoctor(projectRoot: project.path);

      expect(checks.map((DoctorCheck check) => check.label), [
        'Routes',
        'Decoders',
        'Languages',
        'Env',
        'Assets',
      ]);
      expect(
        checks.map((DoctorCheck check) => check.status),
        everyElement(DoctorStatus.skipped),
      );
      expect(doctorExitCode(checks), 0);
    });

    group('Routes', () {
      test('names the page the router leaves out', () {
        write('lib/resources/pages/home_page.dart', page('Home'));
        write('lib/resources/pages/invoice_page.dart', page('Invoice'));
        write('lib/routes/router.dart', router(['Home']));

        final DoctorCheck routes = check('Routes');

        expect(routes.status, DoctorStatus.problem);
        expect(
          routes.summary,
          '1 page has no route: lib/resources/pages/invoice_page.dart',
        );
        expect(routes.fixes, [
          'add router.add(InvoicePage.path); to lib/routes/router.dart',
        ]);
      });

      test('reads a commented-out route as no route', () {
        write('lib/resources/pages/home_page.dart', page('Home'));
        write('lib/resources/pages/commented_page.dart', page('Commented'));
        write('lib/routes/router.dart', router(['Home']));

        expect(check('Routes').status, DoctorStatus.problem);
      });

      test('passes when every page with a path is routed', () {
        write('lib/resources/pages/home_page.dart', page('Home'));
        write(
          'lib/resources/pages/settings/account_page.dart',
          page('Account'),
        );
        write(
          'lib/resources/pages/tab_widget.dart',
          'class TabWidget extends StatelessWidget {}',
        );
        write('lib/routes/router.dart', router(['Home', 'Account']));

        final DoctorCheck routes = check('Routes');

        expect(routes.status, DoctorStatus.ok);
        expect(routes.summary, 'All 2 pages have a route');
      });
    });

    group('Decoders', () {
      setUp(() => write('lib/bootstrap/decoders.dart', decoders));

      test('names an API service used but not in apiDecoders', () {
        write(
          'lib/app/networking/order_api_service.dart',
          'class OrderApiService extends NyApiService {}',
        );
        write(
          'lib/resources/pages/order_page.dart',
          'void load() => api<OrderApiService>((request) => request.fetch());',
        );

        final DoctorCheck result = check('Decoders');

        expect(result.status, DoctorStatus.problem);
        expect(
          result.summary,
          'OrderApiService is used but not in apiDecoders',
        );
        expect(result.details, ['used in lib/resources/pages/order_page.dart']);
        expect(result.fixes, [
          'add OrderApiService: () => OrderApiService(), to apiDecoders in '
              'lib/bootstrap/decoders.dart',
        ]);
      });

      test('names controllers and models that are not registered', () {
        write(
          'lib/app/controllers/profile_controller.dart',
          'class ProfileController extends NyController {}',
        );
        write(
          'lib/resources/pages/profile_page.dart',
          page('Profile', controller: 'ProfileController'),
        );
        write('lib/app/models/order.dart', 'class Order extends Model {}');
        write('lib/app/models/user.dart', 'class User extends Model {}');
        write('lib/app/networking/api_service.dart', '''
class ApiService extends NyApiService {
  Future<List<Order>?> orders() async => await network<List<Order>>();
  Future<User?> user() async => await network<User>();
  Future<Map?> raw() async => await network<Map>();
}
''');

        final DoctorCheck result = check('Decoders');

        expect(result.summary, '2 classes are used but not registered');
        expect(result.fixes, [
          'add Decode(Order.fromJson), to modelDecoders in '
              'lib/bootstrap/decoders.dart',
          'add ProfileController: () => ProfileController(), to controllers '
              'in lib/bootstrap/decoders.dart',
        ]);
      });

      test('suggests the map form for a map of model decoders', () {
        write(
          'lib/bootstrap/decoders.dart',
          'final Map<Type, dynamic> modelDecoders = {};',
        );
        write('lib/app/models/order.dart', 'class Order extends Model {}');
        write(
          'lib/app/networking/api_service.dart',
          'Future<Order?> order() async => await network<Order>();',
        );

        expect(check('Decoders').fixes, [
          'add Order: (data) => Order.fromJson(data), to modelDecoders in '
              'lib/bootstrap/decoders.dart',
        ]);
      });

      test('leaves out type parameters and package classes', () {
        write(
          'lib/app/helpers.dart',
          'Future<T?> call<T>() => api<T>((r) => r); '
              'void a() => api<PackageApiService>((r) => r);',
        );

        expect(check('Decoders').status, DoctorStatus.ok);
      });
    });

    group('Languages', () {
      test('counts the keys a language file is missing', () {
        write('lang/en.json', '{"title": "Hi", "nav": {"home": "Home"}}');
        write('lang/de.json', '{"title": "Hallo", "nav": {}}');

        final DoctorCheck result = check('Languages');

        expect(result.status, DoctorStatus.problem);
        expect(result.summary, 'de.json is missing 1 key that en.json has');
        expect(result.details, ['nav.home']);
      });

      test('compares with the DEFAULT_LOCALE file', () {
        write('.env', 'DEFAULT_LOCALE="de"');
        write('lang/en.json', '{"title": "Hi"}');
        write('lang/de.json', '{"title": "Hallo", "extra": "Mehr"}');

        expect(
          check('Languages').summary,
          'en.json is missing 1 key that de.json has',
        );
      });

      test('lists each file when several need a look', () {
        write('lang/en.json', '{"a": "", "b": ""}');
        write('lang/de.json', '{"a": ""}');
        write('lang/fr.json', '{not json');

        final DoctorCheck result = check('Languages');

        expect(result.summary, '2 language files need a look');
        expect(result.details, [
          'lang/fr.json isn\'t a valid JSON object',
          'lang/de.json is missing 1 key:',
          '  b',
        ]);
      });

      test('passes when every file has every key', () {
        write('lang/en.json', '{"a": ""}');
        write('lang/es.json', '{"a": ""}');

        expect(check('Languages').summary, 'es.json has every key en.json has');
      });
    });

    group('Env', () {
      test('names a key in .env but not in .env-example', () {
        write('.env', 'APP_KEY=secret\nAPP_NAME="Shop"\nSTRIPE_KEY=sk_live');
        write('.env-example', '# The app\nAPP_NAME=""\n');

        final DoctorCheck result = check('Env');

        expect(result.status, DoctorStatus.problem);
        expect(result.summary, 'STRIPE_KEY is in .env but not in .env-example');
        expect(result.fixes, ['add STRIPE_KEY= to .env-example']);
      });

      test('passes when .env-example has every key', () {
        write('.env', 'APP_NAME="Shop"');
        write('.env-example', 'APP_NAME=""');

        expect(check('Env').status, DoctorStatus.ok);
      });
    });

    group('Assets', () {
      test('notes images nothing refers to', () {
        write('assets/images/logo.png', '');
        write('assets/images/2.0x/logo.png', '');
        write('assets/images/old_logo.png', '');
        write('assets/images/.DS_Store', '');
        write(
          'lib/resources/widgets/logo.dart',
          'final logo = LocalAsset.image("logo.png");',
        );

        final DoctorCheck result = check('Assets');

        expect(result.status, DoctorStatus.note);
        expect(
          result.summary,
          '1 image in assets/images is never referenced: '
          'assets/images/old_logo.png',
        );
      });

      test('counts references in pubspec.yaml', () {
        write('assets/images/splash.png', '');
        write(
          'pubspec.yaml',
          'flutter_native_splash:\n  image: assets/images/splash.png',
        );

        expect(check('Assets').status, DoctorStatus.ok);
      });
    });

    group('exit code', () {
      test('is 1 for a problem, and for a note only when strict', () {
        const DoctorCheck problem = DoctorCheck(
          'Env',
          DoctorStatus.problem,
          '',
        );
        const DoctorCheck note = DoctorCheck('Assets', DoctorStatus.note, '');

        expect(doctorExitCode([problem]), 1);
        expect(doctorExitCode([note]), 0);
        expect(doctorExitCode([note], strict: true), 1);
      });
    });

    group('formatDoctorReport', () {
      test('lines up each check, its details and the fixes', () {
        const List<DoctorCheck> checks = [
          DoctorCheck('Routes', DoctorStatus.ok, 'All 2 pages have a route'),
          DoctorCheck(
            'Env',
            DoctorStatus.problem,
            '2 keys are in .env but not in .env-example',
            details: ['A', 'B'],
            fixes: ['add A= to .env-example', 'add B= to .env-example'],
          ),
        ];

        expect(
          formatDoctorReport(checks, ansi: false),
          'Routes      All 2 pages have a route\n'
          'Env         2 keys are in .env but not in .env-example\n'
          '            A\n'
          '            B\n'
          'Fix: add A= to .env-example\n'
          'Fix: add B= to .env-example\n',
        );
      });

      test('ends with a green light when nothing is wired wrong', () {
        expect(
          formatDoctorReport(const [
            DoctorCheck('Assets', DoctorStatus.note, '1 image is unused'),
          ], ansi: false),
          endsWith('Everything is wired up.\n'),
        );
      });
    });
  });
}
