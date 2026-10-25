import 'dart:io';

import 'package:recase/recase.dart';

/// Where a Nylo project adds its routes.
const String routerPath = 'lib/routes/router.dart';

/// A page the app's router adds, for a playbook to visit.
class PlaybookRoute {
  /// Creates a [PlaybookRoute] for the page class [page], imported from
  /// [import].
  const PlaybookRoute({
    required this.page,
    required this.import,
    this.guarded = false,
    this.path,
  });

  /// The page class, e.g. `HomePage`.
  final String page;

  /// How a file in the project imports the page, e.g.
  /// `/resources/pages/home_page.dart`.
  final String import;

  /// Whether a route guard, or `authenticatedRoute()`, stands in front of
  /// the page.
  final bool guarded;

  /// The page's route path, e.g. `/profile/{userId}`, when its file says.
  final String? path;

  /// The parameters in [path], e.g. `userId`.
  List<String> get parameters => [
    if (path != null)
      for (final RegExpMatch match in RegExp(r'\{([^}]+)\}').allMatches(path!))
        match.group(1)!.replaceAll('?', ''),
  ];

  /// The screenshot name: the page without `Page`, in snake case, e.g.
  /// `one_of_demo` for `OneOfDemoPage`.
  String get name => ReCase(
    page.endsWith('Page') && page.length > 'Page'.length
        ? page.substring(0, page.length - 'Page'.length)
        : page,
  ).snakeCase;
}

/// The pages the router in [projectRoot] adds, in the order it adds them,
/// reading each page's file for its route path. Empty when there's no router.
List<PlaybookRoute> readPlaybookRoutes({String projectRoot = '.'}) {
  final File router = File('$projectRoot/$routerPath');
  if (!router.existsSync()) return const [];
  return playbookRoutesIn(
    router.readAsStringSync(),
    readPage: (String import) {
      final String? relative = import.startsWith('/')
          ? import.substring(1)
          : import.startsWith('package:') && import.contains('/')
          ? import.substring(import.indexOf('/') + 1)
          : null;
      if (relative == null) return null;
      final File page = File('$projectRoot/lib/$relative');
      return page.existsSync() ? page.readAsStringSync() : null;
    },
  );
}

/// The pages the [router] source adds with `router.add(SomePage.path ...)`,
/// in order, once each.
///
/// The page shown for unknown routes is left out. [readPage] reads a page's
/// file from its import, for its route path.
List<PlaybookRoute> playbookRoutesIn(
  String router, {
  String? Function(String import)? readPage,
}) {
  final String code = withoutComments(router);
  final List<String> imports = [
    for (final RegExpMatch match in RegExp(
      r'''import\s+['"]([^'"]+)['"]''',
    ).allMatches(code))
      match.group(1)!,
  ];

  // Groups with route guards guard every route inside them.
  final List<(int, int)> guardedGroups = [
    for (final RegExpMatch match in RegExp(r'\.group\s*\(').allMatches(code))
      if (_enclosed(code, match.end - 1) case final int end
          when code.substring(match.start, end).contains('route_guards'))
        (match.start, end),
  ];

  final List<PlaybookRoute> routes = [];
  for (final RegExpMatch match in RegExp(
    r'\.add\s*\(\s*([A-Z][A-Za-z0-9_]*)\s*\.\s*path\b',
  ).allMatches(code)) {
    final String page = match.group(1)!;
    if (routes.any((PlaybookRoute route) => route.page == page)) continue;
    final String statement = code.substring(
      match.start,
      _statementEnd(code, match.start),
    );
    if (statement.contains('unknownRoute')) continue;

    final String file = '${ReCase(page).snakeCase}.dart';
    final String import = imports.firstWhere(
      (String path) =>
          (path.startsWith('/') || path.startsWith('package:')) &&
          path.endsWith('/$file'),
      orElse: () => '/resources/pages/$file',
    );
    final String? source = readPage?.call(import);
    routes.add(
      PlaybookRoute(
        page: page,
        import: import,
        guarded:
            RegExp(
              r'authenticatedRoute|routeGuards|addRouteGuard',
            ).hasMatch(statement) ||
            guardedGroups.any(
              ((int, int) group) =>
                  match.start > group.$1 && match.start < group.$2,
            ),
        path: source == null
            ? null
            : RegExp(
                r'''\bpath\s*=\s*\(\s*['"]([^'"]*)['"]''',
              ).firstMatch(withoutComments(source))?.group(1),
      ),
    );
  }
  return routes;
}

/// [code] with its comments blanked out, keeping strings as they are and
/// every character where it was.
String withoutComments(String code) {
  final StringBuffer out = StringBuffer();
  String? quote;
  int i = 0;
  while (i < code.length) {
    final String char = code[i];
    if (quote != null) {
      out.write(char);
      if (char == r'\' && i + 1 < code.length) {
        out.write(code[++i]);
      } else if (char == quote) {
        quote = null;
      }
      i++;
    } else if (char == "'" || char == '"') {
      quote = char;
      out.write(char);
      i++;
    } else if (code.startsWith('//', i)) {
      while (i < code.length && code[i] != '\n') {
        out.write(' ');
        i++;
      }
    } else if (code.startsWith('/*', i)) {
      final int close = code.indexOf('*/', i + 2);
      final int end = close < 0 ? code.length : close + 2;
      out.write(code.substring(i, end).replaceAll(RegExp(r'[^\n]'), ' '));
      i = end;
    } else {
      out.write(char);
      i++;
    }
  }
  return out.toString();
}

/// Where the bracket at [open] in [code] is closed, just past it, or null
/// when it isn't.
int? _enclosed(String code, int open) {
  int depth = 0;
  for (int i = open; i < code.length; i++) {
    switch (code[i]) {
      case '(' || '[' || '{':
        depth++;
      case ')' || ']' || '}':
        if (--depth == 0) return i + 1;
    }
  }
  return null;
}

/// Where the statement starting at [start] in [code] ends: its `;`, or the
/// end of the block it's in.
int _statementEnd(String code, int start) {
  int depth = 0;
  for (int i = start; i < code.length; i++) {
    switch (code[i]) {
      case '(' || '[' || '{':
        depth++;
      case ')' || ']' || '}':
        if (--depth < 0) return i;
      case ';' when depth == 0:
        return i;
    }
  }
  return code.length;
}
