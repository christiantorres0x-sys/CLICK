# Phase 7 – quality, accessibility and polish

Automated (run `flutter test`):
- Colors: text, accent and error colors meet WCAG AA 4.5:1 on every surface (`test/accessibility_test.dart`).
- Playback, queue (incl. reordering), search, library, providers (YouTube, Jamendo), audio-stream routing.

Changes in this pass:
- Cover art is decoded at display size (less memory in long lists) and keeps the old image while reloading.
- Mini-player reads as one label ("Now playing: title by artist") and announces playback errors; its decorative
  progress bar is hidden from screen readers (Now Playing has the seek slider).
- Now Playing announces errors; the video player drag bar has a spoken label.

Manual checks on a real phone (I cannot run these):
1. **TalkBack on**: navigate Home > Search > play a track > Now Playing. Every button should be spoken with a name.
2. **Font size 200%** (Settings > Display): lists, mini-player and Now Playing must not overflow or clip.
3. **Rotate** during playback (Jamendo and YouTube): playback continues, the video square stays on screen.
4. **Airplane mode**: search shows a readable error with Retry; playing a track shows "Press play to retry".
5. **Phone call / other app plays audio** while a Jamendo track plays: it pauses and can be resumed.
6. **Lock screen**: Jamendo keeps playing; play/pause works from the lock screen.
7. **Kill and reopen the app**: liked songs, playlists, history and the chosen source are still there.
8. **Cold start time** and scrolling a 30-track list feel smooth on your CPH2799.
