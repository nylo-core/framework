import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:nylo_framework/helpers/helper.dart';
import 'package:nylo_framework/router/router.dart';
import 'package:sailor/sailor.dart';

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
      List<SailorTransition> transitions,
      Duration transitionDuration,
      Curve transitionCurve,
      Map<String, dynamic> params,
      CustomSailorTransition customTransition,
      Function(dynamic value) onPop}) {
    NyArgument nyArgument = NyArgument(data);
    NyNavigator.instance.router
        .navigate(
          routeName,
          args: nyArgument,
          navigationType: navigationType,
          result: result,
          removeUntilPredicate: removeUntilPredicate,
          transitions: transitions,
          transitionDuration: transitionDuration,
          transitionCurve: transitionCurve,
          params: params,
          customTransition: customTransition,
        )
        .then((v) => onPop != null ? onPop(v) : (v) {});
  }
}
