import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_player/models/enums.dart';
import 'package:music_player/models/library.view.dart';
import 'package:music_player/screens/indexed.list.dart';
import 'package:music_player/screens/track.list.view.dart';
import 'package:music_player/widgets/library.widget.dart';

class ArtistsView extends ConsumerWidget {
  const ArtistsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(artistGroupsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load artists\n$e')),
          data: (artists) {
            if (artists.isEmpty) return const EmptyLibrary(kind: FolderKind.music);

            return Column(
              children: [
                LibraryHeader(countLabel: plural(artists.length, 'artist')),
                const Divider(height: 1),
                Expanded(
                  child: IndexedListView(
                    itemCount: artists.length,
                    primary: true,
                    letterOf: (i) => letterFor(artists[i].name),
                    itemBuilder: (context, i) {
                      final artist = artists[i];
                      return ListTile(
                        leading: CoverArt(
                          path: artist.coverPath,
                          icon: Icons.person,
                        ),
                        title: Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(plural(artist.trackCount, 'song')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TrackListPage(
                              title: artist.name,
                              tracks: artist.tracks,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }
}