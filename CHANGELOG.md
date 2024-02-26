## [5.21.4] - 2024-02-26

* Update pubspec.yaml

## [5.21.3] - 2024-02-24

* Update pubspec.yaml

## [5.21.2] - 2024-02-16

* Update pubspec.yaml

## [5.21.1] - 2024-02-14

* Update pubspec.yaml

## [5.21.0] - 2024-02-12

* Tweak stubs
* Update pubspec.yaml

## [5.20.18] - 2024-02-08

* Update pubspec.yaml

## [5.20.17] - 2024-02-07

* Update pubspec.yaml

## [5.20.16] - 2024-02-07

* Update pubspec.yaml

## [5.20.15] - 2024-02-04

* Update pubspec.yaml

## [5.20.14] - 2024-02-04

* export `ny_language_switcher` to `nylo_framework.dart`
* Update pubspec.yaml

## [5.20.13] - 2024-02-02

* Update pubspec.yaml

## [5.20.12] - 2024-02-02

* Update pubspec.yaml

## [5.20.11] - 2024-02-01

* Update page stub docs

## [5.20.10] - 2024-02-01

* Update pubspec.yaml

## [5.20.9] - 2024-01-29

* Update pubspec.yaml

## [5.20.8] - 2024-01-28

* Remove `await Future.delayed(Duration(seconds: 2));` from stub
* Update config stub
* Update pubspec.yaml

## [5.20.7] - 2024-01-26

* Fix postman not automatically adding the `ApiService` into the `decoders.dart` file 
* Update pubspec.yaml

## [5.20.6] - 2024-01-24

* Add `override` to model stub

## [5.20.5] - 2024-01-23

* Update pubspec.yaml

## [5.20.4] - 2024-01-23

* Update pubspec.yaml

## [5.20.3] - 2024-01-22

* Update pubspec.yaml

## [5.20.2] - 2024-01-21

* Update pubspec.yaml

## [5.20.1] - 2024-01-18

* Update README.md

## [5.20.0] - 2024-01-18

* New `--bottom-nav` flag to create bottom nav pages. E.g. `metro make:page dashboard_nav --bottom-nav`
* Add new stub for creating pages that use bottom navigation tabs
* Update pubspec.yaml

## [5.19.0] - 2024-01-15

* Update page and controller stub to use `view` instead of `build`
* Update the page and controller stub to include controller getter
* Update pubspec.yaml

## [5.18.9] - 2024-01-13

* Update pubspec.yaml

## [5.18.8] - 2024-01-13

* Update pubspec.yaml

## [5.18.7] - 2024-01-11

* Improve `metro make:api_service` when using Postman flag

## [5.18.6] - 2024-01-11

* Improve `metro make:api_service` when using Postman flag

## [5.18.5] - 2024-01-10

* Fix `metro make:api_service` error when using Postman flag

## [5.18.4] - 2024-01-06

* Update pubspec.yaml

## [5.18.3] - 2024-01-03

* Update pubspec.yaml

## [5.18.2] - 2024-01-03

* Update stateful stub
* Update pubspec.yaml

## [5.18.1] - 2024-01-02

* Update pubspec.yaml

## [5.18.0] - 2024-01-01

* Update pubspec.yaml

## [5.17.0] - 2024-01-01

* Metro cli improvements
  * Ability to create pages in a subfolder. E.g. `metro make:page auth/login`
  * Ability to create models in a subfolder. E.g. `metro make:model auth/user`
  * Ability to create controllers in a subfolder. E.g. `metro make:controller auth/login`
  * Update `--postman` flag for API Services. Now you can run `metro make:api_service example_api_service --postman` and it will help you create an API Service from a Postman collection.
* Update stubs
* Add `cli_dialog` as a dependency
* Update pubspec.yaml

## [5.16.0] - 2023-12-25

* Update pubspec.yaml

## [5.15.0] - 2023-12-09

* Export new `ny_route_history_observer.dart` file
* Update pubspec.yaml

## [5.14.0] - 2023-12-03

* Update pubspec.yaml

## [5.13.0] - 2023-12-02

* Add new `--json` flag to the "make:model" command to create a model from a json string. E.g. `metro make:model user --json '{"name": "John Doe", "age": 30}'`

## [5.12.0] - 2023-12-02

* Update pubspec.yaml

## [5.11.1] - 2023-12-01

* Update pubspec.yaml

## [5.11.0] - 2023-11-25

* Update pubspec.yaml

## [5.10.0] - 2023-11-23

* Ability to set routes as the initialPage using **--initial** E.g. `metro make:page dashboard --initial`
* Ability to set routes as the authPage using **--auth** E.g. `metro make:page dashboard --auth`
* Update pubspec.yaml

## [5.9.0] - 2023-11-22

* New ability to create dio Interceptors using Metro. E.g. `metro make:interceptor auth_token`
* Update stubs for creating pages and api services
* Small refactor to Metro class
* Remove ny_base_networking.dart
* Update pubspec.yaml

## [5.8.0] - 2023-11-04

* Fix `make:api_service` when using Postman flag
* New `publish:slate` command added to Metro
* Added more docs to Metro methods

## [5.7.1] - 2023-10-27

* Update page stub to include an example on how to set the state. 

## [5.7.0] - 2023-10-22

* Ability to auto add themes to the Nylo config using e.g. `metro make:theme bright_theme`
* Update default theme stub to use `useMaterial3`
* Update pubspec.yaml

## [5.6.0] - 2023-10-19

* Add docblock to more APIs
* Update pubspec.yaml

## [5.5.0] - 2023-10-17

* Update page stub to use `NyPage`
* Fix metro make:api_service Postman error when URL is null
* Update pubspec.yaml

## [5.4.1] - 2023-10-08

* Update pubspec.yaml

## [5.4.0] - 2023-10-01

* Ability to create config files via Metro
* Update pubspec.yaml

## [5.3.7] - 2023-09-22

* Update pubspec.yaml

## [5.3.6] - 2023-09-14

* Update pubspec.yaml

## [5.3.5] - 2023-08-31

* Update pubspec.yaml

## [5.3.4] - 2023-08-31

* Update pubspec.yaml

## [5.3.3] - 2023-08-31

* Update pubspec.yaml

## [5.3.2] - 2023-08-28

* Add docblock to setPagination method and fix the queryParameters not being reset when using the `api` helper

## [5.3.1] - 2023-08-26

* Update pubspec.yaml

## [5.3.0] - 2023-08-25

* Update stateful_stub to remove `stateInit`
* Add `setPagination` to NyBaseNetworking
* Update pubspec.yaml

## [5.2.1] - 2023-08-21

* Update pubspec.yaml

## [5.2.0] - 2023-08-21

* Add `useUndefinedResponse` to `network` helper. This will allow you to catch the response when your decoder.dart file fails to return the correct type. To listen to undefinedResponse's, call `onUndefinedResponse(dynamic data, Response response, BuildContext? context)` in your ApiService.
* Update stateful_stub to include `stateInit` and `stateUpdated`
* Small refactor to page_stub 
* Fix Metro error -  The class 'FileSystemEvent' can't be extended, implemented
* Add json_dart_generator into the library

## [5.1.2] - 2023-07-13

* Pubspec.yaml dependency updates.

## [5.1.1] - 2023-07-03

* Pubspec.yaml dependency updates.

## [5.1.0] - 2023-06-17

* Breaking change to validation.
* If you are using Nylo 5.x, do the following:
  * Go to **config/validation_rules.dart**.
  * Update 'final Map<Type, dynamic> validationRules = {'
  * to this 'final Map<String, dynamic> validationRules = {'
  * Custom validation rules must now the follow the following format:
    * "simple_password": (attribute) => SimplePassword(attribute), // example
* Pubspec.yaml dependency updates.

## [5.0.6] - 2023-06-14

* Update Nylo framework version.

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
* Create Api Services from Postman collections using Metro, read more [here](https://nylo.dev/docs/5.x/metro#make-api-service-using-postman)
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
