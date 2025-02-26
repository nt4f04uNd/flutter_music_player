import 'dart:async';
import 'dart:io';

export 'package:sweyer/sweyer.dart';
export 'package:flutter/foundation.dart';
export 'package:flutter_test/flutter_test.dart';
import 'package:android_content_provider/android_content_provider.dart';
import 'package:clock/clock.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:package_info_plus_platform_interface/method_channel_package_info.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:flutter_gen/gen_l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;
import 'package:sweyer/constants.dart' as constants;
import 'package:sweyer_plugin/sweyer_plugin_platform_interface.dart';

export 'fakes/fakes.dart';

import 'observer/observer.dart';
import 'test.dart';
import 'test_description.dart';

final _testSong = Song(
  id: 0,
  album: _testAlbum.album,
  albumId: _testAlbum.id,
  artist: _testArtist.artist,
  artistId: _testArtist.id,
  genre: 'genre',
  genreId: 0,
  title: 'title',
  track: 'track',
  dateAdded: 0,
  dateModified: 0,
  duration: 0,
  size: 0,
  filesystemPath: '/path/to/song',
  isFavoriteInMediaStore: false,
  generationAdded: 0,
  generationModified: 0,
);

const _testAlbum = Album(
  id: 0,
  album: 'album',
  albumArt: 'albumArt_albumArt_albumArt',
  artist: 'artist',
  artistId: 0,
  firstYear: 2000,
  lastYear: 2000,
  numberOfSongs: 1000,
);

final _testPlaylist = Playlist(
  id: 0,
  filesystemPath: '/path/to/playlist',
  dateAdded: 0,
  dateModified: 0,
  name: 'name',
  songIds: [_testSong.id],
);

const _testArtist = Artist(
  id: 0,
  artist: 'artist',
  numberOfAlbums: 1,
  numberOfTracks: 1,
);

final SongCopyWith songWith = _testSong.copyWith;
final AlbumCopyWith albumWith = _testAlbum.copyWith;
final PlaylistCopyWith playlistWith = _testPlaylist.copyWith;
final ArtistCopyWith artistWith = _testArtist.copyWith;

/// Default l10n delegate in tests.
final l10n = AppLocalizationsEn();
const kScreenHeight = 800.0;
const kScreenWidth = 450.0;
const kScreenPixelRatio = 3.0;
const kScreenSize = Size(kScreenWidth, kScreenHeight);

extension AppInitExtension on TestWidgetsFlutterBinding {
  /// Run a test that doesn't need the App UI using the following procedure:
  ///  1. Initializes the application, optionally running [initialization] when all fakes are set up
  ///     before the [ContentControl] is initialized.
  ///  2. Runs the test from the [callback].
  ///  3. Stops and disposes the player and app state.
  ///  4. Flushes all micro-tasks and stream events.
  Future<void> runAppTestWithoutUi(FutureOr<void> Function() callback, {VoidCallback? initialization}) async {
    addTearDown(postTest);
    return runTest(
      () => withClock(clock, () async {
        await _setUpAppTest(initialization);
        try {
          await callback();
        } finally {
          await MusicPlayer.instance.stop();
          DeviceInfoControl.instance.dispose();
          ContentControl.instance.dispose();
          // Wait for any asynchronous events and stream callbacks to finish.
          await pump(const Duration(seconds: 1));
          await idle();
        }
      }),
      () {},
    );
  }

  /// Sets the fake data providers and initializes the app state.
  ///
  /// The [configureFakes] callback can be used to modify the fake data providers
  /// before the controls will load it.
  Future<void> _setUpAppTest([VoidCallback? configureFakes]) async {
    assert(inTest, "setUpAppTest must be called in a test, otherwise it doesn't use the correct AsyncZone");
    for (TestFlutterView view in platformDispatcher.views) {
      view.physicalSize = kScreenSize * kScreenPixelRatio;
      view.devicePixelRatio = kScreenPixelRatio;
    }

    // Fake prefs values.
    //
    // Set empty values, because Windows implements shared_preferences
    // without plugin code, thus works in tests, which is undesirable,
    // because it changes test results
    // https://github.com/flutter/flutter/issues/95951#issuecomment-1002972723
    NFPrefs.prefs = null;
    await NFPrefs.prefs?.clear();
    SharedPreferences.setMockInitialValues({});

    // Reset any state
    AppRouter.instance = AppRouter();

    // Set up fakes
    SystemUiStyleController.instance = FakeSystemUiStyleController();
    Backend.instance = FakeBackend();
    DeviceInfoControl.instance = FakeDeviceInfoControl();
    FavoritesControl.instance = FakeFavoritesControl();
    PermissionsChannelObserver(this); // Grant all permissions by default.
    SweyerPluginPlatform.instance = FakeSweyerPluginPlatform(this);
    QueueControl.instance = FakeQueueControl();
    ThemeControl.instance = FakeThemeControl();
    JustAudioPlatform.instance = MockJustAudio(this);
    PackageInfoPlatform.instance = MethodChannelPackageInfo();
    PlayerInterfaceColorStyleControl.instance = PlayerInterfaceColorStyleControl();
    defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (MethodCall methodCall) async {
      return {
        'appName': constants.Config.applicationTitle,
        'packageName': 'com.nt4f04und.sweyer',
        'version': '1.0.0',
        'buildNumber': '0',
      };
    });
    defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_service.client.methods'),
        (MethodCall methodCall) async {
      return {};
    });
    defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_service.handler.methods'),
        (MethodCall methodCall) async {
      return {};
    });
    defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_session'),
        (MethodCall methodCall) async {
      return null;
    });
    defaultBinaryMessenger.setMockMethodCallHandler(AndroidContentResolver.methodChannel,
        (MethodCall methodCall) async {
      return null;
    });
    defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory' || methodCall.method == 'getApplicationSupportDirectory') {
        Directory('./temp').createSync();
        return './temp';
      }
      return null;
    });
    defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'),
        (MethodCall methodCall) async {
      if (methodCall.method == 'getDatabasesPath') {
        Directory('./temp').createSync();
        return './temp';
      }
      if (methodCall.method == 'openDatabase') {
        return 0;
      }
      if (methodCall.method == 'query') {
        return {};
      }
      if (methodCall.method == 'execute') {
        return null;
      }
      return null;
    });
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(() => Stream.value(const FakeLicenseEntry()));

    configureFakes?.call();

    // Set up regular classes
    PlaybackControl.instance = PlaybackControl();
    ContentControl.instance = ContentControl();

    // Default initialization process from main.dart
    await NFPrefs.initialize();
    await SearchHistory.instance.clear();

    await DeviceInfoControl.instance.init();
    ThemeControl.instance.init();
    ThemeControl.instance.initSystemUi();
    await Permissions.instance.init();
    final contentInitFuture = ContentControl.instance.init();
    // Flush micro-tasks to allow all stream events to propagate to their listeners.
    await pump(const Duration(seconds: 1));
    await idle();
    await contentInitFuture;
    // Called in the [App] widget
    NFWidgets.init(
      navigatorKey: AppRouter.instance.navigatorKey,
      routeObservers: [routeObserver, homeRouteObserver],
    );
  }
}

extension WidgetTesterExtension on WidgetTester {
  /// Run a test that uses the App UI using the following procedure:
  ///  1. Initializes the application, optionally running [initialization] when all fakes are set up
  ///     before the [ContentControl] is initialized.
  ///  2. Optionally, runs [postInitialization] after [ContentControl] is initialized.
  ///  3. Pumps the app.
  ///  4. Runs the test from the [callback].
  ///  5. Optionally, runs [goldenCaptureCallback].
  ///  6. Stops and disposes the player and app state.
  ///  7. Un-pumps the screen and flushes all micro-tasks and stream events.
  Future<void> runAppTest(
    AsyncCallback callback, {
    AsyncCallback? goldenCaptureCallback,
    VoidCallback? initialization,
    VoidCallback? postInitialization,
  }) async {
    await withClock(binding.clock, () async {
      await binding._setUpAppTest(initialization);
      try {
        postInitialization?.call();
        // App only supports vertical orientation, so switch tests to use it.
        await binding.setSurfaceSize(kScreenSize);
        await pumpWidget(ProviderScope(
          overrides: [
            playerInterfaceColorStyleArtColorBuilderProvider
                .overrideWithValue(FakePlayerInterfaceColorStyleArtColorBuilder())
          ],
          child: const App(debugShowCheckedModeBanner: false),
        ));
        await pump();
        await callback();
        await goldenCaptureCallback?.call();
      } finally {
        // Don't leak app state between tests.
        await MusicPlayer.instance.stop();
        DeviceInfoControl.instance.dispose();
        ContentControl.instance.dispose();
        // Un-pump, in case we have any real animations running,
        // so the pumpAndSettle on the next line doesn't hang on.
        await pumpWidget(const SizedBox());
        // Wait for any asynchronous events and stream callbacks to finish.
        await pump(const Duration(seconds: 1));
        await idle();
        // Wait for ui animations.
        await pumpAndSettle();
      }
    });
  }

  /// Whether the current tester is running in [testAppGoldens] and
  /// in light mode.
  bool get lightThemeGolden => _testersLightTheme[this] ?? false;

  /// Whether the current tester is running in [testAppGoldens] and
  /// has non-default player interface style.
  PlayerInterfaceColorStyle? get nonDefaultPlayerInterfaceColorStyle => _testersPlayerInterfaceColorStyle[this];

  Future<void> screenMatchesGolden(
    String name, {
    bool? autoHeight,
    Finder? finder,
    CustomPump? customPump,
  }) {
    final testDescription = getTestDescription(
      lightTheme: lightThemeGolden,
      playerInterfaceColorStyle: nonDefaultPlayerInterfaceColorStyle,
    );
    name = testDescription.buildFileName(name);
    return _screenMatchesGoldenWithTolerance(
      this,
      name,
      autoHeight: autoHeight,
      finder: finder,
      customPump: customPump,
    );
  }

  /// Expect the app to render a list of songs in [SongTile]s.
  void expectSongTiles(Iterable<Song> songs) {
    final songTiles = widgetList<SongTile>(find.byType(SongTile));
    final foundSongs = songTiles.map((e) => e.song);
    expect(foundSongs, songs);
  }

  /// From the home route, navigate to the player route.
  Future<void> expandPlayerRoute() async {
    await tap(find.byType(TrackPanel));
    await pumpAndSettle();
    expect(playerRouteController.value, 1.0);
  }

  /// From the home route, navigate to the queue screen in the player route.
  Future<void> openPlayerQueueScreen() async {
    await expandPlayerRoute();
    await flingFrom(Offset.zero, const Offset(-400.0, 0.0), 1000.0);
    await pumpAndSettle();
  }
}

final _testersLightTheme = <WidgetTester, bool>{};
final _testersPlayerInterfaceColorStyle = <WidgetTester, PlayerInterfaceColorStyle?>{};
const _defaultPlayerInterfaceColorStyle = PlayerInterfaceColorStyle.artColor;
const Object _defaultTagObject = Object();

/// Creates a golden test in two variants - in dark and light mode.
//
// TODO: weird, when run individually from IDE for some reason Dart extension throws
// "No tests match regular expression "^tabs_route idle_drawer( \(variant: .*\))?$"."
// report it here https://github.com/Dart-Code/Dart-Code/issues/new/choose
//
// More weird, just `testGoldens` itself works ok
@isTest
void testAppGoldens(
  String description,
  Future<void> Function(WidgetTester) test, {
  bool? skip,
  Object? tags = _defaultTagObject,
  Set<PlayerInterfaceColorStyle> playerInterfaceColorStylesToTest = const {_defaultPlayerInterfaceColorStyle},
  VoidCallback? initialization,
  VoidCallback? postInitialization,
  CustomPump? customGoldenPump,
}) {
  assert(playerInterfaceColorStylesToTest.isNotEmpty);
  for (final lightTheme in [false, true]) {
    final nonDefaultPlayerInterfaceColorStyle = playerInterfaceColorStylesToTest.length > 1 ||
        !playerInterfaceColorStylesToTest.contains(_defaultPlayerInterfaceColorStyle);

    for (final playerInterfaceColorStyle in playerInterfaceColorStylesToTest) {
      final testDescription = getTestDescription(
        lightTheme: lightTheme,
        playerInterfaceColorStyle: nonDefaultPlayerInterfaceColorStyle ? playerInterfaceColorStyle : null,
      );

      testGoldens(
        testDescription.buildDescription(description),
        (tester) async {
          final previousDeterministicCursor = EditableText.debugDeterministicCursor;
          addTearDown(() {
            EditableText.debugDeterministicCursor = previousDeterministicCursor;
            _testersLightTheme.remove(tester);
            _testersPlayerInterfaceColorStyle.remove(tester);
          });
          EditableText.debugDeterministicCursor = true;
          _testersLightTheme[tester] = lightTheme;
          if (nonDefaultPlayerInterfaceColorStyle) {
            _testersPlayerInterfaceColorStyle[tester] = playerInterfaceColorStyle;
          }
          return tester.runAppTest(
            initialization: () => initialization?.call(),
            postInitialization: () {
              ThemeControl.instance.setThemeLightMode(lightTheme);
              Settings.playerInterfaceColorStyle.set(playerInterfaceColorStyle);
              postInitialization?.call();
            },
            () => test(tester),
            goldenCaptureCallback: () => tester.screenMatchesGolden(
              Invoker.current!.liveTest.test.name.split(' | theme')[0].replaceAll(' ', '.'),
              customPump: customGoldenPump,
            ),
          );
        },
        tags: tags != _defaultTagObject ? tags : GoldenToolkit.configuration.tags,
      );
    }
  }
}

/// Signature used in [runGoldenAppTest].
typedef GoldenCaptureCallback = Future<void> Function(bool lightTheme);

Future<void> _screenMatchesGoldenWithTolerance(
  WidgetTester tester,
  String name, {
  bool? autoHeight,
  Finder? finder,
  CustomPump? customPump,
}) {
  goldenFileComparator = _TolerableFileComparator(path.join(
    (goldenFileComparator as LocalFileComparator).basedir.toString(),
    name,
  ));
  return screenMatchesGolden(
    tester,
    name,
    autoHeight: autoHeight,
    finder: finder,
    customPump: customPump,
  );
}

class _TolerableFileComparator extends LocalFileComparator {
  _TolerableFileComparator(String testFile) : super(Uri.parse(testFile));

  static const double _kGoldenDiffTolerance = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent > _kGoldenDiffTolerance) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    if (!result.passed) {
      print('A tolerable difference of ${result.diffPercent * 100}% was found when '
          'comparing $golden.');
    }
    return result.passed || result.diffPercent <= _kGoldenDiffTolerance;
  }
}

class FakeLicenseEntry extends LicenseEntry {
  const FakeLicenseEntry();

  @override
  Iterable<String> get packages => const ['test_package'];

  @override
  Iterable<LicenseParagraph> get paragraphs => const [
        LicenseParagraph('test paragraph 1', 0),
        LicenseParagraph('test paragraph 2', 0),
        LicenseParagraph('test paragraph 3', 0),
        LicenseParagraph('test paragraph 4', 0),
        LicenseParagraph('test paragraph 5', 0),
      ];
}

class FakeSystemUiStyleController implements SystemUiStyleController {
  @override
  Curve curve = Curves.linear;

  @override
  Duration duration = Duration.zero;

  @override
  SystemUiOverlayStyle actualUi = const SystemUiOverlayStyle();

  @override
  SystemUiOverlayStyle lastUi = const SystemUiOverlayStyle();

  @override
  Stream<SystemUiOverlayStyle> get onUiChange => const Stream.empty();

  @override
  Future<void> animateSystemUiOverlay({
    SystemUiOverlayStyle? from,
    required SystemUiOverlayStyle to,
    Curve? curve,
    Duration? duration,
  }) async {
    setSystemUiOverlay(to);
  }

  @override
  void setSystemUiOverlay(SystemUiOverlayStyle ui) {
    actualUi = ui;
    lastUi = ui;
  }
}
