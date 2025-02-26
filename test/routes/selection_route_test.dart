import 'package:flutter/material.dart';

import '../test.dart';

void main() {
  group('playlist add element selection screen', () {
    testWidgets('hides config button on insertion order config screen', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlistWith()));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.settings_rounded).hitTestable(), findsOneWidget);

        // Open insertion settings
        await tester.tap(find.descendant(
          of: find.byType(SelectionActionsBar),
          matching: find.byIcon(Icons.settings_rounded).hitTestable(),
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.settings_rounded).hitTestable(), findsNothing);

        // Close insertion settings
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).hitTestable());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.settings_rounded).hitTestable(), findsOneWidget);

        // The `NFMarquee` widget starts a timer for 2 seconds before it starts it's animation,
        // at which point it can be disposed. Let that time pass.
        await tester.pump(const Duration(seconds: 2));
      });
    });

    testWidgets('allows to finish insertion from insertion order config screen', (WidgetTester tester) async {
      final song0 = songWith(id: 0, title: 'Song 0');
      final song1 = songWith(id: 1, title: 'Song 1');
      final playlist = playlistWith(songIds: [song0.id]);
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [song0, song1];
        FakeSweyerPluginPlatform.instance.playlists = [playlist];
      }, () async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlist));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.done)).enabled, isFalse);

        // Open insertion settings
        await tester.tap(find.descendant(
          of: find.byType(SelectionActionsBar),
          matching: find.byIcon(Icons.settings_rounded).hitTestable(),
        ));
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.done)).enabled, isFalse);

        // Close insertion settings
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).hitTestable());
        await tester.pumpAndSettle();

        // Select Song 1
        await tester.tap(find.descendant(
            of: find.ancestor(of: find.text(song1.title), matching: find.byType(SongTile)),
            matching: find.byIcon(Icons.add_rounded)));
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.done)).enabled, isTrue);

        // Open insertion settings
        await tester.tap(find.descendant(
          of: find.byType(SelectionActionsBar),
          matching: find.byIcon(Icons.settings_rounded).hitTestable(),
        ));
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.done)).enabled, isTrue);

        // Finish insertion
        await tester.tap(find.ancestor(of: find.text(l10n.done), matching: find.byType(ElevatedButton)));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(SongTile, song1.title).hitTestable(), findsOneWidget);
        expect(playlist.songs, orderedEquals([song0, song1]));
      });
    });

    testWidgets('counts selection', (WidgetTester tester) async {
      final song0 = songWith(id: 0, title: 'Song 0');
      final song1 = songWith(id: 1, title: 'Song 1');
      final song2 = songWith(id: 2, title: 'Song 2');
      final playlist = playlistWith(songIds: [song0.id]);
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [song0, song1, song2];
        FakeSweyerPluginPlatform.instance.playlists = [playlist];
      }, () async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlist));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(SelectionCounter), matching: find.text('0')), findsOneWidget);
        expect(find.byIcon(Icons.settings_rounded).hitTestable(), findsOneWidget);

        // Select Song 1
        await tester.tap(find.descendant(
            of: find.ancestor(of: find.text(song1.title), matching: find.byType(SongTile)),
            matching: find.byIcon(Icons.add_rounded)));
        await tester.pumpAndSettle();
        expect(
            find.descendant(of: find.byType(SelectionCounter), matching: find.text('1')).hitTestable(), findsOneWidget);
        expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.done)).enabled, isTrue);

        // Select Song 2
        await tester.tap(find.descendant(
            of: find.ancestor(of: find.text(song2.title), matching: find.byType(SongTile)),
            matching: find.byIcon(Icons.add_rounded)));
        await tester.pumpAndSettle();
        expect(
            find.descendant(of: find.byType(SelectionCounter), matching: find.text('2')).hitTestable(), findsOneWidget);
        expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, l10n.done)).enabled, isTrue);

        // The `NFMarquee` widget starts a timer for 2 seconds before it starts it's animation,
        // at which point it can be disposed. Let that time pass.
        await tester.pump(const Duration(seconds: 2));
      });
    });

    testWidgets('inserts at the end per default', (WidgetTester tester) async {
      final song0 = songWith(id: 0, title: 'Song 0');
      final song1 = songWith(id: 1, title: 'Song 1');
      final song2 = songWith(id: 2, title: 'Song 2');
      final playlist = playlistWith(songIds: [song0.id, song1.id]);
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [song0, song1, song2];
        FakeSweyerPluginPlatform.instance.playlists = [playlist];
      }, () async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlist));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.settings_rounded).hitTestable(), findsOneWidget);

        // Select Song 2
        await tester.tap(find.descendant(
            of: find.ancestor(of: find.text(song2.title), matching: find.byType(SongTile)),
            matching: find.byIcon(Icons.add_rounded)));
        await tester.pumpAndSettle();

        // Add selected Song 2 to playlist
        await tester.tap(find.ancestor(of: find.text(l10n.done), matching: find.byType(ElevatedButton)));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(SongTile, song2.title).hitTestable(), findsOneWidget);
        expect(playlist.songs, orderedEquals([song0, song1, song2]));

        // The `NFMarquee` widget starts a timer for 2 seconds before it starts it's animation,
        // at which point it can be disposed. Let that time pass.
        await tester.pump(const Duration(seconds: 2));
      });
    });

    testWidgets('allows insertion at the beginning', (WidgetTester tester) async {
      final song0 = songWith(id: 0, title: 'Song 0');
      final song1 = songWith(id: 1, title: 'Song 1');
      final song2 = songWith(id: 2, title: 'Song 2');
      final playlist = playlistWith(songIds: [song0.id, song1.id]);
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [song0, song1, song2];
        FakeSweyerPluginPlatform.instance.playlists = [playlist];
      }, () async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlist));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.settings_rounded).hitTestable(), findsOneWidget);

        // Select Song 2
        await tester.tap(find.descendant(
            of: find.ancestor(of: find.text(song2.title), matching: find.byType(SongTile)),
            matching: find.byIcon(Icons.add_rounded)));
        await tester.pumpAndSettle();

        // Open insertion settings
        await tester.tap(find.descendant(
          of: find.byType(SelectionActionsBar),
          matching: find.byIcon(Icons.settings_rounded).hitTestable(),
        ));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<InListContentAction>(find.widgetWithText(InListContentAction, l10n.insertAtTheBeginning))
                .color,
            isNot(FakeThemeControl.instance.theme.colorScheme.primary));

        // Select insert at beginning
        await tester.tap(find.widgetWithText(InListContentAction, l10n.insertAtTheBeginning));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<InListContentAction>(find.widgetWithText(InListContentAction, l10n.insertAtTheBeginning))
                .color,
            FakeThemeControl.instance.theme.colorScheme.primary);

        // Add selected Song 2 to playlist
        await tester.tap(find.ancestor(of: find.text(l10n.done), matching: find.byType(ElevatedButton)));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(SongTile, song2.title).hitTestable(), findsOneWidget);
        expect(playlist.songs, orderedEquals([song2, song0, song1]));
      });
    });

    testWidgets('allows insertion at any index', (WidgetTester tester) async {
      final song0 = songWith(id: 0, title: 'Song 0');
      final song1 = songWith(id: 1, title: 'Song 1');
      final song2 = songWith(id: 2, title: 'Song 2');
      final playlist = playlistWith(songIds: [song0.id, song1.id]);
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [song0, song1, song2];
        FakeSweyerPluginPlatform.instance.playlists = [playlist];
      }, () async {
        HomeRouter.instance.goto(HomeRoutes.factory.content(playlist));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.settings_rounded).hitTestable(), findsOneWidget);

        // Select Song 2
        await tester.tap(find.descendant(
            of: find.ancestor(of: find.text(song2.title), matching: find.byType(SongTile)),
            matching: find.byIcon(Icons.add_rounded)));
        await tester.pumpAndSettle();

        // Open insertion settings
        await tester.tap(find.descendant(
          of: find.byType(SelectionActionsBar),
          matching: find.byIcon(Icons.settings_rounded).hitTestable(),
        ));
        await tester.pumpAndSettle();
        expect(tester.widget<SongTile>(find.widgetWithText(SongTile, song0.title).hitTestable()).backgroundColor,
            isNot(FakeThemeControl.instance.theme.colorScheme.primary));

        // Select Song 0
        await tester.tap(find.widgetWithText(SongTile, song0.title).hitTestable());
        await tester.pumpAndSettle();
        expect(tester.widget<SongTile>(find.widgetWithText(SongTile, song0.title).hitTestable()).backgroundColor,
            FakeThemeControl.instance.theme.colorScheme.primary);

        // Add selected Song 2 to playlist
        await tester.tap(find.ancestor(of: find.text(l10n.done), matching: find.byType(ElevatedButton)));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(SongTile, song2.title).hitTestable(), findsOneWidget);
        expect(playlist.songs, orderedEquals([song0, song2, song1]));
      });
    });
  });

  group('common selection actions on all tabs', () {
    final album0 = albumWith(id: 0);
    final album1 = albumWith(id: 1);
    final album2 = albumWith(id: 2);
    final artist0 = artistWith(id: 0);
    final artist1 = artistWith(id: 1);
    final artist2 = artistWith(id: 2);
    final song0 = songWith(id: 0, title: 'Song 0', albumId: album0.id, artistId: artist0.id);
    final song1 = songWith(id: 1, title: 'Song 1', albumId: album1.id, artistId: artist1.id);
    final song2 = songWith(id: 2, title: 'Song 2', albumId: album2.id, artistId: artist2.id);
    final playlist0 = playlistWith(id: 0, songIds: [song0.id]);
    final playlist1 = playlistWith(id: 1, songIds: [song1.id]);
    final playlist2 = playlistWith(id: 2, songIds: [song2.id]);

    for (final (tabName, contentType) in [
      ('tracks', ContentType.song),
      ('album', ContentType.album),
      ('playlists', ContentType.playlist),
      ('artists', ContentType.artist),
    ]) {
      testWidgets('allows selecting all and deselecting all on the $tabName tab', (WidgetTester tester) async {
        await tester.runAppTest(initialization: () {
          FakeSweyerPluginPlatform.instance.songs = [song0, song1, song2];
          FakeSweyerPluginPlatform.instance.albums = [album0, album1, album2];
          FakeSweyerPluginPlatform.instance.playlists = [playlist0, playlist1, playlist2];
          FakeSweyerPluginPlatform.instance.artists = [artist0, artist1, artist2];
        }, () async {
          // Select tab
          await tester.tap(find.ancestor(of: find.byIcon(contentType.icon).first, matching: find.byType(TabCollapse)));
          await tester.pumpAndSettle();

          // Select first content
          await tester.longPress(find.byType(ContentTile).first);
          await tester.pumpAndSettle();

          final selectionController = ContentControl.instance.selectionNotifier.value!;
          expect(selectionController.inSelection, true);
          expect(selectionController.data.length, 1);
          expect(find.descendant(of: find.byType(SelectionCounter), matching: find.text('1')).hitTestable(),
              findsOneWidget);

          // Select all
          await tester.tap(find.byType(SelectAllSelectionAction).last);
          await tester.pumpAndSettle();

          final numElements = ContentControl.instance.getContent(contentType).length;
          expect(selectionController.inSelection, true);
          expect(selectionController.data.length, numElements);
          expect(find.descendant(of: find.byType(SelectionCounter), matching: find.text('$numElements')).hitTestable(),
              findsOneWidget);

          // Deselect all
          await tester.tap(find.byType(SelectAllSelectionAction).last);
          await tester.pumpAndSettle();

          expect(selectionController.inSelection, false);
          expect(selectionController.data.length, 0);
          expect(find.byType(SelectAllSelectionAction).hitTestable(), findsNothing);
          expect(find.byType(SelectionCounter).hitTestable(), findsNothing);
        });
      });
    }
  });
}
