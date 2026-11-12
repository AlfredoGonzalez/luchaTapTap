import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// Short sound effects. The file is `assets/audio/sfx_<file>.ogg`.
enum Sfx {
  tap('tap'),
  hit('hit'),
  crit('crit'),
  finisher('finisher'),
  buy('buy'),
  error('error'),
  bossIntro('boss_intro'),
  victory('victory'),
  popupOpen('popup_open'),
  popupClose('popup_close');

  const Sfx(this.file);
  final String file;
}

/// Looping music. The file is `assets/audio/music_<file>.ogg`.
enum MusicTrack {
  main('main'),
  boss('boss');

  const MusicTrack(this.file);
  final String file;
}

/// Plays sound. Volumes already include the master level and the player's
/// switches; the game logic never touches the audio package directly so it
/// runs (and is tested) without any sound hardware.
abstract class AudioService {
  /// Loads the effects so the first tap does not stutter.
  Future<void> preload();

  void playSfx(Sfx sfx, {required double volume});

  /// Starts [track] looping, or just changes the volume when it is already
  /// playing. Does nothing while the app is in the background.
  void playMusic(MusicTrack track, {required double volume});

  void stopMusic();

  /// The app lost focus: music pauses.
  void pause();

  void resume();
}

/// No sound: tests and platforms without audio.
class SilentAudioService implements AudioService {
  @override
  Future<void> preload() async {}
  @override
  void playSfx(Sfx sfx, {required double volume}) {}
  @override
  void playMusic(MusicTrack track, {required double volume}) {}
  @override
  void stopMusic() {}
  @override
  void pause() {}
  @override
  void resume() {}
}

/// Records what would have played (tests).
class RecordingAudioService extends SilentAudioService {
  final List<Sfx> sfx = [];
  final List<double> sfxVolumes = [];
  final List<MusicTrack> music = [];
  MusicTrack? current;
  double musicVolume = 0;
  bool paused = false;

  @override
  void playSfx(Sfx sfx, {required double volume}) {
    this.sfx.add(sfx);
    sfxVolumes.add(volume);
  }

  @override
  void playMusic(MusicTrack track, {required double volume}) {
    if (current != track) music.add(track);
    current = track;
    musicVolume = volume;
  }

  @override
  void stopMusic() => current = null;

  @override
  void pause() => paused = true;

  @override
  void resume() => paused = false;
}

/// Real playback through `flame_audio`.
class FlameAudioService implements AudioService {
  MusicTrack? _track;
  double _volume = 0;
  bool _paused = false;
  bool _started = false;

  @override
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([
        for (final s in Sfx.values) 'sfx_${s.file}.ogg',
      ]);
    } catch (e) {
      debugPrint('Could not preload the sound effects: $e');
    }
  }

  @override
  void playSfx(Sfx sfx, {required double volume}) {
    if (volume <= 0 || _paused) return;
    // Browsers only allow sound after a touch: retry the music on the first
    // effect if it was blocked.
    if (!_started && _track != null) _start();
    _safely(() => FlameAudio.play('sfx_${sfx.file}.ogg', volume: volume));
  }

  @override
  void playMusic(MusicTrack track, {required double volume}) {
    if (volume <= 0) {
      stopMusic();
      return;
    }
    final changed = _track != track;
    _track = track;
    _volume = volume;
    if (_paused) return;
    if (changed || !_started) {
      _start();
    } else {
      _safely(() => FlameAudio.bgm.audioPlayer.setVolume(volume));
    }
  }

  void _start() {
    final track = _track;
    if (track == null) return;
    _started = true;
    _safely(
      () => FlameAudio.bgm.play('music_${track.file}.ogg', volume: _volume),
      onError: () => _started = false,
    );
  }

  @override
  void stopMusic() {
    _track = null;
    _started = false;
    _safely(FlameAudio.bgm.stop);
  }

  @override
  void pause() {
    _paused = true;
    _safely(FlameAudio.bgm.pause);
  }

  @override
  void resume() {
    _paused = false;
    if (_track == null) return;
    if (_started) {
      _safely(FlameAudio.bgm.resume);
    } else {
      _start();
    }
  }

  /// Audio problems (no sound device, blocked autoplay in a browser) must
  /// never break the game.
  void _safely(Future<Object?> Function() action, {void Function()? onError}) {
    action().catchError((Object e) {
      debugPrint('Audio problem: $e');
      onError?.call();
      return null;
    });
  }
}
