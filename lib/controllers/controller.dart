import 'package:flutter/widgets.dart';
import 'package:nylo_framework/helpers/helper.dart';
import 'package:queue/queue.dart';

/// Class to handle queuing jobs
class BusQueue {
  Queue queue;

  BusQueue._privateConstructor();

  static final BusQueue instance = BusQueue._privateConstructor();

  /// Update the amount of jobs you want to run in parallel.
  setParallel(int parallel) {
    queue.parallel = parallel;
  }

  /// Adds one job to the queue
  dispatch(Future job) {
    queue.add(() => job);
  }

  /// Adds many jobs to the queue
  dispatchMany(List<Future> jobs) {
    jobs.forEach((job) {
      queue.add(() => job);
    });
  }
}

/// Nylo's base controller class
abstract class BaseController {
  BuildContext context;
  NyRequest request;
  BusQueue queue = BusQueue.instance;

  BaseController({this.context, this.request});

  dynamic data() => this.request.data();

  construct(BuildContext context) async {}
}

/// Base class to handle requests
class NyRequest {
  String currentRoute;
  NyArgument _args;
  NyRequest({this.currentRoute, NyArgument args}) {
    _args = args;
  }

  /// Write [data] to controller
  setData(dynamic data) {
    _args.data = data;
  }

  /// Returns data passed as an argument to a route
  dynamic data() => (_args == null ? null : _args.data);
}
