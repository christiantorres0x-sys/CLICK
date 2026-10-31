# CLICK

Online music streaming client for Android, built with Flutter and Dart.
Source of truth: *CLICK – Software Requirements Specification & Development Plan* v1.0 (30 Oct 2026).

> **Status: v0.1–v0.4 on a built-in sample catalog.** No music provider has passed the SRS Phase 0
> gate yet (see `docs/provider-decision-record.md`), so the app uses a clearly labeled **sample
> catalog of fictional tracks with simulated playback (no audio)**. Everything is wired through the
> `MusicProvider` interface so a real provider can replace it later.

## What works in this version

| SRS area | Status |
| --- | --- |
| Dark theme, Home / Search / Library / Profile navigation, mini-player (FR-UI) | Implemented |
| Home discovery from the provider, empty/error/retry states (FR-HOME) | Implemented (sample data) |
| Debounced search via the provider adapter, no-results/error states (FR-SEARCH) | Implemented (sample data) |
| Play, pause, seek, next/previous, shuffle, repeat, Now Playing (FR-PLAY) | Implemented, **simulated** (no audio) |
| Queue: view, add, remove, clear (FR-QUEUE-01..04) | Implemented |
| Liked Songs, playlists (create/rename/delete/add/remove), persistence, history (FR-LIB) | Implemented (SQLite) |
| Settings: provider disclosure, playback defaults, clear history (FR-SET) | Implemented |
| Background playback, notification, lock-screen, audio focus (FR-BG) | **Not implemented** (Phase 5, needs a real audio engine) |
| Real provider, real streaming (FR-PROV, Phase 3/4) | **Not implemented** (blocked by the Phase 0 gate) |
| Queue reordering (FR-QUEUE-05, *Should*) | Not implemented |

## Run it

Prerequisites: Flutter stable (with Android toolchain), VS Code with the Flutter/Dart extensions.

```bash
cd click
flutter create . --platforms=android --project-name click   # generates android/ without touching lib/ or pubspec.yaml
flutter pub get
flutter analyze
flutter test
flutter run                                                   # emulator or physical device
```

`flutter create .` is needed once because the `android/` folder is not checked in yet. It keeps the
existing `lib/`, `test/` and `pubspec.yaml`. Set the application ID/label and review `minSdkVersion`
afterwards (SRS Phase 1).

### Tests

* `test/domain_test.dart`, `playback_controller_test.dart`, `search_and_library_test.dart`, `widget_test.dart`
  need nothing extra.
* `test/sqlite_library_repository_test.dart` runs the real SQL through `sqflite_common_ffi`. On Windows
  this may need `sqlite3.dll` on the path; run it on Linux/macOS/WSL if it cannot load SQLite.

## Design decisions (not specified in the SRS)

* **Sample catalog.** 12 fictional tracks by fictional artists. Labeled on Home, Settings and Now Playing.
* **Simulated playback.** A 500 ms timer advances the position. `PlaybackController` is the only place
  to replace with `just_audio` + `audio_service` (SRS 9.1) in Phase 4/5.
* **Clear queue** removes upcoming tracks and keeps the current track playing (the SRS does not say).
* **Shuffle** randomizes upcoming tracks; turning it off keeps the current order. If a track is added
  to an empty queue it starts playing.
* **Theme setting.** Dark is the only theme (FR-UI-01); Settings shows it read-only.
* **Playback defaults** (shuffle / repeat) are applied when the app starts.
* **Clear listening history** (FR-SET-03) also deletes cached track metadata that is not referenced
  by Liked Songs or a playlist.
* **Unavailable tracks** (FR-LIB-07) are detected when playback fails with `ProviderUnavailableException`
  and then shown as "Unavailable from provider" for the rest of the session.
* **State management:** Riverpod. **Storage:** `sqflite`. Packages from SRS 9.1 that the sample catalog
  does not need yet (`just_audio`, `audio_service`, `cached_network_image`, a networking client) are
  deliberately not added.

## Project layout

```
lib/
  app/        app widget, theme, Riverpod providers
  core/       errors, constants, utilities
  data/       provider adapters (sample), SQLite repository
  domain/     entities and repository interfaces
  features/   home, search, library, player, settings, shell
  shared/     reusable widgets
test/
docs/
```

## Security

No secrets are required in this version. `.gitignore` already excludes `.env`, `secrets.json`,
keystores and `key.properties` (FR-PROV-05, NFR-SEC). When a real provider is added, record its
terms in `docs/provider-decision-record.md` first, and add the `INTERNET` permission to the manifest.
