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
      @required Future api,
      @required Widget Function(T model) child,
      Widget whenLoading,
      Widget initialWidget})
      : super(
          key: key,
          future: api,
          initialData: initialWidget,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                if (initialWidget == null) {
                  return whenLoading == null
                      ? Center(child: CircularProgressIndicator())
                      : whenLoading;
                }
                return initialWidget;
              default:
                if (snapshot.hasError) {
                  NyLogger.debug(snapshot.error);
                  if (initialWidget == null) {
                    return child(null);
                  }
                  return initialWidget;
                } else
                  return child(snapshot.data);
            }
          },
        );
}
