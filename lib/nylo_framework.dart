library nylo_framework;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nylo_framework/controllers/controller.dart';
import 'package:nylo_framework/helpers/helper.dart';
import 'package:nylo_framework/theme/helper/theme_helper.dart';
import 'package:queue/queue.dart';

/// Run to init classes used in Nylo
Future initNylo({@required ThemeData theme}) async {
  await DotEnv().load('.env');
  if (theme != null) {
    CurrentTheme.instance.theme = theme;
  }
  BusQueue.instance.queue = Queue(
    delay: Duration(milliseconds: getEnv("QUEUE_DELAY", defaultValue: 10)),
    parallel: getEnv("QUEUE_PARALLEL", defaultValue: 1),
  );
}
