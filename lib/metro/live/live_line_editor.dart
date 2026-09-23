import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Candidates that complete the last word of [line], the text before the
/// cursor.
typedef LiveCompleter = Future<List<String>> Function(String line);

/// The terminal a [LiveLineEditor] controls.
abstract class LiveTerminal {
  /// Whether input comes from an interactive terminal.
  bool get hasTerminal;

  /// Whether the terminal understands ANSI escape codes.
  bool get supportsAnsi;

  /// The terminal width in columns.
  int get columns;

  /// Turns off echo and line buffering, so each key arrives as it's typed.
  void enableRawMode();

  /// Puts back the modes that were active before [enableRawMode].
  void restoreMode();
}

/// The [LiveTerminal] for this process's stdin and stdout.
class StdioLiveTerminal implements LiveTerminal {
  /// Creates a [StdioLiveTerminal].
  const StdioLiveTerminal();

  static bool? _echoMode;
  static bool? _lineMode;

  @override
  bool get hasTerminal {
    try {
      return stdin.hasTerminal;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get supportsAnsi {
    try {
      return stdout.supportsAnsiEscapes;
    } catch (_) {
      return false;
    }
  }

  @override
  int get columns {
    try {
      return stdout.hasTerminal ? stdout.terminalColumns : 80;
    } catch (_) {
      return 80;
    }
  }

  @override
  void enableRawMode() {
    try {
      _echoMode ??= stdin.echoMode;
      _lineMode ??= stdin.lineMode;
      stdin.echoMode = false;
      stdin.lineMode = false;
    } on StdinException {
      // Not a terminal after all. Lines can still be read, without editing.
    }
  }

  @override
  void restoreMode() {
    final bool? echoMode = _echoMode;
    final bool? lineMode = _lineMode;
    _echoMode = null;
    _lineMode = null;
    try {
      if (lineMode != null) stdin.lineMode = lineMode;
      if (echoMode != null) stdin.echoMode = echoMode;
    } on StdinException {
      // Nothing to put back.
    }
  }
}

/// Reads lines for the `metro live` shell, with editing, history and Tab
/// completion.
///
/// When input isn't an interactive terminal, such as a script piped into
/// `metro live`, lines are read as they are, without editing.
class LiveLineEditor {
  /// Creates a [LiveLineEditor] that reads bytes from [input] and writes to
  /// [output].
  ///
  /// [history] seeds the lines ↑ and ↓ step through, oldest first, keeping
  /// the newest [historyLimit]. [complete] supplies Tab completions.
  LiveLineEditor({
    required Stream<List<int>> input,
    required StringSink output,
    LiveTerminal terminal = const StdioLiveTerminal(),
    List<String> history = const [],
    int historyLimit = 500,
    LiveCompleter? complete,
  }) : _input = input,
       _output = output,
       _terminal = terminal,
       _history = List<String>.of(history),
       _historyLimit = historyLimit < 0 ? 0 : historyLimit,
       _complete = complete {
    _trimHistory();
  }

  final Stream<List<int>> _input;
  final StringSink _output;
  final LiveTerminal _terminal;
  final List<String> _history;
  final int _historyLimit;
  final LiveCompleter? _complete;

  StreamSubscription<List<int>>? _subscription;
  final List<int> _pending = [];
  bool _inputDone = false;
  bool _closed = false;

  Completer<String?>? _reading;
  String _prompt = '';
  bool _interactive = false;
  bool _ansi = false;
  bool _rawMode = false;

  final List<int> _line = [];
  int _cursor = 0;
  int _historyIndex = 0;
  List<int>? _draft;
  bool _afterCarriageReturn = false;
  bool _completing = false;
  int _generation = 0;

  static final RegExp _sgr = RegExp(r'\x1B\[[0-9;]*m');
  static const int _maxListed = 100;

  /// Submitted lines, oldest first.
  List<String> get history => _history;

  /// Whether a [readLine] call is waiting for a line.
  bool get isReading => _reading != null;

  /// Prints [prompt] and reads one line.
  ///
  /// Returns null when input ends, or when Ctrl+D is pressed on an empty
  /// line. A line that was partly typed when input ends is returned as it
  /// is. Lines that aren't blank are added to [history], unless they repeat
  /// the previous line.
  Future<String?> readLine(String prompt) {
    if (_reading != null) {
      throw StateError('A line is already being read.');
    }
    if (_closed) return Future<String?>.value(null);

    final Completer<String?> reading = Completer<String?>();
    _reading = reading;
    _prompt = prompt;
    _interactive = _terminal.hasTerminal;
    _ansi = _interactive && _terminal.supportsAnsi;
    _line.clear();
    _cursor = 0;
    _historyIndex = _history.length;
    _draft = null;
    _completing = false;
    _generation++;

    if (_interactive) {
      _terminal.enableRawMode();
      _rawMode = true;
    }
    _output.write(_interactive && !_ansi ? _stripAnsi(prompt) : prompt);

    _listen();
    _process();
    return reading.future;
  }

  /// Discards the line being typed and shows a fresh prompt.
  ///
  /// The shell calls this when Ctrl+C is pressed at the prompt.
  void cancelLine() {
    _cancel();
    _process();
  }

  /// Prints [text] above the prompt, keeping what's been typed so far.
  ///
  /// When no line is being read, [text] is printed as a line on its own.
  void printAbove(String text) {
    if (_reading == null || !_interactive) {
      _output.writeln(text);
      return;
    }
    if (_ansi) {
      _output.write('\r\x1B[K$text\n');
      _refresh();
    } else {
      _output.write(
        '\n$text\n${_stripAnsi(_prompt)}${String.fromCharCodes(_line)}',
      );
    }
  }

  /// Replaces the prompt, redrawing the line being typed.
  void updatePrompt(String prompt) {
    if (prompt == _prompt) return;
    _prompt = prompt;
    if (_reading == null || !_interactive) return;
    if (_ansi) {
      _refresh();
    } else {
      _output.write('\n${_stripAnsi(prompt)}${String.fromCharCodes(_line)}');
    }
  }

  /// Puts the terminal back the way it was and stops reading input.
  ///
  /// A [readLine] call still waiting returns null. Safe to call twice.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _restoreRawMode();
    _completing = false;
    _generation++;
    final Completer<String?>? reading = _reading;
    _reading = null;
    if (reading != null && !reading.isCompleted) reading.complete(null);

    final StreamSubscription<List<int>>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _listen() {
    if (_subscription != null || _inputDone || _closed) return;
    final ByteConversionSink decoder = const Utf8Decoder(
      allowMalformed: true,
    ).startChunkedConversion(_TextSink(_onText));
    _subscription = _input.listen(
      decoder.add,
      onError: (Object _) {
        // A broken input stream ends like a closed one, in onDone.
      },
      onDone: () {
        decoder.close();
        _inputDone = true;
        _process();
      },
    );
  }

  void _onText(String text) {
    _pending.addAll(text.runes);
    _process();
  }

  void _process() {
    if (_reading == null || _completing) return;
    if (!_interactive) {
      _processPlain();
      return;
    }

    while (_reading != null && !_completing && _pending.isNotEmpty) {
      final _KeyPress? press = _parseKey(_pending);
      if (press == null) break; // Wait for the rest of an escape sequence.
      _pending.removeRange(0, press.length);
      _handle(press);
    }

    if (_inputDone && _reading != null && !_completing) {
      _pending.clear();
      _finish(_line.isEmpty ? null : String.fromCharCodes(_line));
    }
  }

  void _processPlain() {
    while (_reading != null) {
      final int newline = _pending.indexOf(0x0A);
      if (newline == -1) break;
      final List<int> line = _pending.sublist(0, newline);
      _pending.removeRange(0, newline + 1);
      _finish(_withoutCarriageReturn(line));
    }

    if (_inputDone && _reading != null) {
      if (_pending.isEmpty) {
        _finish(null);
      } else {
        final List<int> rest = List<int>.of(_pending);
        _pending.clear();
        _finish(_withoutCarriageReturn(rest));
      }
    }
  }

  void _handle(_KeyPress press) {
    final bool afterCarriageReturn = _afterCarriageReturn;
    _afterCarriageReturn = press.key == _Key.enter;

    switch (press.key) {
      case _Key.insert:
        _insert(press.rune);
      case _Key.enter:
        _finish(String.fromCharCodes(_line));
      case _Key.lineFeed:
        if (!afterCarriageReturn) _finish(String.fromCharCodes(_line));
      case _Key.backspace:
        if (_cursor == 0) return;
        _cursor--;
        _line.removeAt(_cursor);
        _refresh();
      case _Key.delete:
        _deleteAtCursor();
      case _Key.left:
        if (_cursor == 0) return;
        _cursor--;
        _refresh(contentChanged: false);
      case _Key.right:
        if (_cursor == _line.length) return;
        _cursor++;
        _refresh(contentChanged: false);
      case _Key.home:
        if (_cursor == 0) return;
        _cursor = 0;
        _refresh(contentChanged: false);
      case _Key.end:
        if (_cursor == _line.length) return;
        _cursor = _line.length;
        _refresh(contentChanged: false);
      case _Key.up:
        _recallOlder();
      case _Key.down:
        _recallNewer();
      case _Key.deleteToStart:
        if (_cursor == 0) return;
        _line.removeRange(0, _cursor);
        _cursor = 0;
        _refresh();
      case _Key.deleteToEnd:
        if (_cursor == _line.length) return;
        _line.removeRange(_cursor, _line.length);
        _refresh();
      case _Key.deleteWord:
        _deleteWord();
      case _Key.clearScreen:
        if (!_ansi) return;
        _output.write('\x1B[2J\x1B[H');
        _refresh();
      case _Key.cancel:
        _cancel();
      case _Key.endOfInput:
        if (_line.isEmpty) {
          _finish(null);
        } else {
          _deleteAtCursor();
        }
      case _Key.tab:
        unawaited(_completeWord());
      case _Key.ignore:
        break;
    }
  }

  void _insert(int rune) {
    final bool atEnd = _cursor == _line.length;
    _line.insert(_cursor, rune);
    _cursor++;
    if (atEnd) {
      _output.write(String.fromCharCode(rune));
    } else {
      _refresh();
    }
  }

  void _deleteAtCursor() {
    if (_cursor == _line.length) return;
    _line.removeAt(_cursor);
    _refresh();
  }

  void _deleteWord() {
    int start = _cursor;
    while (start > 0 && _line[start - 1] == 0x20) {
      start--;
    }
    while (start > 0 && _line[start - 1] != 0x20) {
      start--;
    }
    if (start == _cursor) return;
    _line.removeRange(start, _cursor);
    _cursor = start;
    _refresh();
  }

  void _recallOlder() {
    if (_historyIndex == 0) return;
    if (_historyIndex >= _history.length) _draft = List<int>.of(_line);
    _historyIndex--;
    _replaceLine(_history[_historyIndex].runes.toList());
  }

  void _recallNewer() {
    if (_historyIndex >= _history.length) return;
    _historyIndex++;
    _replaceLine(
      _historyIndex == _history.length
          ? (_draft ?? <int>[])
          : _history[_historyIndex].runes.toList(),
    );
  }

  void _replaceLine(List<int> runes) {
    _line
      ..clear()
      ..addAll(runes);
    _cursor = _line.length;
    _refresh();
  }

  void _cancel() {
    if (_reading == null) return;
    _generation++;
    _completing = false;
    _line.clear();
    _cursor = 0;
    _historyIndex = _history.length;
    _draft = null;
    if (_interactive) {
      _output.write('^C\n${_ansi ? _prompt : _stripAnsi(_prompt)}');
    }
  }

  Future<void> _completeWord() async {
    final LiveCompleter? complete = _complete;
    if (complete == null) return;

    final int generation = _generation;
    final List<int> before = _line.sublist(0, _cursor);
    _completing = true;
    List<String> candidates = const [];
    try {
      candidates = await complete(String.fromCharCodes(before));
    } catch (_) {
      // A failing completer never gets in the way of typing.
    }

    // The line was submitted, cancelled or closed while candidates loaded.
    if (generation != _generation) return;
    _completing = false;
    _applyCompletion(before, candidates);
    _process();
  }

  void _applyCompletion(List<int> before, List<String> candidates) {
    final List<String> unique = candidates.toSet().toList();
    if (unique.isEmpty) {
      if (_ansi) _output.write('\x07');
      return;
    }

    final int start = _wordStart(before);
    final String word = String.fromCharCodes(before, start);
    if (unique.length == 1) {
      final String candidate = unique.single;
      final bool keepsGoing =
          candidate.endsWith('/') ||
          candidate.endsWith('=') ||
          candidate.endsWith(':');
      _replaceWord(start, keepsGoing ? candidate : '$candidate ');
      return;
    }

    final String prefix = _commonPrefix(unique);
    if (prefix.length > word.length &&
        prefix.toLowerCase().startsWith(word.toLowerCase())) {
      _replaceWord(start, prefix);
      return;
    }
    _listCandidates(unique);
  }

  void _replaceWord(int start, String text) {
    final List<int> runes = text.runes.toList();
    _line.replaceRange(start, _cursor, runes);
    _cursor = start + runes.length;
    _refresh();
  }

  void _listCandidates(List<String> candidates) {
    final List<String> sorted = List<String>.of(candidates)..sort();
    final List<String> shown = sorted.length > _maxListed
        ? sorted.sublist(0, _maxListed)
        : sorted;
    final int width =
        shown.map((candidate) => candidate.length).reduce((a, b) {
          return a > b ? a : b;
        }) +
        2;
    final int columns = _terminal.columns > 0 ? _terminal.columns : 80;
    final int perRow = columns ~/ width < 1 ? 1 : columns ~/ width;

    final List<String> rows = [];
    for (int i = 0; i < shown.length; i += perRow) {
      final int end = i + perRow < shown.length ? i + perRow : shown.length;
      rows.add(
        shown
            .sublist(i, end)
            .map((candidate) => candidate.padRight(width))
            .join()
            .trimRight(),
      );
    }
    if (sorted.length > _maxListed) {
      rows.add('…and ${sorted.length - _maxListed} more');
    }
    printAbove(rows.join('\n'));
  }

  void _refresh({bool contentChanged = true}) {
    if (_reading == null || !_interactive) return;
    if (_ansi) {
      final int after = _line.length - _cursor;
      _output.write(
        '\r$_prompt${String.fromCharCodes(_line)}\x1B[K'
        '${after > 0 ? '\x1B[${after}D' : ''}',
      );
    } else if (contentChanged) {
      _output.write('\n${_stripAnsi(_prompt)}${String.fromCharCodes(_line)}');
    }
  }

  void _finish(String? line) {
    final Completer<String?>? reading = _reading;
    if (reading == null) return;
    _reading = null;
    _generation++;
    _completing = false;
    if (_interactive) _output.write('\n');
    _restoreRawMode();
    if (line != null) _remember(line);
    reading.complete(line);
  }

  void _restoreRawMode() {
    if (!_rawMode) return;
    _rawMode = false;
    _terminal.restoreMode();
  }

  void _remember(String line) {
    if (line.trim().isEmpty) return;
    if (_history.isNotEmpty && _history.last == line) return;
    _history.add(line);
    _trimHistory();
  }

  void _trimHistory() {
    final int excess = _history.length - _historyLimit;
    if (excess > 0) _history.removeRange(0, excess);
  }

  static String _stripAnsi(String text) => text.replaceAll(_sgr, '');

  static String _withoutCarriageReturn(List<int> runes) {
    final int end = runes.isNotEmpty && runes.last == 0x0D
        ? runes.length - 1
        : runes.length;
    return String.fromCharCodes(runes, 0, end);
  }

  /// Where the word before the cursor starts: after the last space that
  /// isn't inside quotes.
  static int _wordStart(List<int> runes) {
    int start = 0;
    int? quote;
    for (int i = 0; i < runes.length; i++) {
      final int rune = runes[i];
      if (quote != null) {
        if (rune == quote) quote = null;
      } else if (rune == 0x20) {
        start = i + 1;
      } else if (rune == 0x27 || rune == 0x22) {
        quote = rune;
      }
    }
    return start;
  }

  static String _commonPrefix(List<String> values) {
    String prefix = values.first;
    for (final String value in values.skip(1)) {
      final int limit = prefix.length < value.length
          ? prefix.length
          : value.length;
      int length = 0;
      while (length < limit &&
          prefix.codeUnitAt(length) == value.codeUnitAt(length)) {
        length++;
      }
      prefix = prefix.substring(0, length);
      if (prefix.isEmpty) break;
    }
    // Don't end halfway through a character made of two code units.
    if (prefix.isNotEmpty) {
      final int last = prefix.codeUnitAt(prefix.length - 1);
      if (last >= 0xD800 && last <= 0xDBFF) {
        prefix = prefix.substring(0, prefix.length - 1);
      }
    }
    return prefix;
  }

  /// Reads one key from the start of [input], or returns null when [input]
  /// ends partway through an escape sequence.
  static _KeyPress? _parseKey(List<int> input) {
    final int code = input.first;
    if (code == 0x1B) return _parseEscape(input);
    return switch (code) {
      0x0D => const _KeyPress(_Key.enter, 1),
      0x0A => const _KeyPress(_Key.lineFeed, 1),
      0x7F || 0x08 => const _KeyPress(_Key.backspace, 1),
      0x09 => const _KeyPress(_Key.tab, 1),
      0x01 => const _KeyPress(_Key.home, 1),
      0x05 => const _KeyPress(_Key.end, 1),
      0x15 => const _KeyPress(_Key.deleteToStart, 1),
      0x0B => const _KeyPress(_Key.deleteToEnd, 1),
      0x17 => const _KeyPress(_Key.deleteWord, 1),
      0x0C => const _KeyPress(_Key.clearScreen, 1),
      0x03 => const _KeyPress(_Key.cancel, 1),
      0x04 => const _KeyPress(_Key.endOfInput, 1),
      _ when code < 0x20 || (code >= 0x80 && code < 0xA0) => const _KeyPress(
        _Key.ignore,
        1,
      ),
      _ => _KeyPress(_Key.insert, 1, code),
    };
  }

  static _KeyPress? _parseEscape(List<int> input) {
    if (input.length < 2) return null;
    final int kind = input[1];

    // SS3 sequences: ESC O <key>
    if (kind == 0x4F) {
      if (input.length < 3) return null;
      final _Key key = switch (input[2]) {
        0x41 => _Key.up,
        0x42 => _Key.down,
        0x43 => _Key.right,
        0x44 => _Key.left,
        0x48 => _Key.home,
        0x46 => _Key.end,
        _ => _Key.ignore,
      };
      return _KeyPress(key, 3);
    }

    // Alt+key or Escape on its own: drop the escape and keep the key.
    if (kind != 0x5B) return const _KeyPress(_Key.ignore, 1);

    // CSI sequences: ESC [ <parameters> <intermediates> <final byte>
    int index = 2;
    while (index < input.length &&
        input[index] >= 0x30 &&
        input[index] <= 0x3F) {
      index++;
    }
    final int parametersEnd = index;
    while (index < input.length &&
        input[index] >= 0x20 &&
        input[index] <= 0x2F) {
      index++;
    }
    if (index >= input.length) return null;

    final int finalByte = input[index];
    if (finalByte < 0x40 || finalByte > 0x7E) {
      // Not a real sequence: skip what was read and carry on from there.
      return _KeyPress(_Key.ignore, index);
    }

    final String parameters = String.fromCharCodes(input, 2, parametersEnd);
    final _Key key = parametersEnd != index
        ? _Key.ignore
        : switch ((parameters, finalByte)) {
            ('', 0x41) => _Key.up,
            ('', 0x42) => _Key.down,
            ('', 0x43) => _Key.right,
            ('', 0x44) => _Key.left,
            ('', 0x48) => _Key.home,
            ('', 0x46) => _Key.end,
            ('1' || '7', 0x7E) => _Key.home,
            ('4' || '8', 0x7E) => _Key.end,
            ('3', 0x7E) => _Key.delete,
            _ => _Key.ignore,
          };
    return _KeyPress(key, index + 1);
  }
}

enum _Key {
  insert,
  enter,
  lineFeed,
  backspace,
  delete,
  left,
  right,
  home,
  end,
  up,
  down,
  deleteToStart,
  deleteToEnd,
  deleteWord,
  clearScreen,
  cancel,
  endOfInput,
  tab,
  ignore,
}

class _KeyPress {
  const _KeyPress(this.key, this.length, [this.rune = 0]);

  final _Key key;

  /// How many characters of input the key used.
  final int length;

  /// The character to insert, for [_Key.insert].
  final int rune;
}

/// Passes decoded text to a callback as each chunk arrives.
class _TextSink implements Sink<String> {
  _TextSink(this._onText);

  final void Function(String text) _onText;

  @override
  void add(String data) => _onText(data);

  @override
  void close() {}
}
