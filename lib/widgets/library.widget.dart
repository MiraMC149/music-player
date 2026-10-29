import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_player/data/providers/library.provider.dart';
import 'package:music_player/models/enums.dart';
import 'package:music_player/models/library.view.dart';
import 'package:music_player/models/models.dart';

/// Height of a two-line list row. Fixed so the alphabet slider can compute
/// exact scroll offsets.
const kRowExtent = 72.0;

String plural(int n, String word) => '$n ${n == 1 ? word : '${word}s'}';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '<1m';
}

// ---------------------------------------------------------------------------

class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    this.path,
    this.size = 48,
    this.icon = Icons.music_note,
  });

  final String? path;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(icon, size: size * 0.5, color: scheme.onSurfaceVariant),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? placeholder()
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(), // don't decode full-size art
                errorBuilder: (_, __, ___) => placeholder(),
              ),
      ),
    );
  }
}

class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.track, this.onTap});

  final Track track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CoverArt(path: track.coverPath),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist ?? unknownArtist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

/// Top bar of each list: optional shuffle button, count, and a trailing control.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.countLabel,
    this.onShuffle,
    this.trailing,
  });

  final String countLabel;
  final VoidCallback? onShuffle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          if (onShuffle != null)
            FilledButton.tonalIcon(
              onPressed: onShuffle,
              icon: const Icon(Icons.shuffle),
              label: const Text('Shuffle'),
            ),
          const Spacer(),
          Text(countLabel, style: Theme.of(context).textTheme.labelLarge),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class SortMenuButton<T> extends StatelessWidget {
  const SortMenuButton({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: 'Sort',
      icon: const Icon(Icons.sort),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final option in options)
          CheckedPopupMenuItem<T>(
            value: option,
            checked: option == value,
            child: Text(labelOf(option)),
          ),
      ],
    );
  }
}

class EmptyLibrary extends ConsumerWidget {
  const EmptyLibrary({super.key, required this.kind});

  final FolderKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final music = kind == FolderKind.music;
    final scanning = ref.watch(addFolderControllerProvider).isLoading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              music ? Icons.library_music : Icons.menu_book,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              music ? 'No music yet' : 'No audiobooks yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a folder and everything inside it will show up here.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (scanning)
              const CircularProgressIndicator()
            else
              FilledButton.icon(
                onPressed: () => ref
                    .read(addFolderControllerProvider.notifier)
                    .addFolder(kind),
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Add folder'),
              ),
          ],
        ),
      ),
    );
  }
}