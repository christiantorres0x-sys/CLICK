# Provider decision record (SRS Phase 0)

**Decision (31 Oct 2026): YouTube, music only** — catalog from the YouTube Data API v3, playback through
YouTube's official embedded player. This was chosen by the project owner. It is a *conditional* approval:
the items marked **VERIFY** below still need the owner to confirm against YouTube's current terms before
publishing an APK (SRS §10 Phase 0 gate, §12.1).

The built-in sample catalog remains as the fallback when no API key is supplied.

## What CLICK does and does not do with YouTube

| Item | Decision |
| --- | --- |
| Catalog source | `search.list` and `videos.list` (documented endpoints only, FR-PROV-02) |
| "Music only" | `videoCategoryId=10` on search and charts, `videoEmbeddable=true`, and CLICK also re-checks `categoryId == 10`, `embeddable`, not live, public, and length ≤ 15 minutes |
| Playback | **Only** the official YouTube IFrame player (`youtube_player_iframe`). CLICK never downloads, extracts or proxies audio/video streams, and does not use unofficial libraries (FR-PROV-04) |
| Player visibility | The player is pinned above the app while a YouTube track is loaded. It is at least 200×200 px (full width, 16:9) with nothing drawn over it. YouTube requires an embedded viewport of at least 200×200 px and forbids overlays on it (source: YouTube API Services – Required Minimum Functionality) |
| Background playback / lock-screen controls | **Not possible** with the embedded player. FR-BG-01..04 cannot be met for YouTube; this is an accepted limitation of this provider choice |
| Ads | Controlled by YouTube. CLICK's own UI is ad-free, which is all SRS 2.2 promises |
| Attribution / disclosure | Settings shows the provider text, YouTube Terms of Service link and Google Privacy Policy link (FR-SET-02, FR-SET-04) |
| Downloads / offline | Not offered |

## Quota (the real constraint)

Google's current Data API overview states the default project allocation is "100 `search.list` calls … and
10,000 units per day" for other endpoints; a list read such as `videos.list` usually costs 1 unit.
So CLICK:

* runs a search **only when the user submits** it (no search-as-you-type) and caches results in memory;
* adds one `videos.list` call per search to get duration and embeddable status (cheap, but not free);
* builds Home from one `videos.list` call (`chart=mostPopular`, Music category);
* resolves a track for playback with **no** API call.

When the quota is exhausted the app shows "The YouTube daily limit has been reached." Quota increases are
requested through Google's compliance audit if ever needed.

## API key handling (FR-PROV-05, FR-PROV-06)

* The key is passed at build time with `--dart-define-from-file=secrets.json`. `secrets.json` is git-ignored;
  `secrets.example.json` is the template.
* A key inside an APK can be extracted. In Google Cloud Console restrict it to **YouTube Data API v3**.
  Optionally also restrict it to the Android app (package + SHA-1) and pass `ANDROID_PACKAGE` and
  `ANDROID_CERT_SHA1` so CLICK sends the `X-Android-Package` / `X-Android-Cert` headers.
* **VERIFY:** for a public GitHub release, decide whether each user supplies their own key (recommended) or
  you ship one restricted key.

## Still to verify (not confirmed from the pages I could read)

* **VERIFY** YouTube's developer policies on background/audio-only playback and on third-party apps that
  wrap the embedded player, and that distributing a GitHub-hosted APK is acceptable under the API Services
  Terms of Service.
* **VERIFY** the current quota table for `videos.list` in your Cloud Console (Quotas page).

## Switching providers later

Implement `MusicProvider` (`lib/domain/repositories/music_provider.dart`) and select it in
`lib/app/providers.dart`. Playback engines plug in through `PlayableSource` and `ExternalPlayer`.
