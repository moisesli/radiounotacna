import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:radiounotacna/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

String? res;
Future<String> loadJson() async{
  var url = Uri.parse('https://gix12724dc.execute-api.us-east-1.amazonaws.com/radiouno');
  var response = await http.get(url);
  var data = jsonDecode(response.body);
  return data['url'];
}


// You might want to provide this using dependency injection rather than a
// global variable.
late AudioHandler _audioHandler;

Future<void> main() async {
  res = await loadJson();
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Uno',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const Principal(),
    );
  }
}

class Principal extends StatefulWidget {
  const Principal({Key? key}) : super(key: key);

  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio Uno'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Show media item title
          StreamBuilder<MediaItem?>(
            stream: _audioHandler.mediaItem,
            builder: (context, snapshot) {
              final mediaItem = snapshot.data;
              return Text(mediaItem?.title ?? '');
            },
          ),
          // Play/pause/stop buttons.
          StreamBuilder<bool>(
            stream: _audioHandler.playbackState.map((state) => state.playing).distinct(),
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;
              return Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset('assets/img/radiouno2.png'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (playing)
                        _button(Icons.pause, _audioHandler.pause)
                      else
                        _button(Icons.play_arrow, _audioHandler .play),
                      _button(Icons.stop, _audioHandler.stop),
                    ],
                  ),
                ],
              );
            },
          ),
          // A seek bar.
          StreamBuilder<MediaState>(
            stream: _mediaStateStream,
            builder: (context, snapshot) {
              final mediaState = snapshot.data;
              return SeekBar(
                duration: mediaState?.mediaItem?.duration ?? Duration.zero,
                position: mediaState?.position ?? Duration.zero,
                onChangeEnd: (newPosition) {
                  _audioHandler.seek(newPosition);
                },
              );
            },
          ),
          // Display the processing state.
          StreamBuilder<AudioProcessingState>(
            stream: _audioHandler.playbackState
                .map((state) => state.processingState)
                .distinct(),
            builder: (context, snapshot) {
              final processingState =
                  snapshot.data ?? AudioProcessingState.idle;
              return Text(
                  "Processing state: ${describeEnum(processingState)}");
            },
          ),
        ],
      ),
    );
  }

  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest2<MediaItem?, Duration, MediaState>(
          _audioHandler.mediaItem,
          AudioService.position,
              (mediaItem, position) => MediaState(mediaItem, position));

  IconButton _button(IconData iconData, VoidCallback onPressed) => IconButton(
    icon: Icon(iconData),
    iconSize: 64.0,
    onPressed: onPressed,
  );
}


class MediaState {
  final MediaItem? mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

/// An [AudioHandler] for playing a single item.
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {

  static final _item = MediaItem(
    id: "${res}",
    album: "Science Friday",
    title: "Peru Tacna - Radio Uno",
    artist: "Science Friday and WNYC Studios",
    duration: const Duration(milliseconds: 5739820),
    artUri: Uri.parse('https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg'),
  );

  final _player = AudioPlayer();

  /// Initialise our audio handler.
  AudioPlayerHandler() {
    // So that our clients (the Flutter UI and the system notification) know
    // what state to display, here we set up our audio handler to broadcast all
    // playback state changes as they happen via playbackState...
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    // ... and also the current media item via mediaItem.
    mediaItem.add(_item);

    // Load the player.
    _player.setAudioSource(AudioSource.uri(Uri.parse(_item.id)));
  }

  // In this simple example, we handle only 4 actions: play, pause, seek and
  // stop. Any button press from the Flutter UI, notification, lock screen or
  // headset will be routed through to these 4 methods so that you can handle
  // your audio playback logic in one place.

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  /// Transform a just_audio event into an audio_service state.
  ///
  /// This method is used from the constructor. Every event received from the
  /// just_audio player will be transformed into an audio_service state so that
  /// it can be broadcast to audio_service clients.
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}