import 'package:nylo_framework/networking/network_url.dart';

class NetworkEnvironment {
  List<NetworkUrl> networkEnvironments;
  String environment;

  NetworkEnvironment(this.networkEnvironments, {this.environment = "development"});

  String getBaseUrl({String tag = ""}) {
    var baseUrl = "";

    NetworkUrl networkUrl = this.networkEnvironments.firstWhere((e) => e.environment == environment && e.tag == tag, orElse: () => null);
    if (networkUrl != null) {
      baseUrl = networkUrl.url;
    }

    return baseUrl;
  }
}