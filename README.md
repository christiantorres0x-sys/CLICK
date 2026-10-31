# CLICK

Online music streaming client for Android, built with Flutter and Dart.
Source of truth: *CLICK – Software Requirements Specification & Development Plan* v1.0 (30 Oct 2026).

**Music source:** YouTube, music only (Data API v3 + the official YouTube embedded player). Without an API key
the app falls back to a labeled sample catalog with simulated playback. See `docs/provider-decision-record.md`.

## Status

| SRS area | Status |
| --- | --- |
| Dark theme, Home / Search / Library / Profile navigation, mini-player (FR-UI) | Implemented |
| Home = YouTube Music chart; search = Music category, embeddable videos only (FR-HOME, FR-SEARCH) | Implemented, **needs your API key** |
| Play, pause, seek, next/previous, shuffle, repeat, Now Playing (FR-PLAY) | Implemented (YouTube player or simulated) |
| Queue: view, add, remove, clear (FR-QUEUE-01..04) | Implemented |
| Liked Songs, playlists, history, persistence (FR-LIB) | Implemented (SQLite) |
| Settings: provider disclosure, playback defaults, clear history (FR-SET) | Implemented |
| Background playback, notification, lock-screen (FR-BG) | **Not possible with YouTube's embedded player** (it must stay visible); see the decision record |
| Queue reordering (FR-QUEUE-05, *Should*) | Not implemented |

## Run it

```powershell
cd click
flutter pub get
flutter analyze
flutter test
flutter run                                   # sample catalog (no key)
flutter run --dart-define-from-file=secrets.json   # YouTube
```

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

## How the YouTube playback works

The YouTube player is pinned at the top of the screen while a YouTube track is loaded and the rest of the app
sits below it (so navigation never hides or covers it). `PlaybackController` stays the only owner of queue and
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
  data/       providers (YouTube, sample), YouTube iframe player, SQLite repository
  domain/     entities and interfaces (MusicProvider, ExternalPlayer, repositories)
  features/   home, search, library, player (incl. YouTube dock), settings, shell
  shared/     reusable widgets
test/
docs/
```

## Security

`secrets.json`, `.env`, keystores and `key.properties` are git-ignored (FR-PROV-05, NFR-SEC). A key compiled
into an APK can be extracted, so restrict it in Google Cloud Console (see the decision record).
