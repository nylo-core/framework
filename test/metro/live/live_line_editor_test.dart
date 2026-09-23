import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_line_editor.dart';

const String enter = '\r';
const String up = '\x1B[A';
const String down = '\x1B[B';
const String left = '\x1B[D';
const String right = '\x1B[C';
const String home = '\x1B[H';
const String end = '\x1B[F';
const String deleteKey = '\x1B[3~';
const String backspace = '\x7F';
const String tab = '\t';

class FakeTerminal implements LiveTerminal {
  FakeTerminal({
    this.hasTerminal = true,
    this.supportsAnsi = true,
    this.columns = 80,
  });

  @override
  final bool hasTerminal;

  @override
  final bool supportsAnsi;

  @override
  final int columns;

  final List<String> calls = [];

  @override
  void enableRawMode() => calls.add('raw');

  @override
  void restoreMode() => calls.add('restore');
}

class Harness {
  Harness({
    FakeTerminal? terminal,
    List<String> history = const [],
    int historyLimit = 500,
    LiveCompleter? complete,
  }) : terminal = terminal ?? FakeTerminal() {
    editor = LiveLineEditor(
      input: input.stream,
      output: output,
      terminal: this.terminal,
      history: history,
      historyLimit: historyLimit,
      complete: complete,
    );
  }

  final StreamController<List<int>> input = StreamController<List<int>>();
  final StringBuffer output = StringBuffer();
  final FakeTerminal terminal;
  late final LiveLineEditor editor;

  /// Sends [text] as one chunk of input.
  void type(String text) => input.add(utf8.encode(text));

  /// Reads a line after typing [keys].
  Future<String?> line(String keys, {String prompt = '› '}) {
    final Future<String?> result = editor.readLine(prompt);
    type(keys);
    return result;
  }
}

/// Lets pending input and completions run.
Future<void> pump([int times = 20]) async {
  for (int i = 0; i < times; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('typing', () {
    test('returns the line when Enter is pressed', () async {
      final Harness h = Harness();

      expect(await h.line('status$enter'), 'status');
      expect(h.output.toString(), '› status\n');
      expect(h.editor.isReading, isFalse);
    });

    test('a line feed submits, and \\r\\n counts as one Enter', () async {
      final Harness h = Harness();

      final Future<String?> first = h.editor.readLine('› ');
      h.type('a\r\nb\n');

      expect(await first, 'a');
      expect(await h.editor.readLine('› '), 'b');
    });

    test('edits in the middle of the line', () async {
      final Harness h = Harness();

      expect(await h.line('hllo$home${right}e$end world$enter'), 'hello world');
    });

    test('Backspace and Delete remove characters', () async {
      final Harness h = Harness();

      expect(
        await h.line('abcx${backspace}d$left$left$deleteKey$enter'),
        'abd',
      );
    });

    test('supports other Home and End keys', () async {
      final Harness h = Harness();

      expect(
        await h.line('bc\x01a\x05d\x1BOH>\x1BOF<\x1B[1~[\x1B[4~]$enter'),
        '[>abcd<]',
      );
    });

    test('redraws and moves the cursor back when editing mid-line', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('abc$left');
      await pump();

      expect(h.output.toString(), endsWith('\r› abc\x1B[K\x1B[1D'));
      h.type(enter);
      expect(await result, 'abc');
    });
  });

  group('history', () {
    test('Up and Down step through history and bring back the unfinished '
        'line', () async {
      final Harness h = Harness(history: ['status', 'routes']);

      final Future<String?> result = h.editor.readLine('› ');
      h.type('dra$up');
      await pump();
      expect(h.output.toString(), endsWith('\r› routes\x1B[K'));

      h.type('$up$up$down');
      await pump();
      expect(h.output.toString(), endsWith('\r› routes\x1B[K'));

      h.type('${down}ft$enter');
      expect(await result, 'draft');
    });

    test('runs an earlier line again', () async {
      final Harness h = Harness(history: ['status', 'routes']);

      expect(await h.line('$up$up$enter'), 'status');
      expect(h.editor.history, ['status', 'routes', 'status']);
    });

    test('skips blank lines and repeats, and keeps the newest lines', () async {
      final Harness h = Harness(historyLimit: 2);

      for (final String line in ['a', 'a', '   ', 'b', 'c']) {
        expect(await h.line('$line$enter'), line);
      }

      expect(h.editor.history, ['b', 'c']);
    });

    test('keeps its own copy of the history it was given', () async {
      final List<String> seeded = ['status'];
      final Harness h = Harness(history: seeded);

      await h.line('routes$enter');

      expect(seeded, ['status']);
      expect(h.editor.history, ['status', 'routes']);
    });
  });

  group('control keys', () {
    test('Ctrl+D on an empty line returns null', () async {
      final Harness h = Harness();

      expect(await h.line('\x04'), isNull);
      expect(h.terminal.calls, ['raw', 'restore']);
    });

    test('Ctrl+D deletes the character under the cursor', () async {
      final Harness h = Harness();

      expect(await h.line('abc$home\x04$enter'), 'bc');
    });

    test('Ctrl+W, Ctrl+K and Ctrl+U delete the previous word, to the end, '
        'and to the start', () async {
      final Harness h = Harness();

      expect(await h.line('hello world\x17$enter'), 'hello ');
      expect(
        await h.line('hello world$left$left$left$left$left$left\x0B$enter'),
        'hello',
      );
      expect(
        await h.line('hello world$left$left$left$left$left\x15$enter'),
        'world',
      );
    });

    test('Ctrl+L clears the screen and redraws the line', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('abc\x0C');
      await pump();

      expect(h.output.toString(), endsWith('\x1B[2J\x1B[H\r› abc\x1B[K'));
      h.type(enter);
      expect(await result, 'abc');
    });

    test('a Ctrl+C byte cancels the line', () async {
      final Harness h = Harness();

      expect(await h.line('abc\x03def$enter'), 'def');
      expect(h.output.toString(), contains('abc^C\n› def'));
    });

    test('ignores other control characters', () async {
      final Harness h = Harness();

      expect(await h.line('a\x02\x07\x1Fb$enter'), 'ab');
    });
  });

  group('input', () {
    test('returns null when input ends, and after that', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      await h.input.close();

      expect(await result, isNull);
      expect(await h.editor.readLine('› '), isNull);
    });

    test('returns a partly typed line when input ends', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('abc');
      await h.input.close();

      expect(await result, 'abc');
    });

    test('decodes UTF-8 split across chunks', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.input.add([0xC3]);
      h.input.add([0xA9]);
      h.type('a');
      h.input.add([0xF0, 0x9F]);
      h.input.add([0x99, 0x82]);
      h.type('${backspace}b$enter');

      expect(await result, 'éab');
    });

    test('handles an escape sequence split across chunks', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('ac');
      h.type('\x1B');
      h.type('[');
      h.type('D');
      h.type('b$enter');

      expect(await result, 'abc');
    });

    test('ignores unknown escape sequences and a lone Escape', () async {
      final Harness h = Harness();

      expect(await h.line('a\x1B[1;5Cb\x1B[99~c\x1Bxd$enter'), 'abcxd');
    });

    test('finishes a line when input ends inside an escape sequence', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('ab\x1B[');
      await h.input.close();

      expect(await result, 'ab');
    });
  });

  group('Tab completion', () {
    Future<List<String>> commands(String line) async {
      final String word = line.split(' ').last;
      return [
        'status',
        'storage',
        'storage:get',
        'storage:set',
      ].where((candidate) => candidate.startsWith(word)).toList();
    }

    test('completes a single candidate and adds a space', () async {
      final List<String> asked = [];
      final Harness h = Harness(
        complete: (line) async {
          asked.add(line);
          return commands(line);
        },
      );

      expect(await h.line('stat$tab$enter'), 'status ');
      expect(asked, ['stat']);
    });

    test('adds no space after /, = or :', () async {
      final Harness h = Harness(
        complete: (line) async => line.endsWith('/pro')
            ? ['/profile/']
            : line.endsWith('--data')
            ? ['--data=']
            : ['app:'],
      );

      expect(await h.line('route /pro$tab$enter'), 'route /profile/');
      expect(await h.line('route --data$tab$enter'), 'route --data=');
      expect(await h.line('ap$tab$enter'), 'app:');
    });

    test(
      'extends to the longest common prefix, then lists the candidates',
      () async {
        final Harness h = Harness(complete: commands);

        final Future<String?> result = h.editor.readLine('› ');
        h.type('stor$tab');
        await pump();
        expect(h.output.toString(), endsWith('\r› storage\x1B[K'));
        expect(h.output.toString(), isNot(contains('storage:get')));

        h.type(tab);
        await pump();
        expect(
          h.output.toString(),
          contains(
            '\r\x1B[Kstorage      storage:get  storage:set\n\r› storage\x1B[K',
          ),
        );

        h.type(':g$tab$enter');
        expect(await result, 'storage:get ');
      },
    );

    test('completes the word after the last unquoted space', () async {
      final List<String> asked = [];
      final Harness h = Harness(
        complete: (line) async {
          asked.add(line);
          return ['"17 Pro"'];
        },
      );

      expect(await h.line('use "17 Pr$tab$enter'), 'use "17 Pro" ');
      expect(asked, ['use "17 Pr']);
    });

    test('keeps the text after the cursor', () async {
      final Harness h = Harness(complete: commands);

      expect(
        await h.line('stat--json$left$left$left$left$left$left$tab$enter'),
        'status --json',
      );
    });

    test('queues keys typed while completions load', () async {
      final Completer<List<String>> loading = Completer<List<String>>();
      final Harness h = Harness(complete: (line) => loading.future);

      final Future<String?> result = h.editor.readLine('› ');
      h.type('sta${tab}x$enter');
      await pump();
      expect(h.editor.isReading, isTrue);

      loading.complete(['status']);
      expect(await result, 'status x');
    });

    test('lists at most 100 candidates', () async {
      final Harness h = Harness(
        complete: (line) async => [
          for (int i = 0; i < 75; i++) 'a${i.toString().padLeft(3, '0')}',
          for (int i = 0; i < 75; i++) 'b${i.toString().padLeft(3, '0')}',
        ],
      );

      final Future<String?> result = h.editor.readLine('› ');
      h.type(tab);
      await pump();

      final String output = h.output.toString();
      expect(output, contains('a000  a001'));
      expect(output, contains('b024'));
      expect(output, isNot(contains('b025')));
      expect(output, contains('…and 50 more'));

      h.type(enter);
      expect(await result, '');
    });

    test('fits the candidate list to the terminal width', () async {
      final Harness h = Harness(
        terminal: FakeTerminal(columns: 20),
        complete: (line) async => ['alpha', 'bravo', 'charlie', 'delta'],
      );

      final Future<String?> result = h.editor.readLine('› ');
      h.type(tab);
      await pump();

      expect(h.output.toString(), contains('alpha    bravo\ncharlie  delta\n'));
      h.type(enter);
      await result;
    });

    test('rings the bell and changes nothing without candidates', () async {
      final Harness h = Harness(complete: (line) async => []);

      expect(await h.line('ab${tab}c$enter'), 'abc');
      expect(h.output.toString(), contains('\x07'));
    });

    test('a failing completer leaves the line alone', () async {
      final Harness h = Harness(
        complete: (line) async => throw StateError('no app'),
      );

      expect(await h.line('ab${tab}c$enter'), 'abc');
    });

    test('Tab does nothing without a completer', () async {
      final Harness h = Harness();

      expect(await h.line('ab${tab}c$enter'), 'abc');
    });
  });

  group('prompt and output', () {
    test('printAbove keeps what has been typed', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('abc');
      await pump();
      h.editor.printAbove('· Pixel 9 hot restarted');
      h.type('d$enter');

      expect(await result, 'abcd');
      expect(
        h.output.toString(),
        contains('\r\x1B[K· Pixel 9 hot restarted\n\r› abc\x1B[K'),
      );
    });

    test('printAbove prints a plain line when nothing is being read', () {
      final Harness h = Harness();

      h.editor.printAbove('hello');

      expect(h.output.toString(), 'hello\n');
    });

    test('updatePrompt redraws the line with the new prompt', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('iPhone /home › ');
      h.type('status');
      await pump();
      h.editor.updatePrompt('iPhone /profile › ');
      h.type(enter);

      expect(await result, 'status');
      expect(h.output.toString(), contains('\riPhone /profile › status\x1B[K'));
    });

    test('cancelLine discards the line and shows a fresh prompt', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('abc');
      await pump();
      h.editor.cancelLine();
      h.type('def$enter');

      expect(await result, 'def');
      expect(h.output.toString(), '› abc^C\n› def\n');
    });

    test('cancelLine does nothing when no line is being read', () {
      final Harness h = Harness();

      h.editor.cancelLine();

      expect(h.output.toString(), isEmpty);
    });

    test('raw mode is on only while a line is read', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      h.type('a');
      await pump();
      expect(h.terminal.calls, ['raw']);

      h.type(enter);
      await result;
      expect(h.terminal.calls, ['raw', 'restore']);
    });

    test('close ends a pending read and restores the terminal', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');
      await h.editor.close();
      await h.editor.close();

      expect(await result, isNull);
      expect(h.terminal.calls, ['raw', 'restore']);
      expect(await h.editor.readLine('› '), isNull);
    });

    test('reading two lines at once is an error', () async {
      final Harness h = Harness();

      final Future<String?> result = h.editor.readLine('› ');

      expect(() => h.editor.readLine('› '), throwsStateError);
      h.type(enter);
      expect(await result, '');
    });

    test('a terminal without ANSI support gets no escape codes', () async {
      final Harness h = Harness(
        terminal: FakeTerminal(supportsAnsi: false),
        complete: (line) async => ['status', 'storage'],
      );

      final Future<String?> result = h.editor.readLine('\x1B[1m› \x1B[0m');
      h.type('abc${left}X$backspace\x0C$tab$enter');

      expect(await result, 'abc');
      final String output = h.output.toString();
      expect(output, isNot(contains('\x1B')));
      expect(output, startsWith('› abc\n› abXc\n› abc'));
      expect(output, contains('\nstatus   storage\n› abc'));
    });
  });

  group('input that is not a terminal', () {
    test('reads plain lines without editing or raw mode', () async {
      final Harness h = Harness(terminal: FakeTerminal(hasTerminal: false));

      h.type('one\r\ntwo\n');
      h.type('thr');
      h.type('ee');
      // Nothing listens until the first readLine, so don't wait for close.
      unawaited(h.input.close());

      expect(await h.editor.readLine('› '), 'one');
      expect(await h.editor.readLine('› '), 'two');
      expect(await h.editor.readLine('› '), 'three');
      expect(await h.editor.readLine('› '), isNull);
      expect(h.terminal.calls, isEmpty);
      expect(h.output.toString(), '› › › › ');
    });

    test('keeps keys that would edit a terminal line', () async {
      final Harness h = Harness(
        terminal: FakeTerminal(hasTerminal: false),
        complete: (line) async => ['status'],
      );

      expect(await h.line('a${tab}b\x1B[D\n'), 'a\tb\x1B[D');
    });

    test('printAbove prints a plain line while reading', () async {
      final Harness h = Harness(terminal: FakeTerminal(hasTerminal: false));

      final Future<String?> result = h.editor.readLine('');
      h.editor.printAbove('· done');
      h.type('next\n');

      expect(await result, 'next');
      expect(h.output.toString(), '· done\n');
    });
  });
}
