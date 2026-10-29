import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_player/data/providers/library.provider.dart';
import 'package:music_player/models/models.dart';


// ---------------------------------------------------------------------------
// Constants & text helpers
// ---------------------------------------------------------------------------

const unknownArtist = 'Unknown artist';
const unknownAlbum = 'Unknown album';
const unknownAuthor = 'Unknown author';

/// Letters shown in the alphabet slider. '#' = anything that isn't A-Z.
const indexLetters = [
  '#', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

final _az = RegExp(r'[A-Z]');

/// Which slider section a piece of text belongs to.
String letterFor(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '#';
  final first = trimmed[0].toUpperCase();
  return _az.hasMatch(first) ? first : '#';
}

/// Case-insensitive A-Z ordering with the '#' bucket first, so the order always
/// matches the sections shown in the slider.
int alphaCompare(String a, String b) {
  final la = letterFor(a);
  final lb = letterFor(b);
  if (la != lb) {
    if (la == '#') return -1;
    if (lb == '#') return 1;
    return la.compareTo(lb);
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}

// ---------------------------------------------------------------------------
// Songs
// ---------------------------------------------------------------------------

enum SongSort { title, artist, dateAddedDesc, dateAddedAsc }

extension SongSortX on SongSort {
  String get label => switch (this) {
        SongSort.title => 'Song name (A–Z)',
        SongSort.artist => 'Artist name (A–Z)',
        SongSort.dateAddedDesc => 'Date added (newest first)',
        SongSort.dateAddedAsc => 'Date added (oldest first)',
      };

  /// Alphabetical sorts get section headers and the slider.
  bool get isAlphabetical => this == SongSort.title || this == SongSort.artist;
}

String songSectionLetter(Track t, SongSort sort) =>
    letterFor(sort == SongSort.artist ? (t.artist ?? unknownArtist) : t.title);

List<Track> sortTracks(List<Track> tracks, SongSort sort) {
  int byAdded(Track a, Track b) {
    final c = a.dateAdded.compareTo(b.dateAdded);
    return c != 0 ? c : a.id.compareTo(b.id); // many tracks share a timestamp
  }

  final list = [...tracks];
  switch (sort) {
    case SongSort.title:
      list.sort((a, b) => alphaCompare(a.title, b.title));
    case SongSort.artist:
      list.sort((a, b) {
        final c = alphaCompare(
          a.artist ?? unknownArtist,
          b.artist ?? unknownArtist,
        );
        return c != 0 ? c : alphaCompare(a.title, b.title);
      });
    case SongSort.dateAddedAsc:
      list.sort(byAdded);
    case SongSort.dateAddedDesc:
      list.sort((a, b) => byAdded(b, a));
  }
  return list;
}

// ---------------------------------------------------------------------------
// Artists & albums
// ---------------------------------------------------------------------------

String? _firstCover(List<Track> tracks) =>
    tracks.map((t) => t.coverPath).whereType<String>().firstOrNull;

class ArtistGroup {
  const ArtistGroup({required this.name, required this.tracks});

  final String name;
  final List<Track> tracks;

  int get trackCount => tracks.length;
  String? get coverPath => _firstCover(tracks);
}

class AlbumGroup {
  const AlbumGroup({
    required this.name,
    required this.artist,
    required this.tracks,
  });

  final String name;
  final String artist;
  final List<Track> tracks;

  int get trackCount => tracks.length;
  String? get coverPath => _firstCover(tracks);
}

List<ArtistGroup> groupByArtist(List<Track> tracks) {
  final byKey = <String, List<Track>>{};
  final names = <String, String>{};
  for (final t in tracks) {
    final name = t.artist ?? unknownArtist;
    final key = name.toLowerCase();
    names.putIfAbsent(key, () => name);
    (byKey[key] ??= []).add(t);
  }

  final groups = [
    for (final e in byKey.entries)
      ArtistGroup(
        name: names[e.key]!,
        tracks: [...e.value]..sort((a, b) => alphaCompare(a.title, b.title)),
      ),
  ];
  groups.sort((a, b) => alphaCompare(a.name, b.name));
  return groups;
}

List<AlbumGroup> groupByAlbum(List<Track> tracks) {
  final byKey = <String, List<Track>>{};
  final names = <String, String>{};
  for (final t in tracks) {
    final name = t.album ?? unknownAlbum;
    final key = name.toLowerCase();
    names.putIfAbsent(key, () => name);
    (byKey[key] ??= []).add(t);
  }

  String albumArtist(List<Track> list) {
    final artists = {for (final t in list) t.artist ?? unknownArtist};
    return artists.length == 1 ? artists.first : 'Various artists';
  }

  final groups = [
    for (final e in byKey.entries)
      AlbumGroup(
        name: names[e.key]!,
        artist: albumArtist(e.value),
        tracks: [...e.value]..sort((a, b) {
            const last = 1 << 30;
            final c = (a.trackNumber ?? last).compareTo(b.trackNumber ?? last);
            return c != 0 ? c : alphaCompare(a.title, b.title);
          }),
      ),
  ];
  groups.sort((a, b) => alphaCompare(a.name, b.name));
  return groups;
}

// ---------------------------------------------------------------------------
// Audiobooks
// ---------------------------------------------------------------------------

enum BookSort { title, author, lastAdded, lastUsed }

extension BookSortX on BookSort {
  String get label => switch (this) {
        BookSort.title => 'Name',
        BookSort.author => 'Author',
        BookSort.lastAdded => 'Last added',
        BookSort.lastUsed => 'Last used',
      };
}

class BookEntry {
  const BookEntry(this.book, this.progress);

  final Book book;
  final PlaybackProgress? progress;

  /// Started but not finished.
  bool get inProgress {
    final p = progress;
    return p != null && !p.completed && p.position > Duration.zero;
  }

  double get fraction {
    final total = book.duration.inMilliseconds;
    final pos = progress?.position.inMilliseconds ?? 0;
    return total == 0 ? 0 : (pos / total).clamp(0.0, 1.0);
  }

  Duration get remaining {
    final left = book.duration - (progress?.position ?? Duration.zero);
    return left.isNegative ? Duration.zero : left;
  }
}

class BookShelf {
  const BookShelf({required this.inProgress, required this.others});

  final List<BookEntry> inProgress;
  final List<BookEntry> others;

  int get total => inProgress.length + others.length;
}

int _compareBooks(BookEntry a, BookEntry b, BookSort sort) {
  int byAdded() {
    final c = b.book.dateAdded.compareTo(a.book.dateAdded); // newest first
    return c != 0 ? c : b.book.id.compareTo(a.book.id);
  }

  switch (sort) {
    case BookSort.title:
      return alphaCompare(a.book.title, b.book.title);
    case BookSort.author:
      final c = alphaCompare(
        a.book.author ?? unknownAuthor,
        b.book.author ?? unknownAuthor,
      );
      return c != 0 ? c : alphaCompare(a.book.title, b.book.title);
    case BookSort.lastAdded:
      return byAdded();
    case BookSort.lastUsed:
      final pa = a.progress?.lastPlayedAt;
      final pb = b.progress?.lastPlayedAt;
      if (pa != null && pb != null) return pb.compareTo(pa); // most recent first
      if (pa != null) return -1; // played books before never-played ones
      if (pb != null) return 1;
      return byAdded();
  }
}

/// "Continue listening" books are always ordered by most recently played;
/// the chosen [sort] applies to everything else.
BookShelf buildShelf(
  List<Book> books,
  Map<int, PlaybackProgress> progress,
  BookSort sort,
) {
  final entries = [for (final b in books) BookEntry(b, progress[b.id])];

  final current = entries.where((e) => e.inProgress).toList()
    ..sort((a, b) => b.progress!.lastPlayedAt.compareTo(a.progress!.lastPlayedAt));
  final others = entries.where((e) => !e.inProgress).toList()
    ..sort((a, b) => _compareBooks(a, b, sort));

  return BookShelf(inProgress: current, others: others);
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

class SongSortNotifier extends Notifier<SongSort> {
  @override
  SongSort build() => SongSort.title;

  void select(SongSort sort) => state = sort;
}

final songSortProvider =
    NotifierProvider<SongSortNotifier, SongSort>(SongSortNotifier.new);

class BookSortNotifier extends Notifier<BookSort> {
  @override
  BookSort build() => BookSort.title;

  void select(BookSort sort) => state = sort;
}

final bookSortProvider =
    NotifierProvider<BookSortNotifier, BookSort>(BookSortNotifier.new);

final sortedTracksProvider = Provider<AsyncValue<List<Track>>>((ref) {
  final sort = ref.watch(songSortProvider);
  return ref.watch(tracksProvider).whenData((t) => sortTracks(t, sort));
});

final artistGroupsProvider = Provider<AsyncValue<List<ArtistGroup>>>(
  (ref) => ref.watch(tracksProvider).whenData(groupByArtist),
);

final albumGroupsProvider = Provider<AsyncValue<List<AlbumGroup>>>(
  (ref) => ref.watch(tracksProvider).whenData(groupByAlbum),
);

final bookShelfProvider = Provider<AsyncValue<BookShelf>>((ref) {
  final sort = ref.watch(bookSortProvider);
  final progress = ref.watch(bookProgressProvider).value ?? const {};
  return ref
      .watch(booksProvider)
      .whenData((books) => buildShelf(books, progress, sort));
});