import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nylo_framework/helpers/helper.dart';
import 'package:nylo_framework/router/router.dart';
import 'package:page_transition/page_transition.dart';

abstract class NyState<T extends StatefulWidget> extends State<T> {
  @override
  void initState() {
    super.initState();
    this.widgetDidLoad();
  }

  void dispose() {
    super.dispose();
  }

  widgetDidLoad() async {}

  pop({dynamic result}) {
    Navigator.of(context).pop(result);
  }

  routeTo(String routeName,
      {dynamic data,
      NavigationType navigationType = NavigationType.push,
      dynamic result,
      bool Function(Route<dynamic> route) removeUntilPredicate,
      Duration transitionDuration,
      PageTransitionType pageTransition,
      Function(dynamic value) onPop}) {
    NyArgument nyArgument = NyArgument(data);
    NyNavigator.instance.router
        .navigate(
          routeName,
          args: nyArgument,
          navigationType: navigationType,
          result: result,
          removeUntilPredicate: removeUntilPredicate,
          pageTransitionType: pageTransition,
        )
        .then((v) => onPop != null ? onPop(v) : (v) {});
  }
}
