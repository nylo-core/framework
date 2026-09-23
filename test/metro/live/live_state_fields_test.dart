import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_app.dart';
import 'package:nylo_framework/metro/live/live_state_fields.dart';

import 'fake_servers.dart';

void main() {
  late FakeNyloApp server;
  late LiveApp app;

  /// The `inspect` block a running Nylo app sends with `state.data`.
  Map<String, Object?> inspect({
    String library = 'package:nylo_support/live/src/live_state_inspector.dart',
    String? variable = 'nyLiveInspectedState',
    String? encoder = 'nyLiveInspectJson',
  }) => {
    'library': library,
    'variable': variable,
    'encoder': encoder,
    'skip': const ['State', 'NyBaseState', 'NyPage', 'NyState'],
  };

  /// Connects to a fake app whose captured state holds [state].
  Future<List<LiveStateField>> read(
    FakeStateObject state, {
    Map<String, Object?>? block,
  }) async {
    server = await FakeNyloApp.start(inspected: state);
    app = await LiveApp.connect(
      server.wsUri,
      device: 'iPhone',
      package: 'shop',
    );
    addTearDown(() async {
      await app.close();
      await server.close();
    });
    return LiveStateFields.read(app, block ?? inspect());
  }

  test('reads the fields the state class declares itself', () async {
    final List<LiveStateField> fields = await read(
      FakeStateObject(
        fields: const [
          FakeField.framework('stateName'),
          FakeField.framework('_debugLifecycleState', owner: 'State'),
          FakeField.own(
            'conversation',
            value: {'id': 42, 'title': 'Team standup'},
            className: 'Conversation',
          ),
          FakeField.own('isTyping', value: false, className: 'bool'),
        ],
      ),
    );

    expect(fields.map((field) => field.name), ['conversation', 'isTyping']);
    expect(fields.first.type, 'Conversation');
    expect(fields.first.value, {'id': 42, 'title': 'Team standup'});
    expect(fields.last.value, false);
  });

  test('skips a generic base class', () async {
    final List<LiveStateField> fields = await read(
      FakeStateObject(
        fields: const [
          FakeField.framework('stateData', owner: 'NyBaseState<HomePage>'),
          FakeField.own('count', value: 1, className: 'int'),
        ],
      ),
    );

    expect(fields.map((field) => field.name), ['count']);
  });

  test('counts a collection field', () async {
    final List<LiveStateField> fields = await read(
      FakeStateObject(
        fields: const [
          FakeField.own(
            'messages',
            value: [1, 2, 3],
            className: 'List<Message>',
          ),
        ],
      ),
    );

    expect(fields.single.count, 3);
    expect(fields.single.type, 'List<Message>');
    expect(fields.single.value, [1, 2, 3]);
  });

  test('says why a field has nothing to read', () async {
    final List<LiveStateField> fields = await read(
      FakeStateObject(
        fields: const [
          FakeField.sentinel('lateUnset', 'NotInitialized'),
          FakeField.own('ready', value: true, className: 'bool'),
        ],
      ),
    );

    expect(fields.first.unread, 'not initialized');
    expect(fields.first.value, isNull);
    expect(fields.last.value, true);
  });

  test('passes only readable fields to the app, keeping their order', () async {
    final FakeStateObject state = FakeStateObject(
      fields: const [
        FakeField.framework('stateName'),
        FakeField.own('a', value: 1, className: 'int'),
        FakeField.sentinel('b', 'NotInitialized'),
        FakeField.own('c', value: 3, className: 'int'),
      ],
    );

    await read(state);

    expect(state.lastExpression, 'nyLiveInspectJson([v0, null, v1])');
    expect(state.lastScope, {'v0': 'objects/1', 'v1': 'objects/3'});
  });

  test('fetches the whole value when the VM service truncates it', () async {
    final List<LiveStateField> fields = await read(
      FakeStateObject(
        truncateAt: 20,
        fields: [
          FakeField.own(
            'notes',
            value: List<String>.filled(40, 'note'),
            className: 'List<String>',
          ),
        ],
      ),
    );

    expect(fields.single.count, 40);
    expect((fields.single.value as List).length, 40);
  });

  test('reports a value the app could not turn into JSON as opaque', () async {
    final List<LiveStateField> fields = await read(
      FakeStateObject(
        fields: const [
          FakeField.own(
            'scroll',
            value: "Instance of 'ScrollController'",
            className: 'ScrollController',
          ),
          FakeField.own('title', value: 'Standup', className: 'String'),
        ],
      ),
    );

    expect(fields.first.isOpaque, isTrue);
    expect(fields.last.isOpaque, isFalse);
  });

  test('finds the library again when Nylo moved the file', () async {
    final List<LiveStateField> fields = await read(
      FakeStateObject(
        libraryUri: 'package:nylo_support/live/live_state_inspector.dart',
        fields: const [FakeField.own('count', value: 2, className: 'int')],
      ),
    );

    expect(fields.single.name, 'count');
  });

  test('reads nothing when no state was captured', () async {
    expect(
      await read(FakeStateObject(captured: false, fields: const [])),
      isEmpty,
    );
  });

  test('reads nothing when the state declares no fields of its own', () async {
    expect(
      await read(
        FakeStateObject(fields: const [FakeField.framework('stateName')]),
      ),
      isEmpty,
    );
  });

  test('explains a build that cannot evaluate expressions', () async {
    expect(
      () => read(
        FakeStateObject(
          evaluates: false,
          fields: const [FakeField.own('count', value: 1, className: 'int')],
        ),
      ),
      throwsA(
        isA<LiveStateFieldsUnavailable>().having(
          (e) => e.message,
          'message',
          contains('debug mode'),
        ),
      ),
    );
  });

  test('passes on an error the app raised while encoding', () async {
    expect(
      () => read(
        FakeStateObject(
          evaluationError: 'Unhandled exception:\nBad state: no',
          fields: const [FakeField.own('count', value: 1, className: 'int')],
        ),
      ),
      throwsA(
        isA<LiveStateFieldsUnavailable>().having(
          (e) => e.message,
          'message',
          contains('Unhandled exception:'),
        ),
      ),
    );
  });

  test('explains an app whose Nylo is too old to expose its fields', () async {
    expect(
      () => read(
        FakeStateObject(fields: const []),
        block: inspect(variable: null, encoder: null),
      ),
      throwsA(
        isA<LiveStateFieldsUnavailable>().having(
          (e) => e.message,
          'message',
          contains('doesn\'t expose its state fields'),
        ),
      ),
    );
  });

  test('explains an app whose inspector cannot be found', () async {
    expect(
      () => read(
        FakeStateObject(fields: const []),
        block: inspect(library: 'package:other/elsewhere.dart'),
      ),
      throwsA(
        isA<LiveStateFieldsUnavailable>().having(
          (e) => e.message,
          'message',
          contains('couldn\'t find Nylo\'s state inspector'),
        ),
      ),
    );
  });

  test('a field survives the round trip to JSON', () {
    const LiveStateField field = LiveStateField(
      name: 'messages',
      type: 'List<Message>',
      value: [1, 2],
      count: 2,
      truncated: true,
    );

    expect(field.toJson(), {
      'name': 'messages',
      'type': 'List<Message>',
      'count': 2,
      'truncated': true,
      'value': [1, 2],
    });
    expect(
      const LiveStateField(
        name: 'late',
        type: 'String',
        unread: 'not initialized',
      ).toJson(),
      {'name': 'late', 'type': 'String', 'unread': 'not initialized'},
    );
  });
}
