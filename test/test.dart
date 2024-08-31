import 'dart:io';

export 'package:sweyer/sweyer.dart';
export 'package:flutter/foundation.dart';
export 'package:flutter_test/flutter_test.dart';
import 'package:android_content_provider/android_content_provider.dart';
import 'package:clock/clock.dart';
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

/// Sets the fake data providers and initializes the app state.
///
/// The [configureFakes] callback can be used to modify the fake data providers
/// before the controls will load it.
Future<void> setUpAppTest([VoidCallback? configureFakes]) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.window.physicalSizeTestValue = kScreenSize * kScreenPixelRatio;
  binding.window.devicePixelRatioTestValue = kScreenPixelRatio;

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
  DeviceInfoControl.instance.dispose();
  ContentControl.instance.dispose();
  AppRouter.instance = AppRouter();

  // Set up fakes
  SystemUiStyleController.instance = FakeSystemUiStyleController();
  Backend.instance = FakeBackend();
  DeviceInfoControl.instance = FakeDeviceInfoControl();
  FavoritesControl.instance = FakeFavoritesControl();
  PermissionsChannelObserver(binding); // Grant all permissions by default.
  SweyerPluginPlatform.instance = FakeSweyerPluginPlatform(binding);
  QueueControl.instance = FakeQueueControl();
  ThemeControl.instance = FakeThemeControl();
  JustAudioPlatform.instance = MockJustAudio(binding);
  PackageInfoPlatform.instance = MethodChannelPackageInfo();
  PlayerInterfaceColorStyleControl.instance = PlayerInterfaceColorStyleControl();
  await FakeFirebaseApp.install(binding);
  binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall methodCall) async {
    return {
      'appName': constants.Config.applicationTitle,
      'packageName': 'com.nt4f04und.sweyer',
      'version': '1.0.0',
      'buildNumber': '0',
    };
  });
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_service.client.methods'), (MethodCall methodCall) async {
    return {};
  });
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.ryanheise.audio_service.handler.methods'), (MethodCall methodCall) async {
    return {};
  });
  binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.audio_session'),
      (MethodCall methodCall) async {
    return null;
  });
  binding.defaultBinaryMessenger.setMockMethodCallHandler(AndroidContentResolver.methodChannel,
      (MethodCall methodCall) async {
    return null;
  });
  binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
    if (methodCall.method == 'getTemporaryDirectory' || methodCall.method == 'getApplicationSupportDirectory') {
      Directory('./temp').createSync();
      return './temp';
    }
    return null;
  });
  binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.tekartik.sqflite'),
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
  if (binding.inTest) {
    await binding.runAsync(() => ContentControl.instance.init());
  } else {
    await ContentControl.instance.init();
  }

  // Called in the [App] widget
  NFWidgets.init(
    navigatorKey: AppRouter.instance.navigatorKey,
    routeObservers: [routeObserver, homeRouteObserver],
  );
}

extension WidgetTesterExtension on WidgetTester {
  /// A template for this:
  ///  1. pumps the app
  ///  2. runs the test from the [callback]
  ///  3. stops and disposes the player
  ///  4. optionally, runs [goldenCaptureCallback]. It would time out if was ran before player is disposed in [callback].
  ///  5. un-pumps the screen
  Future<void> runAppTest(AsyncCallback callback, {AsyncCallback? goldenCaptureCallback}) async {
    await withClock(binding.clock, () async {
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
      await runAsync(() async {
        // Don't leak player state between tests.
        // Delay needed for proper disposal in some tests.
        await Future.delayed(const Duration(milliseconds: 1));
        await MusicPlayer.instance.stop();
        await MusicPlayer.instance.dispose();
      });
      await goldenCaptureCallback?.call();
      // Un-pump, in case we have any real animations running,
      // so the pumpAndSettle on the next line doesn't hang on.
      await pumpWidget(const SizedBox());
      // Wait for ui animations.
      await pumpAndSettle();
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
}) {
  assert(playerInterfaceColorStylesToTest.isNotEmpty);
  final previousDeterministicCursor = EditableText.debugDeterministicCursor;
  try {
    EditableText.debugDeterministicCursor = true;
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
            try {
              ThemeControl.instance.setThemeLightMode(lightTheme);
              Settings.playerInterfaceColorStyle.set(playerInterfaceColorStyle);
              _testersLightTheme[tester] = lightTheme;
              if (nonDefaultPlayerInterfaceColorStyle) {
                _testersPlayerInterfaceColorStyle[tester] = playerInterfaceColorStyle;
              }
              return await test(tester);
            } finally {
              _testersLightTheme.remove(tester);
              _testersPlayerInterfaceColorStyle.remove(tester);
            }
          },
          tags: tags != _defaultTagObject ? tags : GoldenToolkit.configuration.tags,
        );
      }
    }
  } finally {
    EditableText.debugDeterministicCursor = previousDeterministicCursor;
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
