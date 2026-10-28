import 'package:music_player/data/db/database.dart';
import 'package:music_player/models/models.dart';

Duration _ms(int value) => Duration(milliseconds: value);

extension TrackRowX on TrackRow {
  Track toDomain() => Track(
    id: id,
    title: title,
    artist: artist,
    album: album,
    trackNumber: trackNumber,
    duration: _ms(durationMs),
    uri: uri,
    coverPath: coverPath,
    source: source,
    dateAdded: dateAdded,
  );
}

extension BookPartRowX on BookPartRow {
  BookPart toDomain() => BookPart(
    id: id,
    bookId: bookId,
    index: partIndex,
    uri: uri,
    duration: _ms(durationMs),
    startOffset: _ms(startOffsetMs),
  );
}

extension ChapterRowX on ChapterRow {
  Chapter toDomain() => Chapter(
    id: id,
    bookId: bookId,
    index: chapterIndex,
    title: title,
    start: _ms(startMs),
  );
}

extension BookRowX on BookRow {
  /// Pass parts/chapters only when opening or playing a book; list views
  /// can skip them to keep queries cheap.
  Book toDomain({
    List<BookPartRow> parts = const [],
    List<ChapterRow> chapters = const [],
  }) => Book(
    id: id,
    title: title,
    author: author,
    narrator: narrator,
    description: description,
    duration: _ms(durationMs),
    coverPath: coverPath,
    source: source,
    sourceKey: sourceKey,
    dateAdded: dateAdded,
    parts: parts.map((p) => p.toDomain()).toList(),
    chapters: chapters.map((c) => c.toDomain()).toList(),
  );
}

extension PlaylistRowX on PlaylistRow {
  Playlist toDomain({int trackCount = 0}) => Playlist(
    id: id,
    name: name,
    createdAt: createdAt,
    trackCount: trackCount,
  );
}

extension BookmarkRowX on BookmarkRow {
  Bookmark toDomain() => Bookmark(
    id: id,
    bookId: bookId,
    position: _ms(positionMs),
    note: note,
    createdAt: createdAt,
  );
}

extension LibraryFolderRowX on LibraryFolderRow {
  LibraryFolder toDomain() => LibraryFolder(
    id: id,
    path: path,
    kind: kind,
    lastScannedAt: lastScannedAt,
  );
}

extension ProgressRowX on ProgressRow {
  PlaybackProgress toDomain() => PlaybackProgress(
    kind: kind,
    itemId: itemId,
    position: _ms(positionMs),
    speed: speed,
    completed: completed,
    lastPlayedAt: lastPlayedAt,
  );
}
