import 'package:flutter/widgets.dart';

class NetworkUrl {
  String environment;
  String url;
  String tag;

  NetworkUrl({@required this.environment, @required this.url, this.tag = ""});
}