import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/menu.dart';

void main() {
  group('metroMenu', () {
    test('is a non-empty string', () {
      expect(metroMenu, isNotEmpty);
    });

    test('contains header information', () {
      expect(metroMenu, contains('Metro'));
      expect(metroMenu, contains('Nylo'));
      expect(metroMenu, contains('Anthony Gordon'));
    });

    test('contains usage section', () {
      expect(metroMenu, contains('Usage:'));
      expect(metroMenu, contains('command [options] [arguments]'));
    });

    test('contains options section', () {
      expect(metroMenu, contains('Options'));
      expect(metroMenu, contains('-h'));
    });

    test('contains All commands section', () {
      expect(metroMenu, contains('All commands:'));
    });

    group('Widget Commands section', () {
      test('contains section header', () {
        expect(metroMenu, contains('[Widget Commands]'));
      });

      test('contains make:page command', () {
        expect(metroMenu, contains('make:page'));
      });

      test('contains make:stateful_widget command', () {
        expect(metroMenu, contains('make:stateful_widget'));
      });

      test('contains make:stateless_widget command', () {
        expect(metroMenu, contains('make:stateless_widget'));
      });

      test('contains make:state_managed_widget command', () {
        expect(metroMenu, contains('make:state_managed_widget'));
      });

      test('contains make:navigation_hub command', () {
        expect(metroMenu, contains('make:navigation_hub'));
      });

      test('contains make:journey_widget command', () {
        expect(metroMenu, contains('make:journey_widget'));
      });

      test('contains make:bottom_sheet_modal command', () {
        expect(metroMenu, contains('make:bottom_sheet_modal'));
      });

      test('contains make:button command', () {
        expect(metroMenu, contains('make:button'));
      });

      test('contains make:form command', () {
        expect(metroMenu, contains('make:form'));
      });
    });

    group('Helper Commands section', () {
      test('contains section header', () {
        expect(metroMenu, contains('[Helper Commands]'));
      });

      test('contains make:model command', () {
        expect(metroMenu, contains('make:model'));
      });

      test('contains make:provider command', () {
        expect(metroMenu, contains('make:provider'));
      });

      test('contains make:api_service command', () {
        expect(metroMenu, contains('make:api_service'));
      });

      test('contains make:controller command', () {
        expect(metroMenu, contains('make:controller'));
      });

      test('contains make:event command', () {
        expect(metroMenu, contains('make:event'));
      });

      test('contains make:route_guard command', () {
        expect(metroMenu, contains('make:route_guard'));
      });

      test('contains make:config command', () {
        expect(metroMenu, contains('make:config'));
      });

      test('contains make:interceptor command', () {
        expect(metroMenu, contains('make:interceptor'));
      });

      test('contains make:command command', () {
        expect(metroMenu, contains('make:command'));
      });

      test('contains make:env command', () {
        expect(metroMenu, contains('make:env'));
      });
    });

    test('is a constant string', () {
      // Verify it can be used in const context
      const menu = metroMenu;
      expect(menu, equals(metroMenu));
    });
  });
}
