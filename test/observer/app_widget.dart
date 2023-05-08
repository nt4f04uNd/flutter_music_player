import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:tuple/tuple.dart';

import '../test.dart';

/// An observer for platform app widget channel requests.
class AppWidgetChannelObserver {
  /// The method channel used by the flutter `home_widget` package
  static const MethodChannel _channel = MethodChannel('home_widget');

  /// The list of requests made to save widget data.
  List<Tuple2<String, dynamic>> get saveWidgetDataLog => UnmodifiableListView(_saveWidgetDataLog);
  final List<Tuple2<String, dynamic>> _saveWidgetDataLog = [];

  /// The list of requests made to update a widget type.
  List<String> get updateWidgetRequests => UnmodifiableListView(_updateWidgetRequests);
  final List<String> _updateWidgetRequests = [];


  /// Create a new app widget observer, which automatically
  /// unregisters any previously created observer.
  AppWidgetChannelObserver(TestWidgetsFlutterBinding binding) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'saveWidgetData':
          var arguments = Map.castFrom<dynamic, dynamic, String, dynamic>(call.arguments);
          _saveWidgetDataLog.add(Tuple2(arguments['id'] as String, arguments['data']));
          return true;
        case 'updateWidget':
          var arguments = Map.castFrom<dynamic, dynamic, String, dynamic>(call.arguments);
          _updateWidgetRequests.add(arguments['name'] as String);
          return true;
      }
      return null; // Ignore unimplemented method calls.
    });
  }
}
