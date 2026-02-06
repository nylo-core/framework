import 'package:recase/recase.dart';

/// This stub is used to create a Bottom Sheet Modal in the /resources/widgets/bottom_sheet_modals/modals/ directory.
String bottomSheetModalStub(ReCase rc) => '''
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

/// ${rc.titleCase} Modal
///
/// Used in BottomSheetModal.show${rc.pascalCase}()
class ${rc.pascalCase}Modal extends StatelessWidget {
  const ${rc.pascalCase}Modal({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${rc.pascalCase}Modal').headingSmall(),
        
      ],
    );
  }
}
''';

/// This stub is used to create a static method in the BottomSheetModal class.
String bottomSheetModalStaticMethodStub(ReCase rc) => '''
  /// Show ${rc.titleCase} modal
  static Future<void> show${rc.pascalCase}(BuildContext context) {
    return displayModal(
      context,
      isScrollControlled: false,
      child: const ${rc.pascalCase}Modal(),
    );
  }
''';
