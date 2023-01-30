import 'package:recase/recase.dart';

String apiServiceStub(ReCase rc,
        {required ReCase model, required String baseUrl}) =>
    '''
import 'package:flutter/material.dart';
import '/app/networking/dio/base_api_service.dart';
${baseUrl == "getEnv('API_BASE_URL')" ? "import 'package:nylo_framework/nylo_framework.dart';" : ""}
${model.originalText != 'Model' ? "import '../../app/models/${model.snakeCase}.dart';" : ""}

class ${rc.pascalCase}ApiService extends BaseApiService {
  ${rc.pascalCase}ApiService({BuildContext? buildContext}) : super(buildContext);

  @override
  String get baseUrl => $baseUrl;

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
  Future<bool?> delete({required int id}) async {
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
