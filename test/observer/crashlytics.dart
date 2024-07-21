import 'package:firebase_crashlytics_platform_interface/firebase_crashlytics_platform_interface.dart';

import '../test.dart';

/// An observer for crashlytics messages.
class CrashlyticsObserver {
  /// Whether to throw fatal errors.
  final bool throwFatalErrors;

  /// The number of reported non-fatal errors.
  int get nonFatalErrorCount => _nonFatalErrorCount;
  int _nonFatalErrorCount = 0;

  /// The number of reported fatal errors.
  int get fatalErrorCount => _fatalErrorCount;
  int _fatalErrorCount = 0;

  /// The number of reported errors.
  int get errorCount => _fatalErrorCount + _nonFatalErrorCount;

  /// Create a new crashlytics observer, which automatically
  /// unregisters any previously created observer.
  CrashlyticsObserver(TestWidgetsFlutterBinding binding, {this.throwFatalErrors = true}) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannelFirebaseCrashlytics.channel, (call) {
      if (call.method == 'Crashlytics#recordError') {
        if (call.arguments['fatal']) {
          _fatalErrorCount++;
          if (throwFatalErrors) {
            throw call.arguments['exception'];
          }
        } else {
          _nonFatalErrorCount++;
        }
      }
      return null; // Ignore unimplemented method calls.
    });
  }
}
