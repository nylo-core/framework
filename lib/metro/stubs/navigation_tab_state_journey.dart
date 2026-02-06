import 'package:recase/recase.dart';

/// This stub is used to create a navigation tab Journey State widget
String navigationTabJourneyStateStub(ReCase rc,
        {required ReCase parentNavigationHub, bool isLastStep = false}) =>
    '''
import 'package:flutter/material.dart';
import '/resources/pages/navigation_hubs/${parentNavigationHub.snakeCase}/${parentNavigationHub.snakeCase}_navigation_hub.dart';
import '/resources/widgets/buttons/buttons.dart';
import 'package:nylo_framework/nylo_framework.dart';

class ${rc.pascalCase} extends StatefulWidget {
  const ${rc.pascalCase}({super.key});

  @override
  createState() => _${rc.pascalCase}State();
}

class _${rc.pascalCase}State extends JourneyState<${rc.pascalCase}> {
  _${rc.pascalCase}State() : super(
      navigationHubState: ${parentNavigationHub.pascalCase}NavigationHub.path.stateName());
''' +
    (isLastStep
        ? '''
  /// Callback when journey completes
  @override
  void Function()? get onJourneyComplete => () {
    // Navigate to your home page or next destination
    // routeTo(HomePage.path);
  };
'''
        : '') +
    '''

  @override
  get init => () {
    // Your initialization logic here
  };

  @override
  Widget view(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${rc.pascalCase}', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 20),
                  Text('This onboarding journey will help you get started.'),
                ],
              ),
            ),
          ),

          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isFirstStep)
                Flexible(
                  child: Button.textOnly(
                    text: "Back",
                    textColor: Colors.black87,
                    onPressed: onBackPressed,
                  ),
                )
              else
                const SizedBox.shrink(),
              Flexible(
                child: Button.primary(
                  text: ''' +
    (isLastStep ? '"Get Started"' : '"Continue"') +
    ''',
                  onPressed: ''' +
    (isLastStep ? 'onJourneyComplete' : 'nextStep') +
    ''',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

''' +
    (isLastStep
        ? ''
        : '''
  /// Check if the journey can continue to the next step
  /// Override this method to add validation logic
  @override
  Future<bool> canContinue() async {
    // Perform your validation logic here
    // Return true if the journey can continue, false otherwise
    return true;
  }
''') +
    '''
  /// Called before navigating to the next step
  /// Override this method to perform actions before continuing
  @override
  Future<void> onBeforeNext() async {
    // E.g. save data to session
    // session('onboarding', {
    //   'name': 'Anthony Gordon',
    //   'occupation': 'Software Engineer',
    // });
    //
    // final sessionData = session('onboarding').data(); // {'name': 'Anthony Gordon', 'occupation': 'Software Engineer'}
    // printInfo(sessionData);

    // access the session data from other NavigationTabs
  }

  /// Called when the journey is complete (at the last step)
  /// Override this method to perform completion actions
  @override
  Future<void> onComplete() async {}
}
''';
