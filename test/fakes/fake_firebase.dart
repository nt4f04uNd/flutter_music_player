import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_crashlytics_platform_interface/firebase_crashlytics_platform_interface.dart';

import '../observer/crashlytics.dart';
import '../test.dart';

// TODO: Remove this extension once we switch to Dart3.
extension NullableIterableExtensions<T extends Object> on Iterable<T?> {
  /// The non-`null` elements of this iterable.
  ///
  /// The same elements as this iterable, except that `null` values are omitted.
  Iterable<T> get nonNulls sync* {
    for (final element in this) {
      if (element != null) {
        yield element;
      }
    }
  }
}

class FakeFirebaseApp extends MockFirebaseApp {
  static Future<void> install(TestWidgetsFlutterBinding binding) async {
    TestFirebaseCoreHostApi.setup(FakeFirebaseApp());
    CrashlyticsObserver(binding, throwFatalErrors: true); // Register throwing crashlytics observer.
    await Firebase.initializeApp();
  }

  @override
  Future<PigeonInitializeResponse> initializeApp(
    String appName,
    PigeonFirebaseOptions initializeAppRequest,
  ) async {
    var response = await super.initializeApp(appName, initializeAppRequest);
    (response.pluginConstants.putIfAbsent(MethodChannelFirebaseCrashlytics.channel.name, () => {})!
        as Map)['isCrashlyticsCollectionEnabled'] = false;
    response.isAutomaticDataCollectionEnabled = false;
    return response;
  }

  @override
  Future<List<PigeonInitializeResponse?>> initializeCore() async {
    var responseList = await super.initializeCore();
    for (var response in responseList.nonNulls) {
      (response.pluginConstants.putIfAbsent(MethodChannelFirebaseCrashlytics.channel.name, () => {})!
          as Map)['isCrashlyticsCollectionEnabled'] = false;
      response.isAutomaticDataCollectionEnabled = false;
    }
    return responseList;
  }
}
