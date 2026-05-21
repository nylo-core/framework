import 'package:flutter_test/flutter_test.dart';
import 'package:recase/recase.dart';
import 'package:nylo_framework/metro/stubs/model_stub.dart';
import 'package:nylo_framework/metro/stubs/controller_stub.dart';
import 'package:nylo_framework/metro/stubs/page_stub.dart';

void main() {
  group('modelStub', () {
    test('contains correct class name in PascalCase', () {
      final stub = modelStub(modelName: ReCase('user_profile'));

      expect(stub, contains('class UserProfile extends Model'));
    });

    test('contains correct storage key in snake_case', () {
      final stub = modelStub(modelName: ReCase('user_profile'));

      expect(stub, contains('static StorageKey key = "user_profile"'));
    });

    test('extends Model class', () {
      final stub = modelStub(modelName: ReCase('product'));

      expect(stub, contains('extends Model'));
    });

    test('contains fromJson constructor', () {
      final stub = modelStub(modelName: ReCase('order'));

      expect(stub, contains('Order.fromJson(data)'));
    });

    test('contains toJson method', () {
      final stub = modelStub(modelName: ReCase('cart'));

      expect(stub, contains('toJson()'));
    });

    test('imports nylo_framework', () {
      final stub = modelStub(modelName: ReCase('item'));

      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart'"),
      );
    });

    test('handles single word name', () {
      final stub = modelStub(modelName: ReCase('user'));

      expect(stub, contains('class User extends Model'));
      expect(stub, contains('static StorageKey key = "user"'));
    });

    test('handles multi-word name with underscores', () {
      final stub = modelStub(modelName: ReCase('shopping_cart_item'));

      expect(stub, contains('class ShoppingCartItem extends Model'));
      expect(stub, contains('static StorageKey key = "shopping_cart_item"'));
    });
  });

  group('controllerStub', () {
    test('contains correct class name with Controller suffix', () {
      final stub = controllerStub(controllerName: 'home');

      expect(stub, contains('class HomeController extends Controller'));
    });

    test('has construct method', () {
      final stub = controllerStub(controllerName: 'settings');

      expect(stub, contains('construct(BuildContext context)'));
    });

    test('imports controller base class', () {
      final stub = controllerStub(controllerName: 'profile');

      expect(stub, contains("import '/app/controllers/controller.dart'"));
    });

    test('imports flutter widgets', () {
      final stub = controllerStub(controllerName: 'dashboard');

      expect(stub, contains("import 'package:flutter/widgets.dart'"));
    });

    test('calls super.construct', () {
      final stub = controllerStub(controllerName: 'auth');

      expect(stub, contains('super.construct(context)'));
    });

    test('handles PascalCase name correctly', () {
      final stub = controllerStub(controllerName: 'UserProfile');

      expect(stub, contains('class UserProfileController extends Controller'));
    });
  });

  group('pageStub', () {
    test('contains StatefulWidget class', () {
      final stub = pageStub(className: 'home');

      expect(stub, contains('class HomePage extends NyStatefulWidget'));
    });

    test('has correct route path', () {
      final stub = pageStub(className: 'user_profile');

      expect(stub, contains('static RouteView path = ("/user-profile"'));
    });

    test('contains State class', () {
      final stub = pageStub(className: 'settings');

      expect(stub, contains('class _SettingsPageState extends NyPage'));
    });

    test('imports flutter material', () {
      final stub = pageStub(className: 'dashboard');

      expect(stub, contains("import 'package:flutter/material.dart'"));
    });

    test('imports nylo_framework', () {
      final stub = pageStub(className: 'profile');

      expect(
        stub,
        contains("import 'package:nylo_framework/nylo_framework.dart'"),
      );
    });

    test('has view method', () {
      final stub = pageStub(className: 'login');

      expect(stub, contains('Widget view(BuildContext context)'));
    });

    test('has init getter', () {
      final stub = pageStub(className: 'register');

      expect(stub, contains('get init =>'));
    });

    test('has Scaffold in view', () {
      final stub = pageStub(className: 'checkout');

      expect(stub, contains('return Scaffold('));
    });

    test('has AppBar with title', () {
      final stub = pageStub(className: 'cart');

      expect(stub, contains('AppBar('));
      expect(stub, contains('title: Text("Cart")'));
    });

    test('handles multi-word className for route', () {
      final stub = pageStub(className: 'shopping_cart');

      expect(stub, contains('"/shopping-cart"'));
    });
  });
}
