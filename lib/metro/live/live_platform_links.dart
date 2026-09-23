import 'dart:io';

/// What a project's iOS and Android config says about incoming links.
///
/// Read from the files on disk, not from the running app: the platform half
/// of a deep link is decided at build time, and `metro live:run deeplink`
/// can't reach it any other way.
class PlatformLinks {
  /// Creates a [PlatformLinks].
  const PlatformLinks({
    this.iosSchemes = const [],
    this.iosDomains = const [],
    this.androidSchemes = const [],
    this.androidHosts = const [],
    this.iosFound = false,
    this.androidFound = false,
  });

  /// Custom URL schemes from `CFBundleURLTypes` in `Info.plist`.
  final List<String> iosSchemes;

  /// Universal Link domains from the `applinks:` entitlements.
  final List<String> iosDomains;

  /// Schemes from the `VIEW` intent filters in `AndroidManifest.xml`.
  final List<String> androidSchemes;

  /// Hosts from the same intent filters, for App Links.
  final List<String> androidHosts;

  /// Whether `Info.plist` was there to read.
  final bool iosFound;

  /// Whether `AndroidManifest.xml` was there to read.
  final bool androidFound;

  /// Whether either platform declares anything at all.
  bool get isEmpty =>
      iosSchemes.isEmpty &&
      iosDomains.isEmpty &&
      androidSchemes.isEmpty &&
      androidHosts.isEmpty;

  /// Every scheme either platform accepts, without duplicates.
  List<String> get schemes =>
      <String>{...iosSchemes, ...androidSchemes}.toList()..sort();

  /// Whether [uri]'s scheme is declared by either platform.
  ///
  /// `http` and `https` always count: they reach the app through an
  /// association file rather than a declared scheme.
  bool accepts(String scheme) =>
      scheme == 'http' || scheme == 'https' || schemes.contains(scheme);

  /// The `--json` representation.
  Map<String, Object?> toJson() => {
    'ios': {'found': iosFound, 'schemes': iosSchemes, 'domains': iosDomains},
    'android': {
      'found': androidFound,
      'schemes': androidSchemes,
      'hosts': androidHosts,
    },
  };

  /// Reads the iOS and Android config of the project at [root].
  ///
  /// Anything unreadable is left out rather than reported as empty, so a
  /// project without one platform doesn't look misconfigured.
  static PlatformLinks read(String root) {
    final String? plist = _read('$root/ios/Runner/Info.plist');
    final List<String> domains = [];
    for (final String path in const [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/RunnerDebug.entitlements',
    ]) {
      final String? entitlements = _read('$root/$path');
      if (entitlements == null) continue;
      for (final String value in _plistStrings(entitlements)) {
        if (value.startsWith('applinks:')) {
          domains.add(value.substring('applinks:'.length));
        }
      }
    }

    final String? manifest = _read(
      '$root/android/app/src/main/AndroidManifest.xml',
    );
    return PlatformLinks(
      iosFound: plist != null,
      iosSchemes: plist == null ? const [] : _urlSchemes(plist),
      iosDomains: _unique(domains),
      androidFound: manifest != null,
      androidSchemes: manifest == null
          ? const []
          : _attributes(manifest, 'scheme'),
      androidHosts: manifest == null ? const [] : _attributes(manifest, 'host'),
    );
  }

  static String? _read(String path) {
    try {
      final File file = File(path);
      return file.existsSync() ? file.readAsStringSync() : null;
    } on FileSystemException {
      return null;
    }
  }

  /// The schemes under every `CFBundleURLSchemes` array in a plist.
  static List<String> _urlSchemes(String plist) {
    final List<String> found = [];
    final RegExp key = RegExp(
      r'<key>\s*CFBundleURLSchemes\s*</key>\s*<array>(.*?)</array>',
      dotAll: true,
    );
    for (final RegExpMatch match in key.allMatches(plist)) {
      found.addAll(_plistStrings(match.group(1)!));
    }
    return _unique(found);
  }

  static List<String> _plistStrings(String xml) => [
    for (final RegExpMatch match in RegExp(
      r'<string>(.*?)</string>',
      dotAll: true,
    ).allMatches(xml))
      match.group(1)!.trim(),
  ];

  /// The `android:<name>` values inside the manifest's `<data>` tags.
  static List<String> _attributes(String manifest, String name) {
    final List<String> found = [];
    for (final RegExpMatch tag in RegExp(
      r'<data\s[^>]*>',
      dotAll: true,
    ).allMatches(manifest)) {
      final RegExpMatch? value = RegExp(
        'android:$name\\s*=\\s*"([^"]*)"',
      ).firstMatch(tag.group(0)!);
      // A manifest placeholder like ${applicationId} says nothing useful.
      if (value != null && !value.group(1)!.contains(r'${')) {
        found.add(value.group(1)!);
      }
    }
    return _unique(found);
  }

  static List<String> _unique(List<String> values) {
    final List<String> unique = <String>{
      for (final String value in values)
        if (value.isNotEmpty) value,
    }.toList();
    return unique..sort();
  }
}
