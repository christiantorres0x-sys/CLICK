import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../app/providers.dart';
import '../../data/providers/youtube_iframe_player.dart';
import '../../data/providers/youtube_music_provider.dart';
import 'playback_controller.dart';

/// Pins the official YouTube player above the whole app while a YouTube track
/// is loaded, so it stays mounted (and visible, as YouTube requires) across
/// every screen. Nothing is ever drawn on top of it.
///
/// The child keeps a stable position in the tree, so toggling the dock does not
/// reset navigation state.
class YoutubeDockHost extends ConsumerWidget {
  const YoutubeDockHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      playbackProvider.select((s) => s.current?.providerName == YouTubeMusicProvider.providerName),
    );

    return Column(
      children: [
        if (active) _Dock(player: ref.watch(youtubePlayerProvider)) else const SizedBox.shrink(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: active, // the dock already sits below the status bar
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.player});

  final YoutubeIframePlayer player;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final controller = player.controller;
            if (controller == null) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return YoutubePlayer(controller: controller, aspectRatio: 16 / 9);
          },
        ),
      ),
    );
  }
}
