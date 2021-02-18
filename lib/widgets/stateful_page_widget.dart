import 'package:flutter/cupertino.dart';
import 'package:nylo_framework/controllers/controller.dart';

/// StatefulPageWidget's include a [BaseController] to access from your child state.
abstract class StatefulPageWidget extends StatefulWidget {
  final BaseController controller;

  StatefulPageWidget({Key key, this.controller}) : super(key: key);

  StatefulElement createElement() => StatefulElement(this);

  @override
  State<StatefulWidget> createState() {
    throw UnimplementedError();
  }

  dynamic data() => this.controller.request.data();
}
