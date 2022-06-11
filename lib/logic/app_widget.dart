import 'package:home_widget/home_widget.dart';

import '../sweyer.dart';

/// Controller for native app widgets.
class AppWidgetControl extends Control {
  static AppWidgetControl instance = AppWidgetControl();

  @override
  void init() {
    super.init();
    PlaybackControl.instance.onSongChange
        .listen((song) => update(song, MusicPlayer.instance.playing));
    MusicPlayer.instance.playingStream.listen(
        (playing) => update(PlaybackControl.instance.currentSong, playing));
  }

  /// Update the widgets with the current [song] and [playing] state.
  Future<void> update(Song song, bool playing) async {
    await HomeWidget.saveWidgetData('song', song.contentUri);
    await HomeWidget.saveWidgetData('playing', playing);
    await HomeWidget.updateWidget(name: 'MusicPlayerAppWidget');
  }
}
