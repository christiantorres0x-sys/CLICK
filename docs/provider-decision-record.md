# Provider decision record (SRS Phase 0)

**Status: no provider selected.** Version 1 ships with the built-in sample catalog only.

The SRS (§6.2, §10 Phase 0, §12.1) makes provider selection a release gate. Do not implement a real
provider adapter or publish an APK that streams from one until every item below is filled in with
information from the provider's current official terms.

| Item | Answer |
| --- | --- |
| Candidate provider | _TBD_ |
| API base URL(s) | _TBD_ |
| Third-party app/client use permitted (personal use)? | _TBD_ |
| Public GitHub distribution of the app permitted? | _TBD_ |
| Authentication method; is a public-client key allowed? (FR-PROV-05, FR-PROV-06) | _TBD_ |
| Streaming/playback method permitted | _TBD_ |
| Attribution format and placement | _TBD_ |
| Caching rules | _TBD_ |
| Rate limits | _TBD_ |
| Catalog coverage and limitations | _TBD_ |
| Test request retrieves catalog metadata? | _TBD_ |
| Test stream plays in a permitted environment? | _TBD_ |
| Decision and date | _TBD_ |

## Integration checklist once approved

1. Add a class implementing `MusicProvider` in `lib/data/providers/` (search, details, featured,
   `resolvePlayableSource`).
2. Point `musicProviderProvider` in `lib/app/providers.dart` at it.
3. Replace the timer in `PlaybackController` with `just_audio`, add `audio_service` (Phase 5), and add
   the `INTERNET`, foreground-service and notification permissions required by the target SDK.
4. Show the provider's required attribution (`attributionText` / `attributionUrl`).
