import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../app/providers.dart';
import '../../data/providers/youtube_iframe_player.dart';
import '../../data/providers/youtube_music_provider.dart';
import 'dock_layout.dart';
import 'playback_controller.dart';

/// Shows the official YouTube player as a small floating 200x200 square while
/// a YouTube track is loaded. Drag the grip bar above it to move it anywhere on
/// screen; it is kept fully on screen, stays mounted (and visible, as YouTube
/// requires) across every screen, and nothing is ever drawn on top of it.
class YoutubeDockHost extends ConsumerStatefulWidget {
  const YoutubeDockHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<YoutubeDockHost> createState() => _YoutubeDockHostState();
}

class _YoutubeDockHostState extends ConsumerState<YoutubeDockHost> {
  /// Top-left of the dock; null until the user moves it (then the default corner is used).
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(
      playbackProvider.select((s) => s.current?.providerName == YouTubeMusicProvider.providerName),
    );

    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (active)
          LayoutBuilder(
            builder: (context, constraints) {
              final media = MediaQuery.of(context);
              final size = youtubeDockSize(constraints.maxWidth, constraints.maxHeight);
              final total = Size(size.width, size.height + youtubeDockHandleHeight);
              final bounds = Rect.fromLTRB(
                0,
                media.padding.top,
                max(0, constraints.maxWidth - total.width),
                max(media.padding.top, constraints.maxHeight - total.height - media.padding.bottom),
              );
              final fallback = Offset(
                constraints.maxWidth - total.width - youtubeDockMargin,
                constraints.maxHeight - total.height - media.padding.bottom - youtubeDockBottomReserve,
              );
              final pos = _clamp(_position ?? fallback, bounds);
              return Stack(
                children: [
                  Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: _Dock(
                      player: ref.watch(youtubePlayerProvider),
                      size: size,
                      onDrag: (delta) => setState(() => _position = _clamp(pos + delta, bounds)),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  static Offset _clamp(Offset o, Rect b) => Offset(o.dx.clamp(b.left, b.right), o.dy.clamp(b.top, b.bottom));
}

class _Dock extends StatelessWidget {
  const _Dock({required this.player, required this.size, required this.onDrag});

  final YoutubeIframePlayer player;
  final ({double width, double height}) size;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The grip is its own strip above the video, so dragging never touches or covers the player.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => onDrag(d.delta),
            child: SizedBox(
              width: size.width,
              height: youtubeDockHandleHeight,
              child: const Center(child: Icon(Icons.drag_handle_rounded, size: 22, color: Colors.white70)),
            ),
          ),
          SizedBox(
            width: size.width,
            height: size.height,
            child: ListenableBuilder(
              listenable: player,
              builder: (context, _) {
                final controller = player.controller;
                if (controller == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return YoutubePlayer(controller: controller, aspectRatio: 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}
