/// Base class used to represent an API request object used in [Metro] cli.
class NyApiRequest {
  String url;
  String method;
  List<Headers> headers;
  String modelName;
  String modelType;
  dynamic data;

  NyApiRequest(
      {this.url,
      this.method,
      this.headers,
      this.modelName,
      this.modelType,
      this.data});

  NyApiRequest.fromJson(Map<String, dynamic> json) {
    url = json['url'];
    method = json['method'];
    if (json['headers'] != null) {
      headers = new List<Headers>();
      json['headers'].forEach((v) {
        headers.add(new Headers.fromJson(v));
      });
    }
    modelName = json['model_name'];
    modelType = json['model_type'];
    data = json['data'] != null ? json['data'] : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['url'] = this.url;
    data['method'] = this.method;
    if (this.headers != null) {
      data['headers'] = this.headers.map((v) => v.toJson()).toList();
    }
    data['model_name'] = this.modelName;
    data['model_type'] = this.modelType;
    if (this.data != null) {
      data['data'] = this.data;
    }
    return data;
  }

  Map<String, String> headerMap() {
    Map<String, String> headers = {};

    if (this.headers.length > 0) {
      this.headers.forEach((header) {
        headers.addAll({header.key.toString(): header.value.toString()});
      });
    }

    return headers;
  }

  String headerString() {
    String headers = "";

    if (this.headers.length > 0) {
      this.headers.forEach((header) {
        headers += "\"${header.key.toString()}\": \"${header.value.toString()}\",";
      });
      if (headers.endsWith(",")) {
        headers = headers.substring(0, headers.length - 1);
      }
    }

    return headers;
  }

  Map<String, String> urlQueryMap() {
    var uri = Uri.dataFromString(this.url);
    Map<String, String> params = uri.queryParameters;

    return params;
  }

  List<String> urlPrams() {
    return this.urlQueryMap().keys.toList();
  }

  String strUrlParams() {
    String str = "";
    List<String> urlParams = this.urlPrams();
    for (int i = 0; i < urlParams.length; i++) {
      str = str +
          "dynamic ${urlParams[i]}" +
          ((i + 1) == urlParams.length ? '' : ', ');
    }
    return str;
  }

  Uri urlUri() {
    return Uri.dataFromString(this.url);
  }

  String mapQueryParams() {
    String str = "";
    List<String> urlParams = this.urlPrams();
    for (int i = 0; i < urlParams.length; i++) {
      str = str +
          "'${urlParams[i]}': ${urlParams[i]}.toString()" +
          ((i + 1) == urlParams.length ? '' : ', ');
    }
    return str;
  }

  String getBaseUrl() {
    RegExp regExp = new RegExp(
      r"(http[s]?:\/\/)?([^\/\s]+)(.*)",
      caseSensitive: false,
      multiLine: false,
    );

    return regExp.firstMatch(this.url).group(2);
  }

  String getUrlPath({bool withQuery = false}) {
    RegExp regExp = new RegExp(
      r"(http[s]?:\/\/)?([^\/\s]+\/)(.*)",
      caseSensitive: false,
      multiLine: false,
    );

    String strWithQuery = regExp.firstMatch(this.url).group(3);

    if (withQuery == false && strWithQuery.contains("?")) {
      return strWithQuery.split("?")[0];
    }

    return strWithQuery;
  }

  String getProtocol() {
    RegExp regExp = new RegExp(
      r"^[^:]+(?=:\/\/)",
      caseSensitive: false,
      multiLine: false,
    );

    return regExp.stringMatch(this.url).toString();
  }
}

class Headers {
  String key;
  String value;

  Headers({this.key, this.value});

  Headers.fromJson(Map<String, dynamic> json) {
    key = json['key'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['key'] = this.key;
    data['value'] = this.value;
    return data;
  }
}
