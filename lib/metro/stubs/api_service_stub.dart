import 'package:recase/recase.dart';

/// This stub is used to create a new API Service.
String apiServiceStub(
  ReCase rc, {
  required ReCase model,
  required String baseUrl,
}) =>
    '''import '/bootstrap/decoders.dart';
${baseUrl == "getEnv('API_BASE_URL')" ? "import 'package:nylo_framework/nylo_framework.dart';" : ""}${model.originalText != 'Model' ? "\nimport '/app/models/${model.snakeCase}.dart';" : ""}

class ${rc.pascalCase}ApiService extends NyApiService {
  ${rc.pascalCase}ApiService() : super(decoders: modelDecoders);

  @override
  String get baseUrl => $baseUrl;
  
  @override
  get interceptors => {
    ...super.interceptors,
    // MyCustomInterceptor: MyCustomInterceptor(),
  };

${model.originalText != "Model" ? '''
  /// Return a list of ${model.pascalCase}
  Future<List<${model.pascalCase}>?> fetchAll({dynamic query}) async {
    return await network<List<${model.pascalCase}>>(
        request: (request) => request.get("/endpoint-path", queryParameters: query),
    );
  }

  /// Find a ${model.pascalCase}
  Future<${model.pascalCase}?> find({required int id}) async {
    return await network<${model.pascalCase}>(
      request: (request) => request.get("/endpoint-path/\$id"),
    );
  }

  /// Create a ${model.pascalCase}
  Future<${model.pascalCase}?> create({required dynamic data}) async {
    return await network<${model.pascalCase}>(
      request: (request) => request.post("/endpoint-path", data: data),
    );
  }

  /// Update a ${model.pascalCase}
  Future<${model.pascalCase}?> update({dynamic query}) async {
    return await network<${model.pascalCase}>(
      request: (request) => request.put("/endpoint-path", queryParameters: query),
    );
  }

  /// Delete a ${model.pascalCase}
  Future<bool?> destroy({required int id}) async {
    return await network<bool>(
      request: (request) => request.delete("/endpoint-path/\$id"),
    );
  }''' : '''
  /// Example API Request
  Future<dynamic> fetchData() async {
    return await network(
        request: (request) => request.get("/endpoint-path"),
    );
  }'''}
}
''';
