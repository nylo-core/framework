import 'package:recase/recase.dart';

/// This stub is used to create a Button Widget in the /resources/widgets/buttons/partials/ directory.
String buttonStub(ReCase rc) =>
    '''
import 'package:flutter/material.dart';
import '/resources/widgets/buttons/abstract/app_button.dart';

class ${rc.pascalCase}Button extends StatefulAppButton {
  final Color? backgroundColor;
  final Color? contentColor;

  ${rc.pascalCase}Button({
    super.key,
    required super.text,
    super.onPressed,
    super.submitForm,
    super.onFailure,
    super.showToastError = true,
    super.loadingStyle,
    super.width,
    super.height,
    super.animationStyle,
    super.splashStyle,
    this.backgroundColor,
    this.contentColor,
  });

  @override
  Widget buildButton(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color bgColor = backgroundColor ?? theme.colorScheme.primary;
    final Color fgColor = contentColor ?? theme.colorScheme.onPrimary;
    final BorderRadius radius = BorderRadius.circular(14);

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: fgColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
''';

/// This stub is used to create a static method in the Button class.
String buttonStaticMethodStub(ReCase rc) =>
    '''
  /// ${rc.titleCase} button
  static Widget ${rc.camelCase}({
    required String text,
    VoidCallback? onPressed,
    (dynamic, Function(dynamic data))? submitForm,
    Function(dynamic error)? onFailure,
    bool showToastError = true,
    Color? backgroundColor,
    double? width,
  }) {
    return ${rc.pascalCase}Button(
      text: text,
      onPressed: onPressed,
      submitForm: submitForm,
      onFailure: onFailure,
      showToastError: showToastError,
      loadingStyle: LoadingStyle.skeletonizer(),
      backgroundColor: backgroundColor,
      width: width,
      height: _buttonHeight,
      animationStyle: ButtonAnimationStyle.clickable(),
    );
  }
''';
