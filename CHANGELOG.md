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
