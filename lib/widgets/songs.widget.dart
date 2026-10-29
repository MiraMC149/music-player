import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_player/models/enums.dart';
import 'package:music_player/models/library.view.dart';
import 'package:music_player/screens/indexed.list.dart';
import 'package:music_player/widgets/library.widget.dart';


class SongsView extends ConsumerWidget {
  const SongsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(songSortProvider);

    return ref.watch(sortedTracksProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load songs\n$e')),
          data: (tracks) {
            if (tracks.isEmpty) return const EmptyLibrary(kind: FolderKind.music);

            return Column(
              children: [
                LibraryHeader(
                  countLabel: plural(tracks.length, 'song'),
                  onShuffle: () {
                    // TODO: shuffle-play all songs once the audio handler exists.
                  },
                  trailing: SortMenuButton<SongSort>(
                    value: sort,
                    options: SongSort.values,
                    labelOf: (s) => s.label,
                    onSelected: ref.read(songSortProvider.notifier).select,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: IndexedListView(
                    key: ValueKey(sort), // reset scroll position when sort changes
                    itemCount: tracks.length,
                    letterOf: sort.isAlphabetical
                        ? (i) => songSectionLetter(tracks[i], sort)
                        : null,
                    itemBuilder: (context, i) => TrackTile(
                      track: tracks[i],
                      onTap: () {
                        // TODO: play `tracks` starting at index i.
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }
}