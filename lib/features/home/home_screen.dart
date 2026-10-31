import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/track.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/state_views.dart';
import '../player/playback_controller.dart';

/// Discovery content supplied by the active provider (FR-HOME-01).
final featuredProvider = FutureProvider<List<TrackSection>>((ref) async {
  final provider = ref.watch(musicProviderProvider);
  if (!provider.supportsDiscovery) return const [];
  return provider.getFeaturedContent();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(musicProviderProvider);
    final featured = ref.watch(featuredProvider);

    Future<void> refresh() async {
      ref.invalidate(featuredProvider);
      try {
        await ref.read(featuredProvider.future);
      } catch (_) {
        // The error state is rendered from the provider itself.
      }
    }

    final List<Widget> content = featured.when(
      loading: () => [const SizedBox(height: 260, child: LoadingView(label: 'Loading featured tracks'))],
      error: (error, _) => [
        SizedBox(
          height: 320,
          child: ErrorView(
            message: error is AppException ? error.userMessage : 'Could not load discovery content.',
            onRetry: () => ref.invalidate(featuredProvider),
          ),
        ),
      ],
      data: (sections) {
        // FR-HOME-03: useful state when the provider has no discovery content.
        if (!provider.supportsDiscovery || sections.isEmpty) {
          return [
            const SizedBox(
              height: 320,
              child: EmptyView(
                icon: Icons.explore_off_rounded,
                title: 'No discovery content',
                message: 'This provider does not offer featured music. Use Search to find tracks.',
              ),
            ),
          ];
        }
        return [for (final section in sections) _Section(section: section)];
      },
    );

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            const _Header(),
            if (provider.isSample) const _SampleBanner(),
            ...content,
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLICK',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: ClickColors.accent,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Online music streaming', style: TextStyle(color: ClickColors.textSecondary)),
        ],
      ),
    );
  }
}

/// SRS Phase 2: mock/sample data must be clearly labeled.
class _SampleBanner extends StatelessWidget {
  const _SampleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ClickColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ClickColors.outline),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: ClickColors.accent),
          SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              'You are browsing the built-in sample catalog. Tracks are fictional and playback is '
              'simulated until a music provider is approved.',
              style: TextStyle(color: ClickColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends ConsumerWidget {
  const _Section({required this.section});

  final TrackSection section;

  static const double _cardWidth = 150;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaler = MediaQuery.textScalerOf(context);
    final listHeight = _cardWidth + AppSpacing.sm + scaler.scale(20) + scaler.scale(18) + AppSpacing.sm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
          child: Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: listHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: section.tracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm + 4),
            itemBuilder: (context, i) => _TrackCard(
              track: section.tracks[i],
              width: _cardWidth,
              onTap: () => ref.read(playbackProvider.notifier).playTracks(section.tracks, startIndex: i),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track, required this.width, required this.onTap});

  final Track track;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(track: track, size: width),
            const SizedBox(height: AppSpacing.sm),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              track.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ClickColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
