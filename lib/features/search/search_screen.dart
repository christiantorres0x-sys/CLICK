import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../shared/widgets/source_switcher.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/track_tile.dart';
import '../player/playback_controller.dart';
import 'search_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final provider = ref.watch(musicProviderProvider);
    // A new source starts with a clean search box.
    ref.listen(musicProviderProvider, (previous, next) {
      if (previous?.name != next.name) {
        _controller.clear();
        setState(() {});
      }
    });

    final Widget body = switch (state.status) {
      SearchStatus.idle => EmptyView(
          icon: Icons.search_rounded,
          title: 'Search the catalog',
          message: provider.searchIsMetered
              ? 'Type a song or artist, then press the search key. Searches are limited, so they run only when you submit.'
              : 'Find tracks by title, artist or album in ${provider.name}.',
        ),
      SearchStatus.loading => const LoadingView(label: 'Searching'),
      SearchStatus.error => ErrorView(
          message: state.errorMessage ?? 'Search failed.',
          onRetry: notifier.retry,
        ),
      SearchStatus.success => state.results.isEmpty
          ? EmptyView(
              icon: Icons.search_off_rounded,
              title: 'No results',
              message: 'Nothing matched "${state.query}". Try a different title or artist.',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              itemCount: state.results.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  // Provider attribution (FR-SEARCH-03).
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xs,
                    ),
                    child: Text(
                      'Results from ${provider.name}',
                      style: const TextStyle(color: ClickColors.textSecondary, fontSize: 13),
                    ),
                  );
                }
                final index = i - 1;
                final track = state.results[index];
                return TrackTile(
                  track: track,
                  onTap: () => ref
                      .read(playbackProvider.notifier)
                      .playTracks(state.results, startIndex: index),
                );
              },
            ),
    };

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {}); // refresh the clear button
                notifier.onQueryChanged(value);
              },
              onSubmitted: (value) => notifier.search(value),
              decoration: InputDecoration(
                hintText: 'Search tracks and artists',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                          notifier.onQueryChanged('');
                        },
                      ),
                filled: true,
                fillColor: ClickColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SourceSwitcher(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
