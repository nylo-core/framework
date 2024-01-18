import 'package:recase/recase.dart';

/// This stub is used to create a new bottom nav page.
String pageBottomNavStub({required String className, required int tabCount}) =>
    '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${className.pascalCase}Page extends NyStatefulWidget {
  static const path = '/${className.paramCase}';
  
  ${className.pascalCase}Page() : super(path, child: _${className.pascalCase}PageState());
}

class _${className.pascalCase}PageState extends NyState<${className.pascalCase}Page> {

  int _currentIndex = 0;

  final List<Widget> _pages = [
''' +
    List.generate(tabCount,
            (index) => '    Container(child: Text("Tab ${index + 1}"),),')
        .join('\n') +
    '''\n
  ];

  @override
  init() async {

  }

  /// Use boot if you need to load data before the [view] is rendered.
  // @override
  // boot() async {
  //   await Future.delayed(Duration(seconds: 2));
  // }

  @override
  Widget view(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${className.pascalCase}'),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
''' +
    List.generate(
            tabCount,
            (index) =>
                '          BottomNavigationBarItem(\n            icon: Icon(Icons.home),\n            label: \'Tab ${index + 1}\',\n          ),')
        .join('\n') +
    '''\n
        ],
      ),
    );
  }
}

''';
