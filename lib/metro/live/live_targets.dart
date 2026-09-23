/// The apps a live command should run on, or why none were picked.
class LiveTargetSelection<T> {
  /// A successful selection of [targets].
  const LiveTargetSelection.targets(this.targets)
    : error = null,
      exitCode = 0,
      candidates = const [];

  /// A failed selection with an [error] message and [exitCode]. [candidates]
  /// lists the apps worth showing alongside the message.
  const LiveTargetSelection.error(
    this.error,
    this.exitCode, {
    this.candidates = const [],
  }) : targets = const [];

  /// The apps to run the command on.
  final List<T> targets;

  /// Why no apps were selected, or null on success.
  final String? error;

  /// `0` on success, `1` when nothing matched, `2` when the choice is
  /// ambiguous.
  final int exitCode;

  /// Apps to list with the [error] so the user can pick one.
  final List<T> candidates;

  /// Whether targets were selected.
  bool get isSuccess => error == null;
}

/// Picks the apps a live command runs on.
///
/// Precedence: [all] runs on every app; [device] matches a 1-based index from
/// `metro live:devices` or a case-insensitive device name (an exact name
/// wins over partial matches); otherwise the only running app is used.
/// Metro never guesses: several apps and no target, or a name matching more
/// than one app, is an error with exit code 2.
LiveTargetSelection<T> selectLiveTargets<T>(
  List<T> apps, {
  required String Function(T app) deviceOf,
  String? device,
  bool all = false,
  String packageName = 'Nylo',
}) {
  if (apps.isEmpty) {
    return LiveTargetSelection<T>.error(
      'No running $packageName app found. Start it with `flutter run` '
      '(a debug build) and try again.',
      1,
    );
  }

  if (all) return LiveTargetSelection<T>.targets(apps);

  final String? wanted = device?.trim();
  if (wanted != null && wanted.isNotEmpty) {
    final int? index = int.tryParse(wanted);
    if (index != null) {
      if (index < 1 || index > apps.length) {
        return LiveTargetSelection<T>.error(
          'There is no app #$index. ${apps.length} '
          '${apps.length == 1 ? 'app is' : 'apps are'} running:',
          1,
          candidates: apps,
        );
      }
      return LiveTargetSelection<T>.targets([apps[index - 1]]);
    }

    final String needle = wanted.toLowerCase();
    final List<T> exact = apps
        .where((app) => deviceOf(app).toLowerCase() == needle)
        .toList();
    if (exact.length == 1) return LiveTargetSelection<T>.targets(exact);

    final List<T> matches = exact.isNotEmpty
        ? exact
        : apps
              .where((app) => deviceOf(app).toLowerCase().contains(needle))
              .toList();
    if (matches.isEmpty) {
      return LiveTargetSelection<T>.error(
        'No running app matches "$wanted". Running apps:',
        1,
        candidates: apps,
      );
    }
    if (matches.length > 1) {
      return LiveTargetSelection<T>.error(
        '"$wanted" matches ${matches.length} apps. Pass -d <#> or --all:',
        2,
        candidates: matches,
      );
    }
    return LiveTargetSelection<T>.targets(matches);
  }

  if (apps.length == 1) return LiveTargetSelection<T>.targets(apps);

  return LiveTargetSelection<T>.error(
    '${apps.length} apps are running. Pass -d <#|name> or --all:',
    2,
    candidates: apps,
  );
}
