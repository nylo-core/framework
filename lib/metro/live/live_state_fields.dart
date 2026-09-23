import 'dart:convert';

import 'json_rpc_client.dart';
import 'live_app.dart';

/// One field of a running app's page state, read by `metro live:run data`.
class LiveStateField {
  /// Creates a [LiveStateField] named [name] of type [type].
  const LiveStateField({
    required this.name,
    required this.type,
    this.value,
    this.count,
    this.truncated = false,
    this.unread,
  });

  /// The field's name, as it's written on the state class.
  final String name;

  /// The runtime type of the field's value, e.g. `List<Message>`.
  final String type;

  /// The value, decoded from the app's JSON, or null when [unread] says why
  /// it couldn't be read.
  final Object? value;

  /// How many items the value holds, for a list, set or map.
  final int? count;

  /// Whether only the first items of a long collection were encoded.
  final bool truncated;

  /// Why the value couldn't be read, e.g. `not initialized`, or null when it
  /// was.
  final String? unread;

  /// Whether [value] is the app's `toString()` rather than real JSON.
  ///
  /// A value Nylo can't turn into JSON - a controller, a listener - comes
  /// back as text like `Instance of 'ScrollController'`, which says no more
  /// than [type] does.
  bool get isOpaque {
    final Object? read = value;
    return read is String && read.startsWith('Instance of ');
  }

  /// The `--json` representation.
  Map<String, Object?> toJson() => {
    'name': name,
    'type': type,
    if (count != null) 'count': count,
    if (truncated) 'truncated': true,
    if (unread != null) 'unread': unread,
    if (unread == null) 'value': value,
  };
}

/// Why the fields of a state couldn't be read.
class LiveStateFieldsUnavailable implements Exception {
  /// Creates a [LiveStateFieldsUnavailable] explained by [message].
  const LiveStateFieldsUnavailable(this.message);

  /// What stopped the read, written for the terminal.
  final String message;

  @override
  String toString() => message;
}

/// Reads the fields a developer declared on the state `metro live:run data`
/// described.
///
/// A Flutter app has no reflection, so the app itself can't enumerate them.
/// Instead `state.data` leaves the state object in a top-level variable and
/// says where, and this reads it back over the VM service: the variable, then
/// the object's fields, keeping only those the state class declares itself.
/// Each value is then encoded by the app, through the same JSON encoder every
/// other live command uses, so models and dates come back as real JSON.
class LiveStateFields {
  LiveStateFields._();

  /// Instance kinds that hold no value to read.
  static const Set<String> _sentinelKinds = {
    'NotInitialized',
    'BeingInitialized',
    'OptimizedOut',
    'Collected',
    'Expired',
    'Free',
  };

  /// How a sentinel kind is explained in the output.
  static String _explain(String kind) => switch (kind) {
    'NotInitialized' => 'not initialized',
    'BeingInitialized' => 'being initialized',
    'OptimizedOut' => 'optimized out',
    'Collected' => 'collected',
    'Expired' || 'Free' => 'no longer available',
    _ => 'unavailable',
  };

  /// The most characters of an encoded value the VM service is asked for.
  static const int _maxValueLength = 2000000;

  /// Reads the fields of the state the app captured, described by the
  /// `inspect` block of a `state.data` reply.
  ///
  /// Throws a [LiveStateFieldsUnavailable] when the app's build can't answer:
  /// a release or profile build, or a runtime whose VM service doesn't
  /// support reading objects.
  static Future<List<LiveStateField>> read(
    LiveApp app,
    Map<String, Object?> inspect, {
    Duration? timeout,
  }) async {
    final String? variable = inspect['variable'] as String?;
    final String? encoder = inspect['encoder'] as String?;
    if (variable == null || encoder == null) {
      throw const LiveStateFieldsUnavailable(
        'This app\'s Nylo version doesn\'t expose its state fields.',
      );
    }
    final Set<String> skip = {
      for (final Object? name in inspect['skip'] as List? ?? const []) '$name',
    };

    try {
      final String library = await _library(
        app,
        inspect['library'] as String?,
        timeout,
      );
      final Map<String, Object?> state = await _capturedState(
        app,
        library,
        variable,
        timeout,
      );
      if (state.isEmpty) return const [];

      final List<_RawField> raw = _ownFields(state, skip);
      if (raw.isEmpty) return const [];
      return await _encode(app, library, encoder, raw, timeout);
    } on JsonRpcException catch (e) {
      throw LiveStateFieldsUnavailable(
        'The app didn\'t let Metro read its state fields (${e.details}).',
      );
    }
  }

  /// The id of the library holding the app's inspection hooks.
  ///
  /// Matches the URI the app reported, and falls back to the file name so a
  /// newer Nylo that moved the file still works.
  static Future<String> _library(
    LiveApp app,
    String? uri,
    Duration? timeout,
  ) async {
    final Object? isolate = await app.client.call('getIsolate', {
      'isolateId': app.isolateId,
    }, timeout);
    final Object? libraries = isolate is Map ? isolate['libraries'] : null;
    if (libraries is! List) {
      throw const LiveStateFieldsUnavailable(
        'This build doesn\'t expose its libraries, so its state fields can\'t '
        'be read. Run the app in debug mode.',
      );
    }

    final String? file = uri?.split('/').last;
    String? fallback;
    for (final Object? library in libraries) {
      if (library is! Map) continue;
      final Object? id = library['id'];
      final Object? found = library['uri'];
      if (id is! String || found is! String) continue;
      if (found == uri) return id;
      if (file != null && found.endsWith('/$file')) fallback ??= id;
    }
    if (fallback != null) return fallback;
    throw const LiveStateFieldsUnavailable(
      'Metro couldn\'t find Nylo\'s state inspector in the running app.',
    );
  }

  /// The captured state object, or an empty map when nothing was captured.
  static Future<Map<String, Object?>> _capturedState(
    LiveApp app,
    String library,
    String variable,
    Duration? timeout,
  ) async {
    final Object? loaded = await _object(app, library, timeout);
    final Object? variables = loaded is Map ? loaded['variables'] : null;
    if (variables is! List) return const {};

    String? fieldId;
    for (final Object? field in variables) {
      if (field is Map && field['name'] == variable) {
        final Object? id = field['id'];
        if (id is String) fieldId = id;
        break;
      }
    }
    if (fieldId == null) return const {};

    final Object? field = await _object(app, fieldId, timeout);
    final Object? value = field is Map ? field['staticValue'] : null;
    if (value is! Map) return const {};
    final Object? id = value['id'];
    if (id is! String || value['kind'] == 'Null') return const {};

    final Object? state = await _object(app, id, timeout);
    return state is Map ? Map<String, Object?>.from(state) : const {};
  }

  /// The fields [state] declares itself: everything not owned by a class in
  /// [skip], in the order the VM service reports them.
  static List<_RawField> _ownFields(
    Map<String, Object?> state,
    Set<String> skip,
  ) {
    final Object? fields = state['fields'];
    if (fields is! List) return const [];

    final List<_RawField> own = [];
    for (final Object? bound in fields) {
      if (bound is! Map) continue;
      final Object? declaration = bound['decl'];
      final Map<String, Object?> declared = declaration is Map
          ? Map<String, Object?>.from(declaration)
          : const {};
      final Object? owner = declared['owner'];
      final String ownerName = owner is Map ? '${owner['name']}' : '';
      // A generic base class is reported as `NyBaseState<HomePage>`.
      if (skip.contains(ownerName.split('<').first)) continue;

      final String name = '${declared['name'] ?? bound['name'] ?? ''}';
      if (name.isEmpty) continue;

      final Object? value = bound['value'];
      final Map<String, Object?> instance = value is Map
          ? Map<String, Object?>.from(value)
          : const {};
      final String kind = '${instance['kind'] ?? instance['type'] ?? ''}';
      final Object? id = instance['id'];
      final bool readable =
          instance['type'] != 'Sentinel' &&
          !_sentinelKinds.contains(kind) &&
          id is String;
      own.add(
        _RawField(
          name: name,
          type: '${(instance['class'] as Map?)?['name'] ?? 'Object'}',
          id: readable ? id : null,
          unread: readable ? null : _explain(kind),
        ),
      );
    }
    return own;
  }

  /// Encodes every field's value in one call, by handing the app's encoder
  /// the objects the VM service just named.
  static Future<List<LiveStateField>> _encode(
    LiveApp app,
    String library,
    String encoder,
    List<_RawField> fields,
    Duration? timeout,
  ) async {
    final Map<String, Object?> scope = {};
    final List<String> arguments = [];
    for (final _RawField field in fields) {
      final String? id = field.id;
      if (id == null) {
        arguments.add('null');
        continue;
      }
      final String name = 'v${scope.length}';
      scope[name] = id;
      arguments.add(name);
    }

    final Object? evaluated;
    try {
      evaluated = await app.client.call('evaluate', {
        'isolateId': app.isolateId,
        'targetId': library,
        'expression': '$encoder([${arguments.join(', ')}])',
        if (scope.isNotEmpty) 'scope': scope,
      }, timeout);
    } on JsonRpcException catch (e) {
      // A profile build is compiled ahead of time, so it has no compiler to
      // evaluate with.
      throw LiveStateFieldsUnavailable(
        'This build can\'t evaluate expressions, so its state fields can\'t '
        'be read (${e.details}). Run the app in debug mode.',
      );
    }

    final Map<String, Object?> result = evaluated is Map
        ? Map<String, Object?>.from(evaluated)
        : const {};
    if (result['kind'] != 'String') {
      throw LiveStateFieldsUnavailable(
        _evaluationError(result) ??
            'This build can\'t evaluate expressions, so its state fields '
                'can\'t be read. Run the app in debug mode.',
      );
    }

    final List<Object?> described = _decode(
      await _fullString(app, result, timeout),
    );
    return [
      for (int i = 0; i < fields.length; i++)
        _merge(fields[i], i < described.length ? described[i] : null),
    ];
  }

  /// The whole encoded string: the VM service truncates the result of an
  /// evaluation, so a truncated one is fetched again in full.
  static Future<String> _fullString(
    LiveApp app,
    Map<String, Object?> result,
    Duration? timeout,
  ) async {
    if (result['valueAsStringIsTruncated'] != true) {
      return '${result['valueAsString'] ?? ''}';
    }
    final Object? id = result['id'];
    if (id is! String) return '${result['valueAsString'] ?? ''}';
    final Object? whole = await app.client.call('getObject', {
      'isolateId': app.isolateId,
      'objectId': id,
      'count': _maxValueLength,
    }, timeout);
    return whole is Map
        ? '${whole['valueAsString'] ?? ''}'
        : '${result['valueAsString'] ?? ''}';
  }

  static List<Object?> _decode(String encoded) {
    try {
      final Object? decoded = jsonDecode(encoded);
      return decoded is List ? decoded : const [];
    } on FormatException {
      throw const LiveStateFieldsUnavailable(
        'Metro couldn\'t read the state fields the app sent back.',
      );
    }
  }

  /// Combines what the VM service knows about a field with what the app
  /// encoded for it.
  static LiveStateField _merge(_RawField field, Object? described) {
    if (field.unread != null || described is! Map) {
      return LiveStateField(
        name: field.name,
        type: field.type,
        unread: field.unread ?? 'unavailable',
      );
    }
    final Object? count = described['count'];
    return LiveStateField(
      name: field.name,
      type: '${described['type'] ?? field.type}',
      value: described['value'],
      count: count is int ? count : null,
      truncated: described['truncated'] == true,
    );
  }

  /// The app's message for a failed evaluation, trimmed to its first line.
  static String? _evaluationError(Map<String, Object?> result) {
    final Object? message = result['message'];
    if (message is! String || message.isEmpty) return null;
    final String first = message.split('\n').first.trim();
    return first.isEmpty ? null : 'The app couldn\'t encode its fields: $first';
  }

  static Future<Object?> _object(
    LiveApp app,
    String objectId,
    Duration? timeout,
  ) => app.client.call('getObject', {
    'isolateId': app.isolateId,
    'objectId': objectId,
  }, timeout);
}

/// A field before the app encoded its value.
class _RawField {
  const _RawField({
    required this.name,
    required this.type,
    this.id,
    this.unread,
  });

  final String name;
  final String type;

  /// The VM service id of the value, or null when there's nothing to read.
  final String? id;

  /// Why there's nothing to read, or null when there is.
  final String? unread;
}
