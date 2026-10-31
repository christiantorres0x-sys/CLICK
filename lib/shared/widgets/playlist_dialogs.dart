import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/library_repository.dart';
import '../../features/library/library_controller.dart';
import 'feedback.dart';

/// Asks for a playlist name (FR-LIB-02, FR-LIB-04). Returns the validated name
/// or null if cancelled.
Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlaylistNameDialog(title: title, confirmLabel: confirmLabel, initial: initial),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({required this.title, required this.confirmLabel, required this.initial});

  final String title;
  final String confirmLabel;
  final String initial;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final name = validatePlaylistName(_controller.text);
      Navigator.of(context).pop(name);
    } on ValidationException catch (e) {
      setState(() => _error = e.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: 'Playlist name', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Bottom sheet to add [track] to an existing or new playlist (FR-LIB-03).
Future<void> showAddToPlaylistSheet(BuildContext context, Track track) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(track: track),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(libraryProvider.select((s) => s.playlists));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    Future<void> addTo(int playlistId, String playlistName) async {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(libraryProvider.notifier);
      navigator.pop();
      final ok = await guardAction(messenger, () => notifier.addToPlaylist(playlistId, track));
      if (ok) showSnack(messenger, 'Added to $playlistName');
    }

    Future<void> createAndAdd() async {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(libraryProvider.notifier);
      final name = await showPlaylistNameDialog(
        context,
        title: 'New playlist',
        confirmLabel: 'Create',
      );
      if (name == null) return;
      navigator.pop();
      final playlist = await guardValue(messenger, () => notifier.createPlaylist(name));
      if (playlist == null) return;
      final ok = await guardAction(messenger, () => notifier.addToPlaylist(playlist.id, track));
      if (ok) showSnack(messenger, 'Added to ${playlist.name}');
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('New playlist'),
              onTap: createAndAdd,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final playlist in playlists)
                    ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${playlist.trackCount} tracks'),
                      onTap: () => addTo(playlist.id, playlist.name),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
