import 'package:flutter_test/flutter_test.dart';
import 'package:recase/recase.dart';
import 'package:nylo_framework/metro/stubs/event_stub.dart';
import 'package:nylo_framework/metro/stubs/provider_stub.dart';
import 'package:nylo_framework/metro/stubs/interceptor_stub.dart';
import 'package:nylo_framework/metro/stubs/route_guard_stub.dart';
import 'package:nylo_framework/metro/stubs/config_stub.dart';
import 'package:nylo_framework/metro/stubs/env_stub.dart';
import 'package:nylo_framework/metro/stubs/form_stub.dart';
import 'package:nylo_framework/metro/stubs/bottom_sheet_modal_stub.dart';
import 'package:nylo_framework/metro/stubs/button_stub.dart';
import 'package:nylo_framework/metro/stubs/custom_command_stub.dart';

void main() {
  group('eventStub', () {
    test('contains correct class name in PascalCase', () {
      final stub = eventStub(eventName: ReCase('user_login'));

      expect(stub, contains('class UserLoginEvent implements NyEvent'));
    });

    test('contains listeners map', () {
      final stub = eventStub(eventName: ReCase('order_placed'));

      expect(stub, contains('final listeners = {'));
      expect(stub, contains('DefaultListener: DefaultListener()'));
    });

    test('contains DefaultListener class', () {
      final stub = eventStub(eventName: ReCase('notification'));

      expect(stub, contains('class DefaultListener extends NyListener'));
    });

    test('contains handle method', () {
      final stub = eventStub(eventName: ReCase('test'));

      expect(stub, contains('handle(dynamic data) async'));
    });

    test('imports nylo_framework', () {
      final stub = eventStub(eventName: ReCase('app'));

      expect(stub,
          contains("import 'package:nylo_framework/nylo_framework.dart'"));
    });
  });

  group('providerStub', () {
    test('contains correct class name with Provider suffix', () {
      final stub = providerStub(ReCase('app_config'));

      expect(stub, contains('class AppConfigProvider implements NyProvider'));
    });

    test('contains boot method', () {
      final stub = providerStub(ReCase('auth'));

      expect(stub, contains('boot(Nylo nylo) async'));
    });

    test('contains setup method that returns nylo', () {
      final stub = providerStub(ReCase('database'));

      expect(stub, contains('setup(Nylo nylo) async => nylo'));
    });

    test('imports nylo_framework', () {
      final stub = providerStub(ReCase('service'));

      expect(stub,
          contains("import 'package:nylo_framework/nylo_framework.dart'"));
    });
  });

  group('interceptorStub', () {
    test('contains correct class name with Interceptor suffix', () {
      final stub = interceptorStub(interceptorName: ReCase('auth_header'));

      expect(stub, contains('class AuthHeaderInterceptor extends Interceptor'));
    });

    test('contains onRequest override', () {
      final stub = interceptorStub(interceptorName: ReCase('logging'));

      expect(stub, contains('void onRequest(RequestOptions options'));
      expect(stub, contains('RequestInterceptorHandler handler'));
    });

    test('contains onResponse override', () {
      final stub = interceptorStub(interceptorName: ReCase('cache'));

      expect(stub, contains('void onResponse(Response response'));
      expect(stub, contains('ResponseInterceptorHandler handler'));
    });

    test('contains onError override', () {
      final stub = interceptorStub(interceptorName: ReCase('error_handler'));

      expect(stub, contains('void onError(DioException err'));
      expect(stub, contains('ErrorInterceptorHandler handler'));
    });

    test('imports nylo_framework', () {
      final stub = interceptorStub(interceptorName: ReCase('test'));

      expect(stub,
          contains("import 'package:nylo_framework/nylo_framework.dart'"));
    });
  });

  group('routeGuardStub', () {
    test('contains correct class name with RouteGuard suffix', () {
      final stub = routeGuardStub(ReCase('auth'));

      expect(stub, contains('class AuthRouteGuard extends NyRouteGuard'));
    });

    test('contains constructor', () {
      final stub = routeGuardStub(ReCase('admin'));

      expect(stub, contains('AdminRouteGuard()'));
    });

    test('contains onBefore method', () {
      final stub = routeGuardStub(ReCase('guest'));

      expect(
          stub, contains('Future<GuardResult> onBefore(RouteContext context)'));
    });

    test('contains next() return', () {
      final stub = routeGuardStub(ReCase('authenticated'));

      expect(stub, contains('return next()'));
    });

    test('contains usage comments', () {
      final stub = routeGuardStub(ReCase('subscriber'));

      expect(stub, contains('context.data'));
      expect(stub, contains('context.queryParameters'));
      expect(stub, contains('context.routeName'));
    });

    test('imports nylo_framework', () {
      final stub = routeGuardStub(ReCase('test'));

      expect(stub,
          contains("import 'package:nylo_framework/nylo_framework.dart'"));
    });
  });

  group('configStub', () {
    test('contains correct class name', () {
      final stub = configStub(ReCase('app_settings'));

      expect(stub, contains('class AppSettingsConfig'));
    });

    test('contains final class modifier', () {
      final stub = configStub(ReCase('database'));

      expect(stub, contains('final class DatabaseConfig'));
    });

    test('contains static example setting', () {
      final stub = configStub(ReCase('cache'));

      expect(stub, contains('static final String exampleValue'));
    });
  });

  group('envStub', () {
    test('generates environment template content with encrypted map', () {
      final stub = envStub(
        encryptedMap: {'APP_NAME': 'encrypted_value'},
        appKey: 'test_key',
      );

      expect(stub, isNotEmpty);
      expect(stub, contains('class Env'));
    });

    test('contains decrypt method', () {
      final stub = envStub(
        encryptedMap: {'KEY': 'value'},
        appKey: 'key',
      );

      expect(stub, contains('_decrypt'));
    });

    test('contains get method', () {
      final stub = envStub(
        encryptedMap: {'TEST': 'test'},
        appKey: 'mykey',
      );

      expect(stub, contains('static dynamic get(String key'));
    });

    test('uses dart define when specified', () {
      final stub = envStub(
        encryptedMap: {'VAR': 'val'},
        useDartDefine: true,
      );

      expect(stub, contains('String.fromEnvironment'));
    });

    test('embeds app key when not using dart define', () {
      final stub = envStub(
        encryptedMap: {'VAR': 'val'},
        appKey: 'my_secret_key',
        useDartDefine: false,
      );

      expect(stub, contains('my_secret_key'));
    });
  });

  group('formStub', () {
    test('contains correct class name', () {
      final stub = formStub(ReCase('login'));

      expect(stub, contains('class LoginForm extends NyFormWidget'));
    });

    test('contains fields method', () {
      final stub = formStub(ReCase('registration'));

      expect(stub, contains('fields() =>'));
    });

    test('contains Field types', () {
      final stub = formStub(ReCase('contact'));

      expect(stub, contains('Field.text'));
      expect(stub, contains('Field.currency'));
      expect(stub, contains('Field.picker'));
      expect(stub, contains('Field.textArea'));
    });

    test('imports nylo_framework', () {
      final stub = formStub(ReCase('settings'));

      expect(stub,
          contains("import 'package:nylo_framework/nylo_framework.dart'"));
    });
  });

  group('bottomSheetModalStub', () {
    test('contains correct class name', () {
      final stub = bottomSheetModalStub(ReCase('user_options'));

      expect(stub, contains('class UserOptionsModal extends StatelessWidget'));
    });

    test('contains build method', () {
      final stub = bottomSheetModalStub(ReCase('settings'));

      expect(stub, contains('Widget build(BuildContext context)'));
    });

    test('contains const constructor', () {
      final stub = bottomSheetModalStub(ReCase('filter'));

      expect(stub, contains('const FilterModal({super.key})'));
    });

    test('imports flutter material', () {
      final stub = bottomSheetModalStub(ReCase('test'));

      expect(stub, contains("import 'package:flutter/material.dart'"));
    });
  });

  group('bottomSheetModalStaticMethodStub', () {
    test('generates static show method', () {
      final stub = bottomSheetModalStaticMethodStub(ReCase('share'));

      expect(stub, contains('static Future<void> showShare'));
      expect(stub, contains('ShareModal()'));
    });
  });

  group('buttonStub', () {
    test('contains correct class name', () {
      final stub = buttonStub(ReCase('primary'));

      expect(stub, contains('class PrimaryButton extends StatefulAppButton'));
    });

    test('contains buildButton method', () {
      final stub = buttonStub(ReCase('submit'));

      expect(stub, contains('Widget buildButton(BuildContext context'));
    });

    test('contains Container widget', () {
      final stub = buttonStub(ReCase('action'));

      expect(stub, contains('Container('));
    });

    test('contains color properties', () {
      final stub = buttonStub(ReCase('custom'));

      expect(stub, contains('final Color? backgroundColor'));
      expect(stub, contains('final Color? contentColor'));
    });
  });

  group('buttonStaticMethodStub', () {
    test('generates static factory method', () {
      final stub = buttonStaticMethodStub(ReCase('secondary'));

      expect(stub, contains('static Widget secondary('));
      expect(stub, contains('SecondaryButton('));
    });
  });

  group('customCommandStub', () {
    test('contains correct command name', () {
      final stub = customCommandStub(customCommand: ReCase('sync_data'));

      expect(stub, contains('class _SyncDataCommand extends NyCustomCommand'));
    });

    test('contains handle method', () {
      final stub = customCommandStub(customCommand: ReCase('migrate'));

      expect(stub, contains('Future<void> handle(CommandResult result)'));
    });

    test('contains builder method', () {
      final stub = customCommandStub(customCommand: ReCase('generate'));

      expect(stub, contains('CommandBuilder builder(CommandBuilder command)'));
    });

    test('contains main function', () {
      final stub = customCommandStub(customCommand: ReCase('deploy'));

      expect(stub, contains('void main(arguments)'));
    });

    test('uses default category app', () {
      final stub = customCommandStub(customCommand: ReCase('test'));

      expect(stub, contains('app:test'));
    });

    test('uses custom category when specified', () {
      final stub = customCommandStub(
        customCommand: ReCase('backup'),
        category: 'db',
      );

      expect(stub, contains('db:backup'));
    });

    test('imports ny_cli', () {
      final stub = customCommandStub(customCommand: ReCase('example'));

      expect(
          stub, contains("import 'package:nylo_framework/metro/ny_cli.dart'"));
    });
  });
}
