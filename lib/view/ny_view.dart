
import 'package:flutter/cupertino.dart';

typedef ViewCallback = Widget Function(BuildContext context, dynamic data);

Builder view(ViewCallback build, {validator}) {
  return Builder(builder: (context) {
    return build(context, ModalRoute.of(context).settings.arguments);
  });
}
