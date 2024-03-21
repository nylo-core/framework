import 'package:recase/recase.dart';

/// This stub is used to create an Interceptor.
String interceptorStub({required ReCase interceptorName}) => '''
import 'package:nylo_framework/nylo_framework.dart';

class ${interceptorName.pascalCase}Interceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(dioException);
  }
}
''';
