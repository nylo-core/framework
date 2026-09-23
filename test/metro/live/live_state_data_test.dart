import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/commands/live/live_commands.dart';
import 'package:nylo_framework/metro/live/live_output.dart';
import 'package:nylo_framework/metro/live/live_state_fields.dart';

void main() {
  /// A `state.data` reply for a conversation page with a nested list.
  Map<String, Object?> payload({
    Object? data = const {'id': 42, 'title': 'Team standup'},
    Object? queryParameters,
    List<String> actions = const ['refresh', '#markRead'],
    bool nested = true,
  }) => {
    'route': '/conversation-detail',
    'state': {
      'name': 'Closure: () => _ConversationDetailPageState',
      'state': '_ConversationDetailPageState',
      'widget': 'ConversationDetailPage',
      'kind': 'NyPage',
      'controller': 'ConversationDetailController',
      'data': data,
      'queryParameters': queryParameters,
      'actions': actions,
    },
    'states': [
      {
        'name': 'Closure: () => _ConversationDetailPageState',
        'state': '_ConversationDetailPageState',
        'widget': 'ConversationDetailPage',
        'kind': 'NyPage',
      },
      if (nested)
        {
          'name': 'message-list',
          'state': '_MessageListWidgetState',
          'widget': 'MessageListWidget',
          'kind': 'NyState',
        },
    ],
  };

  String render(
    Map<String, Object?> reply, {
    List<LiveStateField>? fields,
    String? unavailable,
    bool full = false,
  }) {
    final LiveBlock block = LiveBlock();
    renderStateData(
      block,
      reply,
      fields: fields,
      unavailable: unavailable,
      full: full,
      target: 'data',
    );
    return block.lines.map((line) => line.$2).join('\n');
  }

  test('shows what the page is, and the data it was opened with', () {
    final String text = render(payload());

    expect(text, contains('ConversationDetailPage · NyPage'));
    expect(
      text,
      contains('state       Closure: () => _ConversationDetailPageState'),
    );
    expect(text, contains('route       /conversation-detail'));
    expect(text, contains('controller  ConversationDetailController'));
    expect(text, contains('actions     refresh, #markRead'));
    expect(text, contains('"title": "Team standup"'));
  });

  test('says when a page was opened with no data', () {
    expect(render(payload(data: null)), contains('No data was passed'));
  });

  test('says why a widget that is not a page never has data', () {
    final Map<String, Object?> reply = payload(data: null);
    (reply['state']! as Map)['controller'] = null;

    expect(render(reply), contains('only a NyStatefulWidget'));
  });

  test('shows query parameters only when the page has them', () {
    expect(render(payload()), isNot(contains('queryParameters')));
    expect(
      render(payload(queryParameters: {'tab': 'messages'})),
      contains('"tab": "messages"'),
    );
  });

  test('leaves out rows the page has nothing for', () {
    final Map<String, Object?> reply = payload(actions: const []);
    (reply['state']! as Map)['controller'] = null;

    final String text = render(reply);

    expect(text, isNot(contains('controller')));
    expect(text, isNot(contains('actions')));
  });

  test('lists a field with its value, and a collection with its count', () {
    final String text = render(
      payload(),
      fields: const [
        LiveStateField(
          name: 'conversation',
          type: 'Conversation',
          value: {'id': 42, 'unread': 3},
        ),
        LiveStateField(
          name: 'messages',
          type: 'List<Message>',
          value: [1, 2],
          count: 12,
        ),
        LiveStateField(name: 'isTyping', type: 'bool', value: false),
      ],
    );

    expect(text, contains('conversation  {"id":42,"unread":3}'));
    expect(text, contains('messages      [1,2]  · 12 items'));
    expect(text, contains('isTyping      false'));
  });

  test('shows the type of a value the app could not turn into JSON', () {
    final String text = render(
      payload(),
      fields: const [
        LiveStateField(
          name: 'scroll',
          type: 'ScrollController',
          value: "Instance of 'ScrollController'",
        ),
      ],
    );

    expect(text, contains('scroll  ScrollController'));
    expect(text, isNot(contains('Instance of')));
  });

  test('says why a field could not be read', () {
    expect(
      render(
        payload(),
        fields: const [
          LiveStateField(name: 'user', type: 'User', unread: 'not initialized'),
        ],
      ),
      contains('user  (not initialized)'),
    );
  });

  test('says when only the first items of a long collection were read', () {
    expect(
      render(
        payload(),
        fields: const [
          LiveStateField(
            name: 'rows',
            type: 'List<int>',
            value: [1],
            count: 250,
            truncated: true,
          ),
        ],
      ),
      contains('· 250 items, first shown'),
    );
  });

  test('shortens a long value, and prints it whole with --full', () {
    final List<LiveStateField> fields = [
      LiveStateField(
        name: 'notes',
        type: 'List<String>',
        value: List<String>.filled(40, 'a long note to print'),
        count: 40,
      ),
    ];

    expect(render(payload(), fields: fields), contains('…'));
    final String full = render(payload(), fields: fields, full: true);
    expect(full, isNot(contains('…')));
    expect(full, contains('notes  · 40 items'));
  });

  test('says when a state declares no fields of its own', () {
    expect(
      render(payload(), fields: const []),
      contains('no fields of its own'),
    );
  });

  test('explains why fields are missing instead of listing none', () {
    final String text = render(
      payload(),
      unavailable: 'Run the app in debug mode.',
    );

    expect(text, contains('fields'));
    expect(text, contains('Run the app in debug mode.'));
    expect(text, isNot(contains('no fields of its own')));
  });

  test('leaves out fields entirely when they were not asked for', () {
    expect(render(payload()), isNot(contains('fields')));
  });

  test('lists the other states on screen and how to look at one', () {
    final String text = render(payload());

    expect(text, contains('Also on screen'));
    expect(text, contains('MessageListWidget'));
    expect(text, contains('message-list'));
    expect(text, contains('data MessageListWidget'));
    expect(
      text,
      isNot(contains('ConversationDetailPage  Closure')),
      reason: 'the state being shown is not listed again',
    );
  });

  test('leaves out the list when the page is the only state', () {
    expect(render(payload(nested: false)), isNot(contains('Also on screen')));
  });
}
