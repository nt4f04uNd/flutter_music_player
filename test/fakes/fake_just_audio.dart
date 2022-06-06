/*---------------------------------------------------------------------------------------------
*  Copyright (c) nt4f04und. All rights reserved.
*  Licensed under the BSD-style license. See LICENSE in the project root for license information.
*
*  Copyright (c) 2019-2020 Ryan Heise and the project contributors.
*  See ThirdPartyNotices.txt in the project root for license information.
*--------------------------------------------------------------------------------------------*/

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockJustAudio
    with MockPlatformInterfaceMixin
    implements JustAudioPlatform {
  MockAudioPlayer? mostRecentPlayer;
  final _players = <String, MockAudioPlayer>{};

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (_players.containsKey(request.id)) {
      throw PlatformException(
          code: "error",
          message: "Platform player ${request.id} already exists");
    }
    final player = MockAudioPlayer(request);
    _players[request.id] = player;
    mostRecentPlayer = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    _players[request.id]!.dispose(DisposeRequest());
    _players.remove(request.id);
    return DisposePlayerResponse();
  }
}

const audioSourceDuration = Duration(minutes: 2);

final icyMetadata = IcyMetadata(
  headers: IcyHeaders(
    url: 'url',
    genre: 'Genre',
    metadataInterval: 3,
    bitrate: 100,
    isPublic: true,
    name: 'name',
  ),
  info: IcyInfo(
    title: 'title',
    url: 'url',
  ),
);

final icyMetadataMessage = IcyMetadataMessage(
  headers: IcyHeadersMessage(
    url: 'url',
    genre: 'Genre',
    metadataInterval: 3,
    bitrate: 100,
    isPublic: true,
    name: 'name',
  ),
  info: IcyInfoMessage(
    title: 'title',
    url: 'url',
  ),
);

extension SaveCompleter<T> on Completer<T> {
  void completeIfPending() {
    if (!isCompleted) {
      complete();
    }
  }
}

class MockAudioPlayer implements AudioPlayerPlatform {
  final String _id;
  final eventController = StreamController<PlaybackEventMessage>();
  final AudioLoadConfigurationMessage? audioLoadConfiguration;
  AudioSourceMessage? _audioSource;
  ProcessingStateMessage _processingState = ProcessingStateMessage.idle;
  Duration _updatePosition = Duration.zero;
  DateTime _updateTime = DateTime.now();
  // ignore: prefer_final_fields
  Duration? _duration;
  int? _index;
  var _playing = false;
  var _speed = 1.0;
  Completer<dynamic>? _playCompleter;
  Timer? _playTimer;

  MockAudioPlayer(InitRequest request)
      : _id = request.id,
        audioLoadConfiguration = request.audioLoadConfiguration;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream =>
      StreamController<PlayerDataMessage>().stream;

  @override
  String get id => _id;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      eventController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final audioSource = request.audioSourceMessage;
    _processingState = ProcessingStateMessage.loading;
    _broadcastPlaybackEvent();
    if (audioSource is UriAudioSourceMessage) {
      if (audioSource.uri.contains('abort')) {
        throw PlatformException(code: 'abort', message: 'Failed to load URL');
      } else if (audioSource.uri.contains('404')) {
        throw PlatformException(code: '404', message: 'Not found');
      } else if (audioSource.uri.contains('error')) {
        throw PlatformException(code: 'error', message: 'Unknown error');
      }
      _duration = audioSourceDuration;
    } else if (audioSource is ClippingAudioSourceMessage) {
      _duration = (audioSource.end ?? audioSourceDuration) -
          (audioSource.start ?? Duration.zero);
    } else {
      // TODO: pull the sequence out of the audio source and return the duration
      // of the first item in the sequence.
      _duration = audioSourceDuration;
    }
    _audioSource = audioSource;
    _index = request.initialIndex ?? 0;
    // Simulate loading time.
    await Future<dynamic>.delayed(Duration(milliseconds: 100));
    _setPosition(request.initialPosition ?? Duration.zero);
    _processingState = ProcessingStateMessage.ready;
    _broadcastPlaybackEvent();
    if (_playing) {
      _startTimer();
    }
    return LoadResponse(duration: _duration);
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    if (_playing) return PlayResponse();
    _playing = true;
    if (_duration != null) {
      _startTimer();
    }
    _playCompleter = Completer<dynamic>();
    await _playCompleter!.future;
    return PlayResponse();
  }

  void _startTimer() {
    _playTimer = Timer(_remaining, () {
      _setPosition(_position);
      _processingState = ProcessingStateMessage.completed;
      _broadcastPlaybackEvent();
      _playCompleter?.completeIfPending();
    });
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    if (!_playing)
      return PauseResponse();
    _playing = false;
    _playTimer?.cancel();
    _playCompleter?.completeIfPending();
    _setPosition(_position);
    _broadcastPlaybackEvent();
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    _setPosition(request.position ?? Duration.zero);
    _index = request.index ?? 0;
    _broadcastPlaybackEvent();
    return SeekResponse();
  }

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
      SetAndroidAudioAttributesRequest request) async {
    return SetAndroidAudioAttributesResponse();
  }

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
          SetAutomaticallyWaitsToMinimizeStallingRequest request) async {
    return SetAutomaticallyWaitsToMinimizeStallingResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
      SetShuffleModeRequest request) async {
    return SetShuffleModeResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
      SetShuffleOrderRequest request) async {
    return SetShuffleOrderResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    _speed = request.speed;
    _setPosition(_position);
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async {
    return SetPitchResponse();
  }

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
      SetSkipSilenceRequest request) async {
    return SetSkipSilenceResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    return SetVolumeResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _processingState = ProcessingStateMessage.idle;
    _broadcastPlaybackEvent();
    return DisposeResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
      ConcatenatingInsertAllRequest request) async {
    // TODO
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
      ConcatenatingMoveRequest request) async {
    // TODO
    return ConcatenatingMoveResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
      ConcatenatingRemoveRangeRequest request) async {
    // TODO
    return ConcatenatingRemoveRangeResponse();
  }

  void _broadcastPlaybackEvent() {
    String? url;
    if (_audioSource is UriAudioSourceMessage) {
      // Not sure why this cast is necessary...
      url = (_audioSource as UriAudioSourceMessage).uri.toString();
    }
    eventController.add(PlaybackEventMessage(
      processingState: _processingState,
      updatePosition: _updatePosition,
      updateTime: _updateTime,
      bufferedPosition: _position,
      icyMetadata: IcyMetadataMessage(
        headers: IcyHeadersMessage(
          url: url,
          genre: 'Genre',
          metadataInterval: 3,
          bitrate: 100,
          isPublic: true,
          name: 'name',
        ),
        info: IcyInfoMessage(
          title: 'title',
          url: url,
        ),
      ),
      duration: _duration,
      currentIndex: _index,
      androidAudioSessionId: null,
    ));
  }

  Duration get _position {
    if (_playing && _processingState == ProcessingStateMessage.ready) {
      final result =
          _updatePosition + (DateTime.now().difference(_updateTime)) * _speed;
      return result <= _duration! ? result : _duration!;
    } else {
      return _updatePosition;
    }
  }

  Duration get _remaining => (_duration! - _position) * (1 / _speed);

  void _setPosition(Duration position) {
    _updatePosition = position;
    _updateTime = DateTime.now();
  }

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
      setCanUseNetworkResourcesForLiveStreamingWhilePaused(
          SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest
              request) async {
    return SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  }

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
      SetPreferredPeakBitRateRequest request) async {
    return SetPreferredPeakBitRateResponse();
  }

  @override
  Future<AudioEffectSetEnabledResponse> audioEffectSetEnabled(
      AudioEffectSetEnabledRequest request) async {
    return AudioEffectSetEnabledResponse();
  }

  @override
  Future<AndroidLoudnessEnhancerSetTargetGainResponse>
      androidLoudnessEnhancerSetTargetGain(
          AndroidLoudnessEnhancerSetTargetGainRequest request) async {
    return AndroidLoudnessEnhancerSetTargetGainResponse();
  }

  @override
  Future<AndroidEqualizerGetParametersResponse> androidEqualizerGetParameters(
      AndroidEqualizerGetParametersRequest request) async {
    return AndroidEqualizerGetParametersResponse(
      parameters: AndroidEqualizerParametersMessage(
        minDecibels: 0.0,
        maxDecibels: 10.0,
        bands: [
          for (var i = 0; i < 5; i++)
            AndroidEqualizerBandMessage(
              index: i,
              lowerFrequency: i * 1000,
              upperFrequency: (i + 1) * 1000,
              centerFrequency: (i + 0.5) * 1000,
              gain: i * 0.1,
            ),
        ],
      ),
    );
  }

  @override
  Future<AndroidEqualizerBandSetGainResponse> androidEqualizerBandSetGain(
      AndroidEqualizerBandSetGainRequest request) async {
    return AndroidEqualizerBandSetGainResponse();
  }
}

final byteRangeData = List.generate(200, (i) => i);

class TestStreamAudioSource extends StreamAudioSource {
  TestStreamAudioSource({dynamic tag}) : super(tag: tag);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      contentType: 'audio/mock',
      stream: Stream.value(byteRangeData.sublist(start ?? 0, end)),
      contentLength: (end ?? byteRangeData.length) - (start ?? 0),
      offset: start ?? 0,
      sourceLength: byteRangeData.length,
    );
  }
}
