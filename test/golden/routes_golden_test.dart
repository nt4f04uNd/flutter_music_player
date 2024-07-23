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
        permissionsObserver.setPermission(Permission.audio, PermissionStatus.denied);
      });
      await tester.runAppTest(() async {
        await tester.tap(find.text(l10n.grant));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('home_route.permissions_screen'));
    });

    testAppGoldens('searching_screen', (WidgetTester tester) async {
      ContentControl.instance.dispose();
      final fake = FakeContentControl();
      fake.init();
      // Fake ContentControl.init in a way to trigger the home screen rebuild
      fake.initializing = true;
      fake.stateNullable = ContentState();
      fake.disposed.value = false;

      await tester.runAppTest(() async {
        expect(find.byType(Spinner), findsOneWidget);
      },
          goldenCaptureCallback: () => tester.screenMatchesGolden(
                'home_route.searching_screen',
                customPump: (WidgetTester tester) async {
                  await tester.pump(const Duration(milliseconds: 400));
                },
              ));
    });

    testAppGoldens('no_songs_screen', (WidgetTester tester) async {
      await setUpAppTest(() {
        FakeSweyerPluginPlatform.instance.songs = [];
      });
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('home_route.no_songs_screen'));
    });

    testAppGoldens('init_error_screen', (WidgetTester tester) async {
      await setUpAppTest(() {
        CrashlyticsObserver(tester.binding, throwFatalErrors: false);
        FakeSweyerPluginPlatform.instance.songsFactory = () => throw TypeError();
      });
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('home_route.init_error_screen'));
    });
  });

  group('tabs_route', () {
    testAppGoldens('drawer', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.drawer'));
    });

    testAppGoldens('songs_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.songs_tab'));
    });

    testAppGoldens('albums_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(ContentType.album.icon));
        await tester.pumpAndSettle();
        expect(find.byType(typeOf<PersistentQueueTile<Album>>()), findsOneWidget);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.albums_tab'));
    });

    testAppGoldens('playlists_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(ContentType.playlist.icon));
        await tester.pumpAndSettle();
        expect(find.byType(typeOf<PersistentQueueTile<Playlist>>()), findsOneWidget);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.playlists_tab'));
    });

    testAppGoldens('artists_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(ContentType.artist.icon));
        await tester.pumpAndSettle();
        expect(find.byType(typeOf<ArtistTile>()), findsOneWidget);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.artists_tab'));
    });

    testAppGoldens('sort_feature_dialog', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.text(
          l10n.sortFeature(
            ContentType.song,
            ContentControl.instance.state.sorts.get(ContentType.song).feature,
          ),
        ));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.sort_feature_dialog'));
    });

    testAppGoldens('selection_songs_tab', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(SongTile));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.selection_songs_tab'));
    });

    testAppGoldens('selection_deletion_dialog_songs_tab', (WidgetTester tester) async {
      final List<Song> songs = List.unmodifiable(List.generate(10, (index) => songWith(id: index)));
      await setUpAppTest(() {
        final fake = FakeDeviceInfoControl();
        DeviceInfoControl.instance = fake;
        fake.sdkInt = 29;
        FakeSweyerPluginPlatform.instance.songs = songs.toList();
      });
      await tester.runAppTest(() async {
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(SongTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SelectAllSelectionAction).last);
        await tester.tap(find.byType(DeleteSongsAppBarAction).last);
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.selection_deletion_dialog_songs_tab'));
    });

    testAppGoldens('scroll_labels', (WidgetTester tester) async {
      await setUpAppTest(() {
        FakeSweyerPluginPlatform.instance.songs =
            List.generate(26, (index) => songWith(id: index, title: String.fromCharCode('A'.codeUnitAt(0) + index)));
      });
      await tester.runAppTest(() async {
        ContentControl.instance.sort(
            contentType: ContentType.song, sort: const SongSort(feature: SongSortFeature.title));
        await tester.pumpAndSettle();

        final listRect = tester.getRect(find.byType(ContentListView).hitTestable());
        final gesture = await tester.startGesture(Offset(listRect.right - 20, listRect.bottom - 20));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await gesture.moveBy(const Offset(0, -20));
        }
        await tester.pumpAndSettle();
        // Do not end the gesture, otherwise the labels will disappear
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('tabs_route.scroll_labels'));
    });
  });

  group('persistent_queue_route', () {
    testAppGoldens('album_route', (WidgetTester tester) async {
      await setUpAppTest(() {
        FakeSweyerPluginPlatform.instance.songs = [
          songWith(id: 0, track: null, title: 'Null Song 1'),
          songWith(id: 5, track: null, title: 'Null Song 2'),
          songWith(id: 3, track: '1', title: 'First Song'),
          songWith(id: 2, track: '2', title: 'Second Song'),
          songWith(id: 4, track: '3', title: 'Third Song'),
          songWith(id: 1, track: '4', title: 'Fourth Song'),
        ];
      });
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(albumWith()));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('persistent_queue_route.album_route'));
    });

    testAppGoldens('playlist_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlistWith()));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('persistent_queue_route.playlist_route'));
    });
  });

  group('selection_route', () {
    testAppGoldens('selection_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlistWith()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('selection_route.selection_route'));
    });

    testAppGoldens('selection_route_settings', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlistWith()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
          of: find.byType(SelectionActionsBar),
          matching: find.byIcon(Icons.settings_rounded),
        ));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('selection_route.selection_route_settings'));
    });
  });

  group('artist_route', () {
    testAppGoldens('artist_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(artistWith()));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('artist_route.artist_route'));
    });
  });

  group('artist_content_route', () {
    testAppGoldens('artist_content_route_songs', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.artistContent<Song>(artistWith(), [songWith()]));
        await tester.pumpAndSettle();
      },
          goldenCaptureCallback: () => tester.screenMatchesGolden(
                'artist_content_route.artist_content_route_songs',
              ));
    });
  });

  group('player_route', () {
    testAppGoldens('player_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(SongTile));
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(playerRouteController.value, 1.0);
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('player_route.player_route'));
    }, playerInterfaceColorStylesToTest: PlayerInterfaceColorStyle.values.toSet());

    testAppGoldens('queue_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.openPlayerQueueScreen();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('player_route.queue_route'));
    }, playerInterfaceColorStylesToTest: PlayerInterfaceColorStyle.values.toSet());

    testAppGoldens('queue_route_selection', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.openPlayerQueueScreen();
        await tester.longPress(find.descendant(
          of: find.byType(PlayerRoute),
          matching: find.byType(SongTile),
        ));
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('player_route.queue_route_selection'));
    }, playerInterfaceColorStylesToTest: PlayerInterfaceColorStyle.values.toSet());
  });

  group('search_route', () {
    testAppGoldens('search_suggestions_empty', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('search_route.search_suggestions_empty'));
    });

    testAppGoldens('search_suggestions', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        SearchHistory.instance.add('entry_1');
        SearchHistory.instance.add('entry_2');
        SearchHistory.instance.add('entry_3');
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('search_route.search_suggestions'));
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
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('search_route.search_suggestions_delete'));
    });

    testAppGoldens('results', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 't');
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('search_route.results'));
    });

    testAppGoldens('results_empty', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byIcon(Icons.search_rounded));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'some_query');
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('search_route.results_empty'));
    });
  });

  group('settings_route', () {
    testAppGoldens('settings_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('settings_route.settings_route'));
    });

    testAppGoldens('general_settings_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.general));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('settings_route.general_settings_route'));
    });

    testAppGoldens('general_settings_favorite_conflict_dialog', (WidgetTester tester) async {
      final localFavoriteAndMediaStoreSong = songWith(id: 1, isFavoriteInMediaStore: true);
      final localFavoriteButNotInMediaStoreSong = songWith(id: 2, title: 'Local only favorite');
      final mediaStoreFavoriteButNotLocalSong =
          songWith(id: 3, isFavoriteInMediaStore: true, title: 'MediaStore only favorite');
      await setUpAppTest(() {
        FakeSweyerPluginPlatform.instance.songs = [
          songWith(),
          localFavoriteAndMediaStoreSong,
          localFavoriteButNotInMediaStoreSong,
          mediaStoreFavoriteButNotLocalSong,
        ];
      });
      await tester.runAppTest(
        () async {
          await Settings.useMediaStoreForFavoriteSongs.set(false);
          await tester.pumpAndSettle(); // Wait for the listener in FavoriteControl to execute
          await FakeFavoritesControl.instance.setFavorite(
            contentTuple: ContentTuple(songs: [localFavoriteAndMediaStoreSong, localFavoriteButNotInMediaStoreSong]),
            value: true,
          );
          await FakeFavoritesControl.instance.setFavorite(
            contentTuple: ContentTuple(songs: [mediaStoreFavoriteButNotLocalSong]),
            value: false,
          );
          await tester.tap(find.byType(AnimatedMenuCloseButton));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.settings));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.general));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.useMediaStoreForFavoriteSongsSetting));
          await tester.pumpAndSettle();
        },
        goldenCaptureCallback: () =>
            tester.screenMatchesGolden('settings_route.general_settings_favorite_conflict_dialog'),
      );
    });

    testAppGoldens('theme_settings_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.theme));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('settings_route.theme_settings_route'));
    });

    testAppGoldens('licenses_route', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        await tester.tap(find.byType(AnimatedMenuCloseButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.settings));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Licenses'));
        await tester.pumpAndSettle();
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('settings_route.licenses_route'));
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
      }, goldenCaptureCallback: () => tester.screenMatchesGolden('settings_route.license_details_route'));
    });
  });
}
