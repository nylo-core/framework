// Make commands
import 'make/api_service.dart' as make_api_service;
import 'make/bottom_sheet_modal.dart' as make_bottom_sheet_modal;
import 'make/button.dart' as make_button;
import 'make/command.dart' as make_command;
import 'make/config.dart' as make_config;
import 'make/controller.dart' as make_controller;
import 'make/deep_link_provider.dart' as make_deep_link_provider;
import 'make/env.dart' as make_env;
import 'make/event.dart' as make_event;
import 'make/form.dart' as make_form;
import 'make/interceptor.dart' as make_interceptor;
import 'make/journey_widget.dart' as make_journey_widget;
import 'make/key.dart' as make_key;
import 'make/model.dart' as make_model;
import 'make/navigation_hub.dart' as make_navigation_hub;
import 'make/page.dart' as make_page;
import 'make/provider.dart' as make_provider;
import 'make/route_guard.dart' as make_route_guard;
import 'make/state_managed_widget.dart' as make_state_managed_widget;
import 'make/stateful_widget.dart' as make_stateful_widget;
import 'make/stateless_widget.dart' as make_stateless_widget;

/// Map of built-in commands to their main functions
final Map<String, Future<void> Function(List<String>)> builtInCommands = {
  'make:api_service': make_api_service.main,
  'make:bottom_sheet_modal': make_bottom_sheet_modal.main,
  'make:button': make_button.main,
  'make:command': make_command.main,
  'make:config': make_config.main,
  'make:controller': make_controller.main,
  'make:deep_link_provider': make_deep_link_provider.main,
  'make:env': make_env.main,
  'make:event': make_event.main,
  'make:form': make_form.main,
  'make:interceptor': make_interceptor.main,
  'make:journey_widget': make_journey_widget.main,
  'make:key': make_key.main,
  'make:model': make_model.main,
  'make:navigation_hub': make_navigation_hub.main,
  'make:page': make_page.main,
  'make:provider': make_provider.main,
  'make:route_guard': make_route_guard.main,
  'make:state_managed_widget': make_state_managed_widget.main,
  'make:stateful_widget': make_stateful_widget.main,
  'make:stateless_widget': make_stateless_widget.main,
};
