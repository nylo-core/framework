/// Nylo Playbooks: scripted walkthroughs your app performs on itself.
///
/// Import this in playbooks (`lib/app/playbooks/`) and in
/// `lib/bootstrap/playbooks.dart`. While the app runs in debug mode,
/// `metro live:run playbook <name>` (or `playbook <name>` inside
/// `metro live`) plays one, and `Playbook.run()` plays it from Dart or a test.
library;

export 'package:nylo_support/playbook/ny_playbook.dart';
