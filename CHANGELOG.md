## [5.0.5] - 2023-06-14

* Update GitHub actions.
* Refactor metro class.
* Pubspec.yaml dependency updates.

## [5.0.4] - 2023-06-08

* Change nylo_framework version.

## [5.0.3] - 2023-06-08

* Change `DioError` to `DioException` as per dio upgrade notes.
* Refactor metro to use `runCommand` from MetroService.
* Pubspec.yaml dependency updates.

## [5.0.2] - 2023-05-28

* Pubspec.yaml dependency updates.

## [5.0.1] - 2023-05-24

* Pubspec.yaml dependency updates.

## [5.0.0] - 2023-05-16

* `NyBaseApiService` has a new method `getContext` to get the BuildContext.
* Remove 'Storable' from the Model stub.
* Page stubs now include a `path` variable to make routing easier.
* New command to create Route Guards.
* Pubspec.yaml dependency updates.
* Readme update.

## [4.2.0] - 2023-05-16

* Flutter v3.10.0 fixes:
    * Update: theme_provider package

## [4.1.5] - 2023-03-07

* Fix metro make:model if modelDecoders doesn't exist.

## [4.1.4] - 2023-03-03

* Pubspec.yaml dependency updates.

* ## [4.1.3] - 2023-02-22

* Pubspec.yaml dependency updates.

## [4.1.2] - 2023-02-14

* Add logo to package
* Pubspec.yaml dependency updates.

## [4.1.0] - 2023-01-30

* Update stubs.
* Now you can pass a baseUrl to the `network` or `nyApi` method.
* Small refactor to the Metro class.
* Fix importPaths when using `addToRouter`.
* Pubspec.yaml dependency updates.

## [4.0.0] - 2023-01-01

* Metro will automatically add Routes to the router.dart file
* Metro will automatically add Events to the config/events.dart file
* Metro will automatically add ApiServices and Models to the config/decoders.dart file
* Metro will automatically add Providers to the config/providers.dart file
* Create Api Services from Postman collections using Metro, read more [here](http://nylo.dev/docs/5.x/metro#make-api-service-using-postman)
* `NyBaseApiService` class has new parameters to add a `bearerToken` or `headers` on each request
* Update stubs
* Copyright year updated
* Pubspec.yaml dependency updates

## [3.4.0] - 2022-09-19

* Add page_transition to dependencies
* Pubspec.yaml dependency updates

## [3.3.0] - 2022-08-27

* Update theme stubs
* Pubspec.yaml dependency updates

## [3.2.0] - 2022-07-27

* Update page stub to include default base Controller on creation
* Refactor stubs using 'package:flutter_app' to use project path
* Pubspec.yaml dependency updates

## [3.1.4] - 2022-06-28

* Pubspec.yaml dependency updates

## [3.1.3] - 2022-05-19

* Add @override to event stubs
* Pubspec.yaml dependency updates

## [3.1.2] - 2022-05-04

* Add version to nylo_framework

## [3.1.1] - 2022-05-04

* Remove import from ny_base_networking.dart
* Flutter format

## [3.1.0] - 2022-05-04

* Add new `NyBaseApiService` class to the networking folder
* Add dio as a dependency
* Pubspec.yaml dependency updates

## [3.0.0] - 2022-04-29

* New command to create: Events, Providers and API Services
* Remove command: project:init
* Docs link updated in Model stub
* Update README info
* Remove nylo_support ref from stubs
* Pubspec.yaml dependency updates

## [2.2.0] - 2022-03-29

* Remove appended 'Widget' from Metro:make command for stateless and stateful widgets
* Docs link updated in Model stub
* Pubspec.yaml dependency updates

## [2.1.4] - 2022-01-02

* Merge PR #27 - Example moved to null safety
* Remove build appicons command from Metro cli

## [2.1.3] - 2021-12-17

* Small refactor to Metro Cli
* Pubspec.yaml dependency updates

## [2.1.2] - 2021-12-12

* Update Controller stub
* Pubspec.yaml dependency updates

## [2.1.1] - 2021-12-10

* Upgrade to Dart 2.15
* Add toast notifications
* Pubspec.yaml dependency updates

## [2.1.0] - 2021-12-08

* Update Nylo version
* Ability to create themes and theme colors from Metro Cli
* Pubspec.yaml dependency updates

## [2.0.4] - 2021-09-21

* Update Nylo version

## [2.0.3] - 2021-09-21

* Pubspec.yaml dependency updates

## [2.0.2] - 2021-09-18

* Upgrade Dart (v2.14.0)
* Pubspec.yaml dependency updates

## [2.0.1] - 2021-09-11

* Remove NyBaseColors class

## [2.0.0] - 2021-09-10

* Refactor nylo_framework.dart
* Metro cli stability improvements
* New NyTheme class for setting the Flutter theme
* Null safety stubs
* Pubspec.yaml dependency updates

## [1.1.0] - 2021-07-13

* Null safety stubs

## [1.0.1] - 2021-07-07

* README changes

## [1.0.0] - 2021-07-07

* New method to create pages in router 'router.page(NyStatefulWidget widget)'
* Pubspec.yaml dependency updates

## [0.8.5] - 2021-04-30

* Use pascal format for metro cli
* Fix metro make:page command

## [0.8.4] - 2021-04-29

* Fix stub using NyStatefulWidget

## [0.8.3] - 2021-04-28

* Fix stub using NyStatefulWidget

## [0.8.2] - 2021-04-10

* Remove operand check

## [0.8.1] - 2021-04-10

* Update adaptive_theme dependency

## [0.8.0] - 2021-04-10

* Null safety support
* Rename StatefulPageWidget to NyStatefulWidget
* Pubspec.yaml dependency updates

## [0.7.0+1] - 2021-03-16

* Changes as per dart analysis log

## [0.7.0] - 2021-03-16

* Router bug fix
* Small tweaks

## [0.6.2] - 2021-03-07

* Flutter 2.0.0+ support
* Bug fixes

## [0.6.1] - 2021-02-18

* Bug fixes

## [0.6.0] - 2021-02-18

* Ability to create plugins for Nylo
* Refactored NyRouter class
* Add page transitions
* `StatefulPageWidget` class now has `data()` method
* Controller and model stub update
* new `construct(context)` method for controllers
* Version bump

## [0.5.2] - 2021-01-31

* Fix `onPop` called on null
* Pass new "result" into `pop` method

## [0.5.1] - 2021-01-30

* `flutter format`

## [0.5.0] - 2021-01-30

* Metro new commands: create stateless widgets, stateful widgets and storable models
* "common" folder renamed to "resources"
* Router new `route` method to create routes
* Controller refactored to remove .of(BuildContext context)
* New Storable method `save('key')` to store to secure storage
* onPop parameter added to `routeTo` method
* Small improvements and tweaks

## [0.4.0] - 2020-12-21

* New default state widget NyState
* Updates to Metro stubs
* APIRender Widget parameter refactor
* Helper class small refactor
* Dart code formatting

## [0.3.2] - 2020-09-23

* ApiRender widget updated with new required parameters and change in functionality.

## [0.3.1] - 2020-09-19

* Small fix to Metro cli tool
* Update to readme

## [0.3.0] - 2020-09-18

* Bug fix for controller when fetching request data
* Tweak to routes and transitions
* Improvements to Metro Cli

## [0.2.0] - 2020-09-15

* Controllers can now return arguments from routes
* Dispatch jobs with the new BusQueue
* Updated router class
* ApiRender widget for rending Widgets from api futures
* Removal of unused methods, code clean up, example added
* New method for storing objects and lists to shared preferences
* New methods to check app connectivity in networking
* Metro improvements and bug fixes
* Bug fixes to project

## [0.1.0] - 2020-08-23

* Initial release.
