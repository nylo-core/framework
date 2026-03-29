import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/ny_cli.dart';
import 'package:nylo_framework/metro/stubs/widget_stateless_stub.dart';
import 'package:nylo_framework/metro/stubs/widget_stateful_stub.dart';
import 'package:nylo_framework/metro/stubs/widget_state_managed_stub.dart';
import 'package:nylo_framework/metro/stubs/controller_stub.dart';
import 'package:nylo_framework/metro/stubs/event_stub.dart';
import 'package:nylo_framework/metro/stubs/provider_stub.dart';
import 'package:nylo_framework/metro/stubs/interceptor_stub.dart';
import 'package:nylo_framework/metro/stubs/route_guard_stub.dart';
import 'package:nylo_framework/metro/stubs/config_stub.dart';
import 'package:nylo_framework/metro/stubs/form_stub.dart';
import 'package:nylo_framework/metro/stubs/custom_command_stub.dart';
import 'package:recase/recase.dart';

/// Tests that each make:* command correctly extracts subdirectory paths
/// from the input name and generates stubs with the correct class name.
///
/// This mirrors the logic in each command's handle() method:
/// 1. Parse input with MetroService.createMetroProjectFile()
/// 2. Clean the name (strip suffix)
/// 3. Generate stub with clean name
/// 4. Pass creationPath to MetroService method
void main() {
  group('make:stateless_widget subdirectory support', () {
    test('parses subdirectory from widget name', () {
      final projectFile = MetroService.createMetroProjectFile(
          'login/BrandPanel',
          prefix: RegExp(r'(_?widget)'));

      expect(projectFile.creationPath, 'login');
      expect(projectFile.name, 'BrandPanel');
    });

    test('generates correct stub with subdirectory path', () {
      final projectFile = MetroService.createMetroProjectFile(
          'login/BrandPanel',
          prefix: RegExp(r'(_?widget)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = widgetStatelessStub(classReCase);
      expect(stub, contains('class BrandPanel extends StatelessWidget'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'login/BrandPanel',
          prefix: RegExp(r'(_?widget)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: widgetsFolder,
        className: cleanName,
        prefix: 'widget',
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/resources/widgets/login/brand_panel_widget.dart');
    });

    test('works without subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile('BrandPanel',
          prefix: RegExp(r'(_?widget)'));

      expect(projectFile.creationPath, isNull);
      expect(projectFile.name, 'BrandPanel');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: widgetsFolder,
        className: cleanName,
        prefix: 'widget',
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/resources/widgets/brand_panel_widget.dart');
    });

    test('handles deep subdirectory path', () {
      final projectFile = MetroService.createMetroProjectFile(
          'auth/social/GoogleSignIn',
          prefix: RegExp(r'(_?widget)'));

      expect(projectFile.creationPath, 'auth/social');
      expect(projectFile.name, 'GoogleSignIn');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: widgetsFolder,
        className: cleanName,
        prefix: 'widget',
        creationPath: projectFile.creationPath,
      );

      expect(filePath,
          'lib/resources/widgets/auth/social/google_sign_in_widget.dart');
    });
  });

  group('make:stateful_widget subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile(
          'dashboard/StatsChart',
          prefix: RegExp(r'(_?widget)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");
      ReCase classReCase = ReCase(cleanName);

      expect(projectFile.creationPath, 'dashboard');

      String stub = widgetStatefulStub(classReCase);
      expect(stub, contains('class StatsChart extends StatefulWidget'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'dashboard/StatsChart',
          prefix: RegExp(r'(_?widget)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: widgetsFolder,
        className: cleanName,
        prefix: 'widget',
        creationPath: projectFile.creationPath,
      );

      expect(
          filePath, 'lib/resources/widgets/dashboard/stats_chart_widget.dart');
    });
  });

  group('make:state_managed_widget subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile('cart/CartIcon',
          prefix: RegExp(r'(_?widget)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");
      ReCase classReCase = ReCase(cleanName);

      expect(projectFile.creationPath, 'cart');

      String stub = widgetStateManagedStub(classReCase);
      expect(stub, contains('class CartIcon extends StatefulWidget'));
    });
  });

  group('make:controller subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      // The command strips "Controller" suffix before calling createMetroProjectFile
      final projectFile = MetroService.createMetroProjectFile('admin/User',
          prefix: RegExp(r'(_?controller)'));

      expect(projectFile.creationPath, 'admin');

      String cleanName =
          projectFile.name.replaceAll(RegExp(r'(_?controller)'), "");
      String stub = controllerStub(controllerName: cleanName);

      expect(stub, contains('class UserController extends Controller'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile('admin/User',
          prefix: RegExp(r'(_?controller)'));

      String filePath = MetroService.createPathForDartFile(
        folderPath: controllersFolder,
        className: projectFile.name,
        prefix: 'controller',
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/app/controllers/admin/user_controller.dart');
    });
  });

  group('make:event subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile('auth/LoginEvent',
          prefix: RegExp(r'(_?event)'));

      expect(projectFile.creationPath, 'auth');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?event)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = eventStub(eventName: classReCase);
      expect(stub, contains('class LoginEvent implements NyEvent'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile('auth/LoginEvent',
          prefix: RegExp(r'(_?event)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?event)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: eventsFolder,
        className: cleanName,
        prefix: 'event',
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/app/events/auth/login_event.dart');
    });

    test('generates correct import path with subdirectory', () {
      expect(
        makeImportPathEvent('login', creationPath: 'auth'),
        "import '/app/events/auth/login_event.dart';",
      );
    });
  });

  group('make:provider subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile(
          'services/StorageProvider',
          prefix: RegExp(r'(_?provider)'));

      expect(projectFile.creationPath, 'services');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?provider)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = providerStub(classReCase);
      expect(stub, contains('class StorageProvider implements NyProvider'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'services/StorageProvider',
          prefix: RegExp(r'(_?provider)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?provider)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: providerFolder,
        className: cleanName,
        prefix: 'provider',
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/app/providers/services/storage_provider.dart');
    });

    test('generates correct import path with subdirectory', () {
      expect(
        makeImportPathProviders('storage', creationPath: 'services'),
        "import '/app/providers/services/storage_provider.dart';",
      );
    });
  });

  group('make:interceptor subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile(
          'api/AuthTokenInterceptor',
          prefix: RegExp(r'(_?interceptor)'));

      expect(projectFile.creationPath, 'api');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?interceptor)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = interceptorStub(interceptorName: classReCase);
      expect(stub, contains('class AuthTokenInterceptor extends Interceptor'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'api/AuthTokenInterceptor',
          prefix: RegExp(r'(_?interceptor)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?interceptor)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: networkingInterceptorsFolder,
        className: cleanName,
        prefix: 'interceptor',
        creationPath: projectFile.creationPath,
      );

      expect(filePath,
          'lib/app/networking/dio/interceptors/api/auth_token_interceptor.dart');
    });
  });

  group('make:config subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile(
          'settings/CurrenciesConfig',
          prefix: RegExp(r'(_?config)'));

      expect(projectFile.creationPath, 'settings');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?config)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = configStub(classReCase);
      expect(stub, contains('class CurrenciesConfig'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'settings/CurrenciesConfig',
          prefix: RegExp(r'(_?config)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?config)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: configFolder,
        className: cleanName,
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/config/settings/currencies.dart');
    });
  });

  group('make:command subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile(
          'db/MigrateCommand',
          prefix: RegExp(r'(_?command)'));

      expect(projectFile.creationPath, 'db');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?command)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = customCommandStub(customCommand: classReCase);
      expect(stub, contains('class _MigrateCommand extends NyCustomCommand'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'db/MigrateCommand',
          prefix: RegExp(r'(_?command)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?command)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: commandsFolder,
        className: cleanName,
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/app/commands/db/migrate.dart');
    });
  });

  group('make:form subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile(
          'auth/RegisterForm',
          prefix: RegExp(r'(_?form)'));

      expect(projectFile.creationPath, 'auth');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?form)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = formStub(classReCase);
      expect(stub, contains('class RegisterForm extends NyFormWidget'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'auth/RegisterForm',
          prefix: RegExp(r'(_?form)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?form)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: formsFolder,
        className: cleanName,
        prefix: 'form',
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/app/forms/auth/register_form.dart');
    });
  });

  group('make:route_guard subdirectory support', () {
    test('parses subdirectory and generates correct stub', () {
      final projectFile = MetroService.createMetroProjectFile(
          'admin/SubscriptionRouteGuard',
          prefix: RegExp(r'(_?route_guard)'));

      expect(projectFile.creationPath, 'admin');

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?route_guard)'), "");
      ReCase classReCase = ReCase(cleanName);

      String stub = routeGuardStub(classReCase);
      expect(
          stub, contains('class SubscriptionRouteGuard extends NyRouteGuard'));
    });

    test('generates correct file path with subdirectory', () {
      final projectFile = MetroService.createMetroProjectFile(
          'admin/SubscriptionRouteGuard',
          prefix: RegExp(r'(_?route_guard)'));

      String cleanName =
          projectFile.name.snakeCase.replaceAll(RegExp(r'(_?route_guard)'), "");

      String filePath = MetroService.createPathForDartFile(
        folderPath: routeGuardsFolder,
        className: cleanName,
        prefix: 'route_guard',
        creationPath: projectFile.creationPath,
      );

      expect(filePath, 'lib/routes/guards/admin/subscription_route_guard.dart');
    });
  });

  group('comma-separated names with subdirectories', () {
    test('stateless_widget handles comma-separated with subdirectory', () {
      // Simulates: make:stateless_widget login/BrandPanel,login/LogoPanel
      final inputs = 'login/BrandPanel,login/LogoPanel'.split(',');

      for (final input in inputs) {
        final projectFile = MetroService.createMetroProjectFile(input.trim(),
            prefix: RegExp(r'(_?widget)'));

        expect(projectFile.creationPath, 'login');

        String cleanName =
            projectFile.name.snakeCase.replaceAll(RegExp(r'(_?widget)'), "");
        ReCase classReCase = ReCase(cleanName);

        String stub = widgetStatelessStub(classReCase);
        expect(stub, contains('extends StatelessWidget'));
      }
    });
  });
}
