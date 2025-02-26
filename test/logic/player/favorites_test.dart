import 'package:flutter/material.dart';

import '../../test.dart';

void main() {
  final notFavoriteSong1 = songWith(id: 0, title: 'Song 0');
  final notFavoriteSong2 = songWith(id: 1, title: 'Song 1');
  final notFavoriteSong3 = songWith(id: 2, title: 'Song 2');
  final favoriteSong1 = songWith(id: 3, title: 'Song 3', isFavoriteInMediaStore: true);
  final favoriteSong2 = songWith(id: 4, title: 'Song 4', isFavoriteInMediaStore: true);
  final favoriteSong3 = songWith(id: 5, title: 'Song 5', isFavoriteInMediaStore: true);

  Future<void> setupDefaultFavouriteState(TestWidgetsFlutterBinding binding) async {
    await Settings.useMediaStoreForFavoriteSongs.set(false);
    await binding.pump(const Duration(seconds: 1)); // Wait for the listener in FavoriteControl to execute
    await FakeFavoritesControl.instance
        .setFavorite(contentTuple: ContentTuple(songs: [favoriteSong1, favoriteSong2, favoriteSong3]), value: true);
    await FakeFavoritesControl.instance.setFavorite(
        contentTuple: ContentTuple(songs: [notFavoriteSong1, notFavoriteSong2, notFavoriteSong3]), value: false);
  }

  group('MediaStore', () {
    testWidgets('Updates the MediaStore correctly when resolving conflicts', (WidgetTester tester) async {
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [
          notFavoriteSong1,
          notFavoriteSong2,
          notFavoriteSong3,
          favoriteSong1,
          favoriteSong2,
          favoriteSong3,
        ];
      }, () async {
        await setupDefaultFavouriteState(tester.binding);
        final localFavoriteAndMediaStoreSong = favoriteSong1;
        final notFavoriteInBothSong = notFavoriteSong1;
        final localFavoriteButNotInMediaStoreKeepSong = notFavoriteSong2;
        final localFavoriteButNotInMediaStoreUnFavorSong = notFavoriteSong3;
        final mediaStoreFavoriteButNotLocalKeepSong = favoriteSong2;
        final mediaStoreFavoriteButNotLocalUnFavorSong = favoriteSong3;
        await FakeFavoritesControl.instance.setFavorite(
          contentTuple: ContentTuple(
            songs: [localFavoriteButNotInMediaStoreKeepSong, localFavoriteButNotInMediaStoreUnFavorSong],
          ),
          value: true,
        );
        await FakeFavoritesControl.instance.setFavorite(
          contentTuple: ContentTuple(
            songs: [mediaStoreFavoriteButNotLocalKeepSong, mediaStoreFavoriteButNotLocalUnFavorSong],
          ),
          value: false,
        );
        await Settings.useMediaStoreForFavoriteSongs.set(true);
        await tester.pumpAndSettle();
        Finder findInDialog(Finder finder) => find.descendant(of: find.byType(AlertDialog), matching: finder);
        expect(findInDialog(find.text(l10n.resolveConflict)), findsOneWidget);
        expect(findInDialog(find.text(notFavoriteInBothSong.title)), findsNothing);
        expect(findInDialog(find.text(localFavoriteAndMediaStoreSong.title)), findsNothing);
        expect(findInDialog(find.text(localFavoriteButNotInMediaStoreKeepSong.title)), findsOneWidget);
        expect(findInDialog(find.text(localFavoriteButNotInMediaStoreUnFavorSong.title)), findsOneWidget);
        expect(findInDialog(find.text(mediaStoreFavoriteButNotLocalKeepSong.title)), findsOneWidget);
        expect(findInDialog(find.text(mediaStoreFavoriteButNotLocalUnFavorSong.title)), findsOneWidget);

        // Unfavor the locally favored song
        await tester.tap(findInDialog(find.text(localFavoriteButNotInMediaStoreUnFavorSong.title)));
        // Favor the MediaStore favored song
        await tester.tap(findInDialog(find.text(mediaStoreFavoriteButNotLocalKeepSong.title)));
        await tester.tap(findInDialog(find.text(l10n.accept)));
        await tester.pumpAndSettle();
        expect(FakeSweyerPluginPlatform.instance.favoriteRequestLog, [
          FavoriteLogEntry({mediaStoreFavoriteButNotLocalUnFavorSong}, false),
          FavoriteLogEntry({localFavoriteButNotInMediaStoreKeepSong}, true),
        ]);
        expect(FakeFavoritesControl.instance.isFavorite(localFavoriteAndMediaStoreSong), true);
        expect(FakeFavoritesControl.instance.isFavorite(notFavoriteInBothSong), false);
        expect(FakeFavoritesControl.instance.isFavorite(localFavoriteButNotInMediaStoreKeepSong), true);
        expect(FakeFavoritesControl.instance.isFavorite(localFavoriteButNotInMediaStoreUnFavorSong), false);
        expect(FakeFavoritesControl.instance.isFavorite(mediaStoreFavoriteButNotLocalKeepSong), true);
        expect(FakeFavoritesControl.instance.isFavorite(mediaStoreFavoriteButNotLocalUnFavorSong), false);
      });
    });

    testWidgets("When switching to MediaStore, doesn't show resolve conflict dialog with no conflicts",
        (WidgetTester tester) async {
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [
          notFavoriteSong1,
          notFavoriteSong2,
          notFavoriteSong3,
          favoriteSong1,
          favoriteSong2,
          favoriteSong3,
        ];
      }, () async {
        await setupDefaultFavouriteState(tester.binding);
        await Settings.useMediaStoreForFavoriteSongs.set(true);
        await tester.pumpAndSettle();
        expect(find.text(l10n.resolveConflict), findsNothing);
      });
    });

    testWidgets('Allows to cancel when resolving conflicts', (WidgetTester tester) async {
      await tester.runAppTest(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [
          notFavoriteSong1,
          notFavoriteSong2,
          notFavoriteSong3,
          favoriteSong1,
          favoriteSong2,
          favoriteSong3,
        ];
      }, () async {
        await setupDefaultFavouriteState(tester.binding);
        await FakeFavoritesControl.instance
            .setFavorite(contentTuple: ContentTuple(songs: [notFavoriteSong1]), value: true);
        await Settings.useMediaStoreForFavoriteSongs.set(true);
        await tester.pumpAndSettle();
        expect(find.text(l10n.resolveConflict), findsOneWidget);
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(FakeSweyerPluginPlatform.instance.favoriteRequestLog, []);
        expect(Settings.useMediaStoreForFavoriteSongs.get(), false);
      });
    });

    test('Keeps favorites when switching form MediaStore to local', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      await binding.runAppTestWithoutUi(initialization: () {
        FakeSweyerPluginPlatform.instance.songs = [
          notFavoriteSong1,
          notFavoriteSong2,
          notFavoriteSong3,
          favoriteSong1,
          favoriteSong2,
          favoriteSong3,
        ];
      }, () async {
        await setupDefaultFavouriteState(binding);
        final favorSong = notFavoriteSong1;
        final unFavorSong = favoriteSong1;
        await Settings.useMediaStoreForFavoriteSongs.set(true);
        await binding.pump();
        await FakeFavoritesControl.instance.setFavorite(contentTuple: ContentTuple(songs: [favorSong]), value: true);
        await FakeFavoritesControl.instance.setFavorite(contentTuple: ContentTuple(songs: [unFavorSong]), value: false);
        await Settings.useMediaStoreForFavoriteSongs.set(false);
        await binding.pump();
        expect(FakeFavoritesControl.instance.isFavorite(unFavorSong), false);
        expect(FakeFavoritesControl.instance.isFavorite(notFavoriteSong2), false);
        expect(FakeFavoritesControl.instance.isFavorite(favorSong), true);
        expect(FakeFavoritesControl.instance.isFavorite(favoriteSong2), true);
      });
    });
  });
}
