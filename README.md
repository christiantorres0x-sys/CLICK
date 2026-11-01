# CLICK

Online music streaming client for Android, built with Flutter and Dart.
Source of truth: *CLICK – Software Requirements Specification & Development Plan* v1.0 (30 Oct 2026).

**Music sources** (switch on Home / Search when both are configured):

* **Jamendo (audio)**: audio-only streams that play in CLICK's own player, with no video on screen.
* **YouTube (video)**: music only (Data API v3 + the official YouTube embedded player). YouTube's rules require
  its player to stay visible, so it cannot be hidden.

With neither key the app falls back to a labeled sample catalog with simulated playback.
See `docs/provider-decision-record.md`.

## Status

| SRS area | Status |
| --- | --- |
| Dark theme, Home / Search / Library / Profile navigation, mini-player (FR-UI) | Implemented |
| Home = YouTube Music chart; search = Music category, embeddable videos only (FR-HOME, FR-SEARCH) | Implemented, **needs your API key** |
| Play, pause, seek, next/previous, shuffle, repeat, Now Playing (FR-PLAY) | Implemented (YouTube player or simulated) |
| Queue: view, add, remove, clear (FR-QUEUE-01..04) | Implemented |
| Liked Songs, playlists, history, persistence (FR-LIB) | Implemented (SQLite) |
| Settings: provider disclosure, playback defaults, clear history (FR-SET) | Implemented |
| Background playback, notification, lock-screen (FR-BG) | Implemented for **audio-only (Jamendo) tracks** via `just_audio_background`. **Not possible for YouTube** (its player must stay visible). |
| Queue reordering (FR-QUEUE-05, *Should*) | Implemented (drag the handle on Up next) |

Phase 7 checks: see `docs/phase7-quality-checklist.md`.

## Run it

```powershell
cd click
flutter pub get
flutter analyze
flutter test
flutter run                                   # sample catalog (no key)
flutter run --dart-define-from-file=secrets.json   # YouTube
```

**Smoothness:** `flutter run` builds a *debug* app, which is much slower and janky on purpose. To judge speed, run
`flutter run --release --dart-define-from-file=secrets.json` (or install the release APK).

### One-time setup for Jamendo (audio-only, no video)

1. Create a free app at the Jamendo developer portal (devportal.jamendo.com) and copy its **client id**.
2. Add it to `secrets.json` as `JAMENDO_CLIENT_ID` (see `secrets.example.json`). It is passed with
   `--dart-define-from-file` and never committed. Use only the sources you have keys for.
3. Run `flutter pub get` (adds `just_audio`) and `flutter run --dart-define-from-file=secrets.json`.
4. Check Jamendo's API terms for your intended use (the free client id is meant for non-commercial apps; verify).

### One-time setup for YouTube

1. **API key.** In Google Cloud Console: create a project, enable **YouTube Data API v3**, create an API key,
   and restrict it to that API. Copy `secrets.example.json` to `secrets.json` (git-ignored) and paste the key.
2. **Internet permission.** Already declared in `android/app/src/main/AndroidManifest.xml`, so release
   APKs can reach YouTube. (Flutter only adds it to debug/profile builds by default.)
3. **Quota.** The default quota is about **100 searches per day**. Search therefore runs only when you press
   the keyboard's search key, and results are cached while the app is open.

### Tests

* No extras needed: `domain_test`, `playback_controller_test`, `external_player_controller_test`,
  `search_and_library_test`, `youtube_music_provider_test` (mocked HTTP, no network), `widget_test`.
* `sqlite_library_repository_test.dart` runs real SQL through `sqflite_common_ffi`.

## How audio-only playback works

A provider that returns `PlayableSource.stream(url)` plays through `JustAudioPlayer` (`lib/data/providers/just_audio_player.dart`),
which implements the same `ExternalPlayer` port as the YouTube player. `PlaybackController` picks the engine per
track, pauses the previous engine when switching, and each track always resolves with the provider that owns it,
so changing the Home/Search source never breaks the queue. The YouTube dock appears only for YouTube tracks.

## Background playback (Jamendo only)

Audio streams keep playing when you leave the app or lock the screen, with a media notification and lock-screen
controls (play/pause, seek). This uses `just_audio_background` (foreground service, declared in
`AndroidManifest.xml`; `MainActivity` extends `AudioServiceActivity`). Limits of this version:

* The notification's next/previous buttons do nothing yet: CLICK keeps its own queue, so skipping is done in the app.
* On Android 13+ the media controls still work, but the separate notification may need the notification permission
  (Settings > Apps > CLICK > Notifications) before it is shown.
* YouTube tracks still pause when CLICK goes to the background (YouTube's rules).

After pulling this update run `flutter pub get`, then do a full rebuild (`flutter run`, not hot reload) because
native Android files changed.

## How the YouTube playback works

The YouTube player is a small floating 200x200 square (YouTube's minimum size) while a YouTube track is loaded. Drag the grip
bar above it to move it anywhere (it stays on screen); it starts bottom-right above the mini-player and nothing is drawn over it. When Jamendo is configured it is the
default source, so you only see video after choosing YouTube. `PlaybackController` stays the only owner of queue and
state and talks to the player through the `ExternalPlayer` interface; only
`lib/data/providers/youtube_iframe_player.dart` and `lib/features/player/youtube_dock.dart` use the
`youtube_player_iframe` package.

## Design decisions (not specified in the SRS)

* **Clear queue** removes upcoming tracks and keeps the current track playing.
* **Shuffle** randomizes upcoming tracks; turning it off keeps the current order. Adding a track to an empty
  queue starts it.
* **Search on submit for YouTube** because of the quota (deviates from FR-SEARCH-05's debounce, which still
  applies to non-metered providers).
* **Music filter:** category 10, embeddable, public, not live, at most 15 minutes (drops mixes and albums).
* **Theme:** dark only. **Clear listening history** also deletes unreferenced cached metadata.
* **Unavailable tracks** (FR-LIB-07) are flagged when playback fails, for the rest of the session.

## Project layout

```
lib/
  app/        app widget, theme, Riverpod providers (provider selection lives here)
  core/       errors, constants, utilities
  data/       providers (YouTube, Jamendo, sample), YouTube iframe + just_audio players, SQLite repository
  domain/     entities and interfaces (MusicProvider, ExternalPlayer, repositories)
  features/   home, search, library, player (incl. YouTube dock), settings, shell
  shared/     reusable widgets
test/
docs/
```

## Security

`secrets.json`, `.env`, keystores and `key.properties` are git-ignored (FR-PROV-05, NFR-SEC). A key compiled
into an APK can be extracted, so restrict it in Google Cloud Console (see the decision record).
