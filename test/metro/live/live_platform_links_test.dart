import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nylo_framework/metro/live/live_platform_links.dart';

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('nylo_links_'));
  tearDown(() => project.deleteSync(recursive: true));

  void write(String path, String contents) => File('${project.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  PlatformLinks read() => PlatformLinks.read(project.path);

  test('reads custom schemes out of Info.plist', () {
    write('ios/Runner/Info.plist', '''
<plist><dict>
  <key>CFBundleName</key><string>Runner</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>shop</string>
      <key>CFBundleURLSchemes</key>
      <array><string>myapp</string><string>myapp-dev</string></array>
    </dict>
  </array>
</dict></plist>''');

    expect(read().iosSchemes, ['myapp', 'myapp-dev']);
    expect(read().iosFound, isTrue);
    // CFBundleName is a <string> too, and must not be mistaken for a scheme.
    expect(read().iosSchemes, isNot(contains('Runner')));
  });

  test('reads universal link domains out of the entitlements', () {
    write('ios/Runner/Runner.entitlements', '''
<plist><dict>
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:shop.example.com</string>
    <string>webcredentials:shop.example.com</string>
  </array>
</dict></plist>''');

    expect(read().iosDomains, ['shop.example.com']);
  });

  test('reads schemes and hosts out of AndroidManifest', () {
    write('android/app/src/main/AndroidManifest.xml', '''
<manifest>
  <application>
    <activity>
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" android:host="shop.example.com" />
      </intent-filter>
      <intent-filter>
        <data android:scheme="myapp" />
        <data android:host="\${applicationId}" />
      </intent-filter>
    </activity>
  </application>
</manifest>''');

    final PlatformLinks links = read();
    expect(links.androidSchemes, ['https', 'myapp']);
    expect(links.androidHosts, ['shop.example.com']);
    expect(links.androidFound, isTrue);
  });

  test('accepts a declared scheme, and http either way', () {
    write('ios/Runner/Info.plist', '''
<plist><dict><key>CFBundleURLTypes</key><array><dict>
  <key>CFBundleURLSchemes</key><array><string>myapp</string></array>
</dict></array></dict></plist>''');

    final PlatformLinks links = read();
    expect(links.accepts('myapp'), isTrue);
    expect(links.accepts('https'), isTrue, reason: 'association, not a scheme');
    expect(links.accepts('http'), isTrue);
    expect(links.accepts('other'), isFalse);
  });

  test('says nothing about a platform that is not there', () {
    final PlatformLinks links = read();

    expect(links.isEmpty, isTrue);
    expect(links.iosFound, isFalse);
    expect(links.androidFound, isFalse);
    expect(links.schemes, isEmpty);
    // Nothing declared means nothing to contradict, so nothing is refused.
    expect(links.toJson(), {
      'ios': {'found': false, 'schemes': <String>[], 'domains': <String>[]},
      'android': {'found': false, 'schemes': <String>[], 'hosts': <String>[]},
    });
  });
}
