import 'dart:async';

import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sweyer/constants.dart';
import 'package:sweyer/routes/settings_route/theme_settings.dart';
import 'package:sweyer/logic/app_widget.dart';

import '../observer/app_widget.dart';
import '../observer/observer.dart';
import '../test.dart';

void main() {
  setUp(() async {
    await setUpAppTest();
  });

  group('permissions screen', () {
    testWidgets('shows if no permissions were granted and pressing the button requests permissions',
        (WidgetTester tester) async {
      late PermissionsChannelObserver permissionsObserver;
      await setUpAppTest(() {
        permissionsObserver = PermissionsChannelObserver(tester.binding);
        permissionsObserver.setPermission(Permission.storage, PermissionStatus.denied);
        permissionsObserver.setPermission(Permission.audio, PermissionStatus.denied);
      });
      await tester.runAppTest(() async {
        expect(permissionsObserver.checkedPermissions, [Permission.storage],
            reason: 'Should always check the storage and audio permission on startup');
        expect(find.byType(Home), findsNothing, reason: 'Permissions are not granted yet');
        final permissionGrantCompleter = Completer<PermissionStatus>();
        permissionsObserver.setPermissionResolvable(Permission.storage, () => permissionGrantCompleter.future);
        await tester.tap(find.text(l10n.grant));
        expect(permissionsObserver.requestedPermissions, [Permission.storage, Permission.audio]);
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget,
            reason: 'Indicate while waiting for the permission to be granted');
        permissionGrantCompleter.complete(PermissionStatus.granted);
        await tester.pumpAndSettle();
        expect(find.byType(Home), findsOneWidget);
      });
    });

    /// On Android 13+ the storage permission is removed and reports as permanentlyDenied.
    /// If the user granted audio permissions, we have access to the music
    /// and don't want to show the permission request screen.
    testWidgets('does not show when removed storage permission is permanently denied', (WidgetTester tester) async {
      late PermissionsChannelObserver permissionsObserver;
      await setUpAppTest(() {
        FakeDeviceInfoControl.instance.sdkInt = 33;
        permissionsObserver = PermissionsChannelObserver(tester.binding);
        permissionsObserver.setPermission(Permission.storage, PermissionStatus.permanentlyDenied);
        permissionsObserver.setPermission(Permission.audio, PermissionStatus.granted);
      });
      await tester.runAppTest(() async {
        expect(Permissions.instance.granted, true);
        expect(permissionsObserver.checkedPermissions, [Permission.audio]);
        expect(find.byType(Home), findsOneWidget, reason: 'Audio permissions was already granted');
      });
    });

    /// The audio permission is new in Android 13 and reports as permanentlyDenied on earlier versions.
    /// If the user granted storage permissions, we have access to the music
    /// and don't want to show the permission request screen.
    testWidgets('does not show when non-existent audio permission is permanently denied', (WidgetTester tester) async {
      late PermissionsChannelObserver permissionsObserver;
      await setUpAppTest(() {
        FakeDeviceInfoControl.instance.sdkInt = 32;
        permissionsObserver = PermissionsChannelObserver(tester.binding);
        permissionsObserver.setPermission(Permission.storage, PermissionStatus.granted);
        permissionsObserver.setPermission(Permission.audio, PermissionStatus.permanentlyDenied);
      });
      await tester.runAppTest(() async {
        expect(Permissions.instance.granted, true);
        expect(permissionsObserver.checkedPermissions, [Permission.storage]);
        expect(find.byType(Home), findsOneWidget, reason: 'Storage permissions was already granted');
      });
    });

    testWidgets('shows toast and opens settings when permissions are denied', (WidgetTester tester) async {
      late PermissionsChannelObserver permissionsObserver;
      await setUpAppTest(() {
        permissionsObserver = PermissionsChannelObserver(tester.binding);
        permissionsObserver.setPermission(Permission.storage, PermissionStatus.denied);
        permissionsObserver.setPermission(Permission.audio, PermissionStatus.denied);
      });
      await tester.runAppTest(() async {
        permissionsObserver.setPermission(Permission.storage, PermissionStatus.permanentlyDenied);
        permissionsObserver.setPermission(Permission.audio, PermissionStatus.permanentlyDenied);
        permissionsObserver.isOpeningSettingsSuccessful = false;
        final ToastChannelObserver toastObserver = ToastChannelObserver(tester);
        await tester.tap(find.text(l10n.grant));
        await tester.pumpAndSettle();
        expect(permissionsObserver.openSettingsRequests, 1);
        expect(toastObserver.toastMessagesLog, [l10n.allowAccessToExternalStorageManually, l10n.openAppSettingsError]);

        permissionsObserver.isOpeningSettingsSuccessful = true;
        await tester.tap(find.text(l10n.grant));
        expect(permissionsObserver.openSettingsRequests, 2);
        expect(toastObserver.toastMessagesLog, [
          l10n.allowAccessToExternalStorageManually,
          l10n.openAppSettingsError,
          l10n.allowAccessToExternalStorageManually
        ]);
      });
    });
  });

  testWidgets('searching screen - shows when permissions are granted and searching for tracks',
      (WidgetTester tester) async {
    // Use fake
    ContentControl.instance.dispose();
    final fake = FakeContentControl();
    fake.init();

    expect(Permissions.instance.granted, true);
    expect(ContentControl.instance.disposed.value, true);
    expect(ContentControl.instance.initializing, false);
    expect(ContentControl.instance.stateNullable, null);

    // Fake ContentControl.init in a way to trigger the home screen rebuild
    fake.initializing = true;
    fake.stateNullable = ContentState();
    fake.disposed.value = false;

    expect(ContentControl.instance.initializing, true);

    await tester.runAppTest(() async {
      // Expect appropriate ui
      expect(find.text(l10n.searchingForTracks), findsOneWidget);
      expect(find.byType(Spinner), findsOneWidget);
    });
  });

  testWidgets('home screen - shows when permissions are granted and not searching for tracks',
      (WidgetTester tester) async {
    late AppWidgetChannelObserver appWidgetChannelObserver;
    await tester.runAsync(() => tester.pump()); // Wait for widget events from old app start to process.
    await setUpAppTest(() {
      appWidgetChannelObserver = AppWidgetChannelObserver(tester.binding);
    });
    await tester.runAppTest(() async {
      expect(Permissions.instance.granted, true);
      expect(find.byType(Home), findsOneWidget);
      expect(
        tester.getRect(find.byType(TrackShowcase)).top,
        tester.getRect(find.byType(App)).height,
        reason: 'Player route must be offscreen',
      );
      await tester.runAsync(() => tester.pump()); // Wait for widget events from start to process.
      expect(appWidgetChannelObserver.saveWidgetDataLog, [("song", songWith().contentUri), ("playing", false)]);
      expect(appWidgetChannelObserver.updateWidgetRequests, [AppWidgetControl.appWidgetName]);
    });
  });

  testWidgets('no songs screen - shows when the library is empty and pressing the button performs refetching',
      (WidgetTester tester) async {
    // TODO: because of `MusicPlayer.instance.stop` at the end of `runAppTest`, this test will print an error in console, but not actually fail, because the exception is caught. Ideally I should somehow hide that
    await setUpAppTest(() {
      FakeSweyerPluginPlatform.instance.songs = [];
    });
    await tester.runAppTest(() async {
      expect(Permissions.instance.granted, true);
      expect(find.text(l10n.noMusic), findsOneWidget);

      // Test refresh
      FakeSweyerPluginPlatform.instance.songs = [songWith()];
      // Triggering refresh will cause a real async work
      await tester.runAsync(() {
        return tester.tap(find.text(l10n.refresh));
      });
      expect(ContentControl.instance.state.allSongs.songs, [songWith()]);
    });
  });

  testWidgets('app shows exit confirmation toast if enabled in the preferences', (WidgetTester tester) async {
    await Settings.confirmExitingWithBackButton.set(true);
    await tester.runAppTest(() async {
      final SystemChannelObserver systemObserver = SystemChannelObserver(tester);
      final ToastChannelObserver toastObserver = ToastChannelObserver(tester);
      await BackButtonInterceptor.popRoute();
      expect(toastObserver.toastMessagesLog, [l10n.pressOnceAgainToExit]);
      expect(systemObserver.closeRequests, 0, reason: 'The app must not close after showing the toast');
      await tester.binding.delayed(Config.backPressCloseTimeout + const Duration(milliseconds: 1));
      await BackButtonInterceptor.popRoute();
      expect(toastObserver.toastMessagesLog, [l10n.pressOnceAgainToExit, l10n.pressOnceAgainToExit],
          reason: 'The previous message timed out');
      expect(systemObserver.closeRequests, 0, reason: 'The app must not close after showing the toast');
      await tester.binding.delayed(Config.backPressCloseTimeout - const Duration(milliseconds: 1));
      await BackButtonInterceptor.popRoute();
      expect(toastObserver.toastMessagesLog, [l10n.pressOnceAgainToExit, l10n.pressOnceAgainToExit]);
      expect(systemObserver.closeRequests, 1);
    });
  });

  testWidgets('app does not ask for exit confirmation if disabled in the preferences', (WidgetTester tester) async {
    await Settings.confirmExitingWithBackButton.set(false);
    await tester.runAppTest(() async {
      final SystemChannelObserver systemObserver = SystemChannelObserver(tester);
      final ToastChannelObserver toastObserver = ToastChannelObserver(tester);
      await BackButtonInterceptor.popRoute();
      expect(toastObserver.toastMessagesLog, []);
      expect(systemObserver.closeRequests, 1);
    });
  });

  group('app does not overlap the track panel and the tab bar', () {
    testWidgets('for the normal text scale', (WidgetTester tester) async {
      await tester.runAppTest(() async {
        final tabBarTop = tester.getBottomLeft(find.byType(NFTabBar)).dy;
        final trackPanelTop =
            tester.getTopLeft(find.descendant(of: find.byType(PlayerRoute), matching: find.byType(TrackPanel))).dy;
        expect(tabBarTop, trackPanelTop);
      });
    });
    testWidgets('for large text scale', (WidgetTester tester) async {
      // TODO: Increase the scale factor once the other unrelated overflows are handled.
      tester.binding.platformDispatcher.textScaleFactorTestValue = 1.2; // 2.5;
      await tester.runAppTest(() async {
        final tabBarTop = tester.getBottomLeft(find.byType(NFTabBar)).dy;
        final trackPanelTop =
            tester.getTopLeft(find.descendant(of: find.byType(PlayerRoute), matching: find.byType(TrackPanel))).dy;
        expect(tabBarTop, trackPanelTop);
      });
    });
    testWidgets('for small text scale', (WidgetTester tester) async {
      tester.binding.platformDispatcher.textScaleFactorTestValue = 0.5;
      await tester.runAppTest(() async {
        final tabBarTop = tester.getBottomLeft(find.byType(NFTabBar)).dy;
        final trackPanelTop =
            tester.getTopLeft(find.descendant(of: find.byType(PlayerRoute), matching: find.byType(TrackPanel))).dy;
        expect(tabBarTop, trackPanelTop);
      });
    });
  });

  testWidgets('Allows changing settings when uninitialized and no permissions were granted',
      (WidgetTester tester) async {
    await setUpAppTest(() {
      PermissionsChannelObserver permissionsObserver = PermissionsChannelObserver(tester.binding);
      permissionsObserver.setPermission(Permission.storage, PermissionStatus.denied);
      permissionsObserver.setPermission(Permission.audio, PermissionStatus.denied);
    });
    await tester.runAppTest(() async {
      // Go to the settings
      await tester.tap(find.byType(SettingsButton));
      await tester.pumpAndSettle();

      // Go to the general settings page
      await tester.tap(find.text(staticl10n.general));
      await tester.pumpAndSettle();

      // Toggle all switch settings
      for (var setting in [
        staticl10n.confirmExitingWithBackButtonSetting,
        staticl10n.useMediaStoreForFavoriteSongsSetting,
      ]) {
        // Toggle switch
        await tester.tap(find.text(setting));
        await tester.pumpAndSettle();

        // Toggle switch back
        await tester.tap(find.text(setting));
        await tester.pumpAndSettle();
      }

      // Go to the theme settings page
      await BackButtonInterceptor.popRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text(staticl10n.theme));
      await tester.pumpAndSettle();

      // Open the player theme setting dialog and toggle the setting
      await tester.tap(find.text(staticl10n.playerInterfaceColorStyle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(staticl10n.playerInterfaceColorStyleThemeBackgroundColor));
      await tester.pumpAndSettle();
      await tester.tap(find.text(staticl10n.playerInterfaceColorStyle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(staticl10n.playerInterfaceColorStyleArtColor));
      await tester.pumpAndSettle();

      // Toggle all switch settings
      for (var setting in [
        staticl10n.settingLightMode,
      ]) {
        // Toggle switch
        await tester.tap(find.text(setting));
        await tester.pumpAndSettle();

        // Toggle switch back
        await tester.tap(find.text(setting));
        await tester.pumpAndSettle();
      }

      // Toggle color choices
      await tester.tap(find.byType(ColorItem).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ColorItem).first);
      await tester.pumpAndSettle();
    });
  });
}
