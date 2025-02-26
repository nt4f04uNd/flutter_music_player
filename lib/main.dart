import 'dart:async';
import 'dart:isolate';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sweyer/media_query_wrapper.dart';
import 'package:sweyer/sweyer.dart';
import 'package:sweyer/constants.dart' as constants;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

/// Builds up the error report message from the exception and stacktrace.
String buildErrorReport(dynamic ex, dynamic stack) {
  return '''
$ex
                      
$stack''';
}

Future<void> reportError(dynamic error, StackTrace stack) async {
  if (Prefs.isInitialized && Prefs.devMode.get()) {
    ShowFunctions.instance.showError(
      errorDetails: buildErrorReport(error, stack),
    );
  }
  if (Firebase.apps.isNotEmpty) {
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }
}

Future<void> reportFlutterError(FlutterErrorDetails details) async {
  if (Prefs.devMode.get()) {
    ShowFunctions.instance.showError(
      errorDetails: buildErrorReport(details.exception, details.stack),
    );
  }
  await FirebaseCrashlytics.instance.recordFlutterError(details);
}

class _WidgetsBindingObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      /// This ensures that proper UI will be applied when activity is resumed.
      ///
      /// See:
      /// * https://github.com/flutter/flutter/issues/21265
      /// * https://github.com/ryanheise/audio_service/issues/662
      ///
      /// [SystemUiOverlayStyle.statusBarBrightness] is only honored on iOS,
      /// so I can safely use that here.
      final lastUi = SystemUiStyleController.instance.lastUi;
      SystemUiStyleController.instance.setSystemUiOverlay(SystemUiStyleController.instance.lastUi.copyWith(
        statusBarBrightness: lastUi.statusBarBrightness == null || lastUi.statusBarBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ));

      /// Defensive programming if I some time later decide to add iOS support.
      SystemUiStyleController.instance.setSystemUiOverlay(SystemUiStyleController.instance.lastUi.copyWith(
        statusBarBrightness: lastUi.statusBarBrightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ));
    }
  }
}

Future<void> main() async {
  // Disabling automatic system UI adjustment, which causes system nav bar
  // color to be reverted to black when the bottom player route is being expanded.
  //
  // Related to https://github.com/flutter/flutter/issues/40590
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  for (RenderView renderView in binding.renderViews) {
    renderView.automaticSystemUiAdjustment = false;
  }
  await NFPrefs.initialize();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    FirebaseFunctions.instance.useFunctionsEmulator('http://localhost/', 5001);

    // Force disable Crashlytics collection while doing every day development.
    // Temporarily toggle this to true if you want to test crash reporting in your app.
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  }

  Isolate.current.addErrorListener(RawReceivePort((pair) async {
    final List<dynamic> errorAndStacktrace = pair;
    await reportError(errorAndStacktrace.first, errorAndStacktrace.last);
  }).sendPort);
  FlutterError.onError = reportFlutterError;
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack);
    return true;
  };
  WidgetsBinding.instance.addObserver(_WidgetsBindingObserver());

  await DeviceInfoControl.instance.init();
  ThemeControl.instance.init();
  ThemeControl.instance.initSystemUi();
  await Permissions.instance.init();
  await ContentControl.instance.init();
  runApp(const ProviderScope(child: App()));
}

class App extends StatefulWidget {
  const App({
    super.key,
    this.debugShowCheckedModeBanner = true,
  });

  final bool debugShowCheckedModeBanner;

  static NFThemeData nfThemeData = NFThemeData(
    systemUiStyle: staticTheme.systemUiThemeExtension.black,
    modalSystemUiStyle: staticTheme.systemUiThemeExtension.modal,
    bottomSheetSystemUiStyle: staticTheme.systemUiThemeExtension.bottomSheet,
  );

  static void rebuildAllChildren() {
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (AppRouter.instance.navigatorKey.currentContext as Element?)!.visitChildren(rebuild);
  }

  @override
  _AppState createState() => _AppState();
}

late SlidableController _playerRouteController;
late SlidableController _drawerController;

/// TODO: https://github.com/nt4f04uNd/sweyer/issues/81#issuecomment-1335575679
/// This is a hack.
///
/// [playerRouteController] is used inside [PlayerInterfaceColorStyleControl], which
/// is faked and initialized before the app actually runs, meaning that
/// at some point it could use uninitialized [playerRouteController].
///
/// This happens in [testAppGoldens] with playerInterfaceColorStylesToTest: {PlayerInterfaceColorStyle.themeBackgroundColor},
/// `player_route.player_route` can be used as an example of this.
bool playerRouteControllerInitialized = false;
SlidableController get playerRouteController => _playerRouteController;
SlidableController get drawerController => _drawerController;

class _AppState extends State<App> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _drawerController = SlidableController(
      vsync: this,
      springDescription: DismissibleRoute.springDescription,
    );
    _playerRouteController = SlidableController(
      vsync: this,
      springDescription: playerRouteSpringDescription,
    );
    playerRouteControllerInitialized = true;
    NFWidgets.init(
      navigatorKey: AppRouter.instance.navigatorKey,
      routeObservers: [routeObserver, homeRouteObserver],
    );
  }

  @override
  void dispose() {
    _playerRouteController.dispose();
    _drawerController.dispose();
    playerRouteControllerInitialized = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQueryWrapper(
      child: Consumer(builder: (context, ref, child) {
        final materialAppSwitchesState = ref.watch(materialAppSwitchesStateHolderProvider.select((value) => value));
        return StreamBuilder(
          stream: ThemeControl.instance.themeChanging,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            final theme = ThemeControl.instance.theme;
            return NFTheme(
              data: App.nfThemeData,
              child: MaterialApp.router(
                showPerformanceOverlay: materialAppSwitchesState.showPerformanceOverlay,
                checkerboardRasterCacheImages: materialAppSwitchesState.checkerboardRasterCacheImages,
                showSemanticsDebugger: materialAppSwitchesState.showSemanticsDebugger,
                debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
                title: constants.Config.applicationTitle,
                theme: theme,
                color: theme.colorScheme.primary,
                supportedLocales: constants.Config.supportedLocales,
                scrollBehavior: _ScrollBehavior(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                routerDelegate: AppRouter.instance,
                routeInformationParser: AppRouteInformationParser(),
              ),
            );
          },
        );
      }),
    );
  }
}

class _ScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    final theme = Theme.of(context);
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: theme.colorScheme.secondaryContainer,
      child: child,
    );
  }
}
