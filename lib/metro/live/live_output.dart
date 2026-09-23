import 'dart:convert';
import 'dart:io';

/// How a line of live command output is styled.
enum LiveTone {
  /// Regular text.
  plain,

  /// A completed action, shown with a green check.
  success,

  /// A failed action, shown with a red cross.
  failure,

  /// Something to pay attention to, shown in yellow.
  warning,

  /// Secondary information, shown dimmed.
  note,

  /// A title, shown in bold.
  heading,
}

/// The output produced for one app, printed once the command finishes.
class LiveBlock {
  final List<(LiveTone, String)> _lines = [];

  /// The styled lines in this block.
  List<(LiveTone, String)> get lines => List.unmodifiable(_lines);

  /// Whether nothing has been added.
  bool get isEmpty => _lines.isEmpty;

  /// Adds regular [text].
  void plain(String text) => _add(LiveTone.plain, text);

  /// Adds [text] styled with [tone], without a leading symbol.
  void add(String text, LiveTone tone) => _add(tone, text);

  /// Adds a completed action.
  void success(String text) => _add(LiveTone.success, '✓ $text');

  /// Adds a failed action.
  void failure(String text) => _add(LiveTone.failure, '✗ $text');

  /// Adds a warning.
  void warning(String text) => _add(LiveTone.warning, '! $text');

  /// Adds secondary information.
  void note(String text) => _add(LiveTone.note, '· $text');

  /// Adds a heading.
  void heading(String text) => _add(LiveTone.heading, text);

  /// Adds [value] as indented JSON.
  void json(Object? value) =>
      _add(LiveTone.plain, const JsonEncoder.withIndent('  ').convert(value));

  /// Adds aligned columns with a dimmed header row.
  void table(List<String> headers, List<List<String>> rows) {
    final List<int> widths = [
      for (final String header in headers) header.length,
    ];
    for (final List<String> row in rows) {
      for (int i = 0; i < row.length && i < widths.length; i++) {
        if (row[i].length > widths[i]) widths[i] = row[i].length;
      }
    }
    String render(List<String> cells) {
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < widths.length; i++) {
        final String cell = i < cells.length ? cells[i] : '';
        buffer.write(
          i == widths.length - 1 ? cell : cell.padRight(widths[i] + 2),
        );
      }
      return buffer.toString().trimRight();
    }

    _add(LiveTone.note, render(headers));
    for (final List<String> row in rows) {
      _add(LiveTone.plain, render(row));
    }
  }

  void _add(LiveTone tone, String text) {
    for (final String line in text.split('\n')) {
      _lines.add((tone, line));
    }
  }
}

/// Prints live command output to the terminal.
class LivePrinter {
  /// Creates a [LivePrinter] writing to [sink] (stdout by default), with
  /// colors when [ansi] is true (by default, when the terminal supports them
  /// and `NO_COLOR` isn't set).
  LivePrinter({StringSink? sink, bool? ansi})
    : _sink = sink ?? stdout,
      ansi = ansi ?? _supportsAnsi();

  final StringSink _sink;

  /// Whether ANSI colors are written.
  final bool ansi;

  static bool _supportsAnsi() {
    try {
      return stdout.supportsAnsiEscapes &&
          !Platform.environment.containsKey('NO_COLOR');
    } catch (_) {
      return false;
    }
  }

  /// Writes [text] as a single line styled with [tone].
  void line(String text, [LiveTone tone = LiveTone.plain]) =>
      _sink.writeln(_style(tone, text));

  /// Writes a completed action.
  void success(String text) => line('✓ $text', LiveTone.success);

  /// Writes an error.
  void error(String text) => line('✗ $text', LiveTone.failure);

  /// Writes a warning.
  void warning(String text) => line('! $text', LiveTone.warning);

  /// Writes secondary information.
  void note(String text) => line('· $text', LiveTone.note);

  /// Writes [value] as indented JSON.
  void json(Object? value) =>
      _sink.writeln(const JsonEncoder.withIndent('  ').convert(value));

  /// Writes a [block], prefixing each line with [prefix] when given.
  void block(LiveBlock block, {String? prefix}) {
    for (final (LiveTone tone, String text) in block.lines) {
      final String styled = _style(tone, text);
      _sink.writeln(
        prefix == null ? styled : '${_style(LiveTone.heading, prefix)}$styled',
      );
    }
  }

  /// Writes each labelled block, adding `[device]` prefixes when there is
  /// more than one.
  void blocks(List<({String label, LiveBlock block})> blocks) {
    if (blocks.length == 1) {
      block(blocks.single.block);
      return;
    }
    final int width = blocks
        .map((entry) => entry.label.length)
        .fold(0, (a, b) => a > b ? a : b);
    for (final ({String label, LiveBlock block}) entry in blocks) {
      block(entry.block, prefix: '[${entry.label}]'.padRight(width + 4));
    }
  }

  String _style(LiveTone tone, String text) {
    if (!ansi || text.isEmpty) return text;
    return switch (tone) {
      LiveTone.plain => text,
      LiveTone.success => '\x1B[92m$text\x1B[0m',
      LiveTone.failure => '\x1B[91m$text\x1B[0m',
      LiveTone.warning => '\x1B[93m$text\x1B[0m',
      LiveTone.note => '\x1B[90m$text\x1B[0m',
      LiveTone.heading => '\x1B[1m$text\x1B[0m',
    };
  }
}

/// Formatting helpers shared by the live commands.
class LiveFormat {
  /// A compact single-line rendering of [value]: strings as-is, everything
  /// else as JSON, cut to [max] characters.
  static String value(Object? value, {int max = 60}) {
    final String text = value is String ? value : jsonEncode(value);
    final String singleLine = text.replaceAll('\n', ' ');
    if (max <= 1 || singleLine.length <= max) return singleLine;
    return '${singleLine.substring(0, max - 1)}…';
  }

  /// `HH:mm:ss` for [time] in local time.
  static String clock(DateTime time) {
    final DateTime local = time.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
