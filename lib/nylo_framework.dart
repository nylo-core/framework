/// The Nylo Framework - a micro-framework for Flutter.
///
/// Provides tools for building Flutter applications including routing,
/// networking, themes, storage, CLI scaffolding, and more.
library nylo_framework;

// Nylo Core
export 'package:nylo_support/ny_core.dart';

// Flutter's painting API (Locale, Color, TextStyle, EdgeInsets...). Apps got
// it through skeletonizer 2, which exported it, and use it with only this
// import; skeletonizer 3 doesn't, so it's exported here instead.
export 'package:flutter/painting.dart';

// Packages
export 'package:error_stack/error_stack.dart';
export 'package:skeletonizer/skeletonizer.dart';
export 'package:flutter_local_notifications/flutter_local_notifications.dart';
export 'package:date_field/date_field.dart';
export 'package:dio/dio.dart';

/// Nylo version
const String nyloVersion = 'v7.2.2';
