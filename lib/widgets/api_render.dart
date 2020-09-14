import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nylo_framework/helpers/helper.dart';

/// Renders future API requests into Widgets
/// Example:
///
/// ApiRender<DemoUser>(
/// 	api: widget.controller.apiService.fetchDemoUser(),
/// 	widget: (user) {
/// 	  return Text(user.data[0].firstName);
/// 	},
/// )
///
/// Replace [DemoUser] with the model your api request returns. In our example
/// the fetchDemoUser() method returns a DemoUser.
/// The [api] parameter is where your provide the api request from your [apiService].
/// If the request is successful, the [widget] callback will return your model.
/// Any errors will return null.
/// You should then be able to return your desired [Widget] with the object in
/// the callback method like the example above.
class ApiRender<T> extends FutureBuilder {
  ApiRender(
      {Key key,
      Future api,
      Widget Function(T model) widget,
      Widget whenLoading = const CircularProgressIndicator(),
      Widget initialWidget})
      : super(
            key: key,
            future: api,
            initialData: initialWidget,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.waiting:
                  if (initialWidget == null) {
                    return whenLoading;
                  }
                  return initialWidget;
                default:
                  if (snapshot.hasError) {
                    NyLogger.debug(snapshot.error);
                    return widget(null);
                  } else
                    return widget(snapshot.data);
              }
            });
}
