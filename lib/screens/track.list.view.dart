import 'package:flutter/material.dart';
import 'package:music_player/models/models.dart';
import 'package:music_player/widgets/library.widget.dart';

/// Songs of one artist or one album. Opened from the artists/albums views.
class TrackListPage extends StatelessWidget {
  const TrackListPage({
    super.key,
    required this.title,
    required this.tracks,
    this.subtitle,
  });

  final String title;

  /// e.g. the artist name on an album page.
  final String? subtitle;
  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final count = plural(tracks.length, 'song');

    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          LibraryHeader(
            countLabel: subtitle == null ? count : '$subtitle • $count',
            onShuffle: () {
              // TODO: shuffle-play `tracks` once the audio handler exists.
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemExtent: kRowExtent,
              itemCount: tracks.length,
              itemBuilder: (context, i) => TrackTile(
                track: tracks[i],
                onTap: () {
                  // TODO: play `tracks` starting at index i.
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}