import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../observer/observer.dart';
import '../test.dart';

void main() {
  setUp(() async {
    await setUpAppTest();
  });

  group('home_route', () {
    testAppGoldens('permissions_screen', (WidgetTester tester) async {
      late PermissionsChannelObserver permissionsObserver;
      await setUpAppTest(() {
        permissionsObserver = PermissionsChannelObserver(tester.binding);
        permissionsObserver.setPermission(Permission.storage, PermissionStatus.denied);
      });
      await tester.runAppTest(() async {
        await tester.tap(find.text(l10n.grant));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'home_route.permissions_screen'));
    });

    testAppGoldens('searching_screen', (WidgetTester tester) async {
      ContentControl.instance.dispose();
      final fake = FakeContentControl();
      ContentControl.instance = fake;
      fake.init();
      // Fake ContentControl.init in a way to trigger the home screen rebuild
      fake.initializing = true;
      fake.stateNullable = ContentState();
      fake.disposed.value = false;

      await tester.runAppTest(() async {
        expect(find.byType(Spinner), findsOneWidget);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'home_route.searching_screen', customPump: (WidgetTester tester) async {
        await tester.pump(const Duration(milliseconds: 400));
      }));
    });

    testAppGoldens('no_songs_screen', (WidgetTester tester) async {
      await setUpAppTest(() {
        FakeContentChannel.instance.songs = [];
      });
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'home_route.no_songs_screen'));
    });
  });

  group('tabs_route', () {
    testAppGoldens('drawer', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.drawer'));
    });

    testAppGoldens('songs_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.songs_tab'));
    });
  
    testAppGoldens('albums_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Album.icon));
        await tester.pumpAndSettle();
        expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsOneWidget);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.albums_tab'));
    });

    testAppGoldens('playlists_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Playlist.icon));
        await tester.pumpAndSettle();
        expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsOneWidget);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.playlists_tab'));
    });

    testAppGoldens('artists_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Artist.icon));
        await tester.pumpAndSettle();
        expect(find.byType(typeOf<ArtistTile>()), findsOneWidget);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.artists_tab'));
    });

    testAppGoldens('sort_feature_dialog', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.text(
          l10n.sortFeature<Song>(
            ContentControl.instance.state.sorts.getValue<Song>()!.feature as SongSortFeature,
          )
        ));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.sort_feature_dialog'));
    });
    
    testAppGoldens('selection_songs_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(SongTile));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.selection_songs_tab'));
    });

    testAppGoldens('selection_deletion_dialog_songs_tab', (WidgetTester tester) async {
      final List<Song> songs = List.unmodifiable(List.generate(10, (index) => songWith(id: index)));
      await tester.runAsync(() async {
        await setUpAppTest(() {
          final fake = FakeDeviceInfoControl();
          DeviceInfoControl.instance = fake;
          fake.sdkInt = 29;
          FakeContentChannel.instance.songs = songs.toList();
        });
      });
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(SongTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SelectAllSelectionAction).last);
        await tester.tap(find.byType(DeleteSongsAppBarAction).last);
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'tabs_route.selection_deletion_dialog_songs_tab'));
    });
  });

  group('persistent_queue_route', () {
    testAppGoldens('album_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content<Album>(albumWith()));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'persistent_queue_route.album_route'));
    });

    testAppGoldens('playlist_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content<Playlist>(playlistWith()));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'persistent_queue_route.playlist_route'));
    });
  });

  group('selection_route', () {
    testAppGoldens('selection_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content<Playlist>(playlistWith()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'selection_route.selection_route'));
    });

    testAppGoldens('selection_route_settings', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content<Playlist>(playlistWith()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
            of: find.byType(SelectionRoute),
            matching: find.byIcon(Icons.settings_rounded),
        ));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'selection_route.selection_settings'));
    });
  });

  group('artist_route', () {
    testAppGoldens('artist_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content<Artist>(artistWith()));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'artist_route.artist_route'));
    });
  });

  group('artist_content_route', () {
    testAppGoldens('artist_content_route_songs', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.artistContent<Song>(artistWith(), [songWith()]));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'artist_content_route.artist_content_route_songs'));
    });
  });

  group('player_route', () {
    testAppGoldens('player_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(SongTile));
        await tester.pumpAndSettle();
        expect(playerRouteController.value, 1.0);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'player_route.player_route'));
    });

    testAppGoldens('queue_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(SongTile));
        await tester.pumpAndSettle();
        expect(playerRouteController.value, 1.0);
        await tester.flingFrom(Offset.zero, const Offset(-400.0, 0.0), 1000.0);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'player_route.queue_route'));
    });
  });

  group('search_route', () {
    testAppGoldens('search_suggestions_empty', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'search_route.search_suggestions_empty'));
    });

    testAppGoldens('search_suggestions', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        SearchHistory.instance.add('entry_1');
        SearchHistory.instance.add('entry_2');
        SearchHistory.instance.add('entry_3');
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'search_route.search_suggestions'));
    });

    testAppGoldens('search_suggestions_delete', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        SearchHistory.instance.add('entry_1');
        SearchHistory.instance.add('entry_2');
        SearchHistory.instance.add('entry_3');
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'search_route.search_suggestions_delete'));
    });

    testAppGoldens('results', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 't');
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'search_route.results'));
    });

    testAppGoldens('results_empty', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'some_query');
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'search_route.results_empty'));
    });
  });

  group('settings_route', () {
    testAppGoldens('settings_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'settings_route.settings_route'));
    });

    testAppGoldens('general_settings_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.general));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'settings_route.general_settings_route'));
    });

    testAppGoldens('theme_settings_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.theme));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'settings_route.theme_settings_route'));
    });

    testAppGoldens('licenses_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Licenses'));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'settings_route.licenses_route'));
    });

    testAppGoldens('license_details_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Licenses'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('test_package'));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden(tester, 'settings_route.license_details_route'));
    });
  });
}
