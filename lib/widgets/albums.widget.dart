import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_player/models/enums.dart';
import 'package:music_player/models/library.view.dart';
import 'package:music_player/screens/indexed.list.dart';
import 'package:music_player/screens/track.list.view.dart';
import 'package:music_player/widgets/library.widget.dart';

class AlbumsView extends ConsumerWidget {
  const AlbumsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(albumGroupsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load albums\n$e')),
          data: (albums) {
            if (albums.isEmpty) return const EmptyLibrary(kind: FolderKind.music);

            return Column(
              children: [
                LibraryHeader(countLabel: plural(albums.length, 'album')),
                const Divider(height: 1),
                Expanded(
                  child: IndexedListView(
                    itemCount: albums.length,
                    primary: true,
                    letterOf: (i) => letterFor(albums[i].name),
                    itemBuilder: (context, i) {
                      final album = albums[i];
                      return ListTile(
                        leading: CoverArt(
                          path: album.coverPath,
                          icon: Icons.album,
                        ),
                        title: Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${album.artist} • ${plural(album.trackCount, 'song')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TrackListPage(
                              title: album.name,
                              subtitle: album.artist,
                              tracks: album.tracks,
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