import 'repeat_mode.dart';

/// Playback-related preferences (SRS 7.1 AppSettings, FR-SET-01).
class AppSettings {
  const AppSettings({this.shuffleDefault = false, this.repeatMode = RepeatMode.off});

  final bool shuffleDefault;
  final RepeatMode repeatMode;

  AppSettings copyWith({bool? shuffleDefault, RepeatMode? repeatMode}) => AppSettings(
        shuffleDefault: shuffleDefault ?? this.shuffleDefault,
        repeatMode: repeatMode ?? this.repeatMode,
      );
}
