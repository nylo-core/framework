import 'package:recase/recase.dart';

/// This stub is used to create a Stateful Widget in the /resources/widgets/ directory.
String widgetStatefulStub(ReCase rc, {String? content}) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase} extends StatefulWidget {
  
  const ${rc.pascalCase}({super.key});

  @override
  createState() => _${rc.pascalCase}State();
}

class _${rc.pascalCase}State extends NyState<${rc.pascalCase}> {

  @override
  get init => () {

  };

  @override
  Widget view(BuildContext context) {
    return Container(
      ${content != null ? 'child: ${content}' : ''}
    );
  }
}
''';
