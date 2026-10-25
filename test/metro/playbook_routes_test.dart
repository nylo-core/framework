import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/playbook_routes.dart';
import 'package:nylo_framework/metro/stubs/playbook_stub.dart';
import 'package:recase/recase.dart';

/// A router written the ways Nylo apps add their routes.
const String router = '''
import '/resources/pages/home_page.dart';
import '/resources/pages/settings/account_page.dart';
import 'package:shop/resources/pages/profile_page.dart';
import 'package:nylo_framework/nylo_framework.dart';

/* App Router
| router.add(CommentedPage.path);
*/

NyRouter appRouter() => nyRoutes((NyRouter router) {
      router.add(HomePage.path).initialRoute();

      router.add(NotFoundPage.path).unknownRoute();
      // router.add(LaterPage.path);
      router.add(ProfilePage.path);
      router.add(AccountPage.path).authenticatedRoute();
      router.add(AdminPage.path, routeGuards: [
        AdminRouteGuard(),
      ]);
      router.add(ReportsPage.path)
          .addRouteGuard(StaffGuard());

      router.group(() => {
        "route_guards": [AuthRouteGuard()],
        "prefix": "/dashboard",
      }, (router) {
        router.add(ChatPage.path);
      });

      router.add(HomePage.path);
      router.add(OneOfDemoPage.path);
});
''';

void main() {
  group('playbookRoutesIn', () {
    test('lists the pages the router adds, once each and in order', () {
      final List<PlaybookRoute> routes = playbookRoutesIn(router);

      expect(routes.map((route) => route.page), [
        'HomePage',
        'ProfilePage',
        'AccountPage',
        'AdminPage',
        'ReportsPage',
        'ChatPage',
        'OneOfDemoPage',
      ]);
      expect(routes.map((route) => route.name), [
        'home',
        'profile',
        'account',
        'admin',
        'reports',
        'chat',
        'one_of_demo',
      ]);
    });

    test('imports each page the way the router does', () {
      final Map<String, String> imports = {
        for (final PlaybookRoute route in playbookRoutesIn(router))
          route.page: route.import,
      };

      expect(imports['HomePage'], '/resources/pages/home_page.dart');
      expect(
        imports['AccountPage'],
        '/resources/pages/settings/account_page.dart',
      );
      expect(
        imports['ProfilePage'],
        'package:shop/resources/pages/profile_page.dart',
      );
      expect(imports['ChatPage'], '/resources/pages/chat_page.dart');
    });

    test('notes the pages behind a route guard', () {
      expect(
        [
          for (final PlaybookRoute route in playbookRoutesIn(router))
            if (route.guarded) route.page,
        ],
        ['AccountPage', 'AdminPage', 'ReportsPage', 'ChatPage'],
      );
    });

    test('reads a page\'s route path from its file', () {
      final PlaybookRoute profile = playbookRoutesIn(
        router,
        readPage: (String import) => import.endsWith('profile_page.dart')
            ? 'static RouteView path = ("/profile/{userId}", '
                  '(_) => ProfilePage());'
            : null,
      ).firstWhere((route) => route.page == 'ProfilePage');

      expect(profile.path, '/profile/{userId}');
      expect(profile.parameters, ['userId']);
    });

    test('finds nothing in a router without router.add lines', () {
      expect(
        playbookRoutesIn('NyRouter appRouter() => nyRoutes((r) {});'),
        isEmpty,
      );
    });
  });

  group('readPlaybookRoutes', () {
    late Directory project;
    setUp(() => project = Directory.systemTemp.createTempSync('nylo_routes'));
    tearDown(() => project.deleteSync(recursive: true));

    void write(String path, String contents) => File('${project.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);

    test('reads the router and the page files it imports', () {
      write('lib/routes/router.dart', router);
      write(
        'lib/resources/pages/profile_page.dart',
        'class ProfilePage {\n'
            '  // static RouteView path = ("/old", (_) => ProfilePage());\n'
            '  static RouteView path = ("/profile/{userId}", (_) => '
            'ProfilePage());\n'
            '}\n',
      );
      write(
        'lib/resources/pages/home_page.dart',
        'static RouteView path = ("/home", (_) => HomePage());',
      );

      final List<PlaybookRoute> routes = readPlaybookRoutes(
        projectRoot: project.path,
      );

      expect(routes.first.path, '/home');
      expect(routes[1].path, '/profile/{userId}');
      expect(routes[2].path, isNull);
    });

    test('is empty without a router', () {
      expect(readPlaybookRoutes(projectRoot: project.path), isEmpty);
    });
  });

  group('playbookStub with routes', () {
    final String stub = playbookStub(
      playbook: ReCase('tour'),
      routes: const [
        PlaybookRoute(
          page: 'HomePage',
          import: '/resources/pages/home_page.dart',
        ),
        PlaybookRoute(
          page: 'DashboardPage',
          import: '/resources/pages/dashboard_page.dart',
          guarded: true,
        ),
        PlaybookRoute(
          page: 'ProfilePage',
          import: '/resources/pages/profile_page.dart',
          path: '/profile/{userId}',
        ),
      ],
    );

    test('imports the pages it visits', () {
      expect(
        stub,
        contains(
          "import 'package:nylo_framework/playbook.dart';\n"
          '\n'
          "import '/resources/pages/home_page.dart';\n"
          "import '/resources/pages/dashboard_page.dart';\n"
          "import '/resources/pages/profile_page.dart';\n",
        ),
      );
    });

    test('visits each page and takes a screenshot of it', () {
      expect(
        stub,
        contains(
          '  List<PlaybookStep> get steps => [\n'
          '    visit(HomePage.path),\n'
          "    screenshot('home'),\n"
          '    // Behind a route guard, so setUp may need to sign in first.\n'
          '    visit(DashboardPage.path),\n'
          "    screenshot('dashboard'),\n"
          '    // Takes {userId}, so setUp may need data for it, or visit e.g. '
          "'/profile/1'.\n"
          '    visit(ProfilePage.path),\n'
          "    screenshot('profile'),\n"
          '  ];\n',
        ),
      );
      expect(stub, isNot(contains('pause(seconds: 1)')));
    });

    test('describes itself as a tour', () {
      expect(
        stub,
        contains(
          "String get description => 'Visits every page and takes a "
          "screenshot';",
        ),
      );
      expect(
        playbookStub(
          playbook: ReCase('tour'),
          description: 'Store tour',
          routes: const [
            PlaybookRoute(page: 'HomePage', import: '/home_page.dart'),
          ],
        ),
        contains("String get description => 'Store tour';"),
      );
    });
  });
}
