import 'enums.dart';

// ---------------------------------------------------------------------------
// Library items
// ---------------------------------------------------------------------------

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.uri,
    required this.source,
    required this.dateAdded,
    this.artist,
    this.album,
    this.trackNumber,
    this.duration = Duration.zero,
    this.coverPath,
  });

  final int id;
  final String title;
  final String? artist;
  final String? album;
  final int? trackNumber;
  final Duration duration;

  /// File path (local) or URL (stream).
  final String uri;
  final String? coverPath;
  final MediaSource source;
  final DateTime dateAdded;

  bool get isLocal => source == MediaSource.local;
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.sourceKey,
    required this.source,
    required this.dateAdded,
    this.author,
    this.narrator,
    this.description,
    this.duration = Duration.zero,
    this.coverPath,
    this.parts = const [],
    this.chapters = const [],
  });

  final int id;
  final String title;
  final String? author;
  final String? narrator;
  final String? description;
  final Duration duration;
  final String? coverPath;
  final MediaSource source;

  /// Unique identity: folder path for local books, "provider:remoteId" for
  /// streamed ones (e.g. "librivox:1234"). Prevents duplicates on rescan/re-add.
  final String sourceKey;
  final DateTime dateAdded;

  /// Empty in list views; populated when a book is opened/played.
  final List<BookPart> parts;
  final List<Chapter> chapters;

  bool get isMultiFile => parts.length > 1;
  bool get hasChapters => chapters.isNotEmpty;

  Book copyWith({List<BookPart>? parts, List<Chapter>? chapters}) => Book(
        id: id,
        title: title,
        sourceKey: sourceKey,
        source: source,
        dateAdded: dateAdded,
        author: author,
        narrator: narrator,
        description: description,
        duration: duration,
        coverPath: coverPath,
        parts: parts ?? this.parts,
        chapters: chapters ?? this.chapters,
      );
}

/// One audio file of a book. Single-file M4B books have exactly one part.
class BookPart {
  const BookPart({
    required this.id,
    required this.bookId,
    required this.index,
    required this.uri,
    this.duration = Duration.zero,
    this.startOffset = Duration.zero,
  });

  final int id;
  final int bookId;
  final int index;
  final String uri;
  final Duration duration;

  /// Where this part starts inside the whole book (sum of earlier parts).
  final Duration startOffset;
}

class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    required this.start,
  });

  final int id;
  final int bookId;
  final int index;
  final String title;

  /// Global offset from the start of the book.
  final Duration start;
}

// ---------------------------------------------------------------------------
// Playlists, bookmarks, folders
// ---------------------------------------------------------------------------

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.trackCount = 0,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final int trackCount;
}

class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.position,
    required this.createdAt,
    this.note,
  });

  final int id;
  final int bookId;

  /// Global position inside the book.
  final Duration position;
  final String? note;
  final DateTime createdAt;
}

/// A folder the user added for scanning.
class LibraryFolder {
  const LibraryFolder({
    required this.id,
    required this.path,
    required this.kind,
    this.lastScannedAt,
  });

  final int id;
  final String path;
  final FolderKind kind;
  final DateTime? lastScannedAt;
}

// ---------------------------------------------------------------------------
// Playback progress
// ---------------------------------------------------------------------------

class PlaybackProgress {
  const PlaybackProgress({
    required this.kind,
    required this.itemId,
    required this.position,
    required this.lastPlayedAt,
    this.speed = 1.0,
    this.completed = false,
  });

  final MediaKind kind;
  final int itemId;

  /// For books this is the GLOBAL position across all parts.
  final Duration position;
  final double speed;
  final bool completed;
  final DateTime lastPlayedAt;

  PlaybackProgress copyWith({
    Duration? position,
    double? speed,
    bool? completed,
    DateTime? lastPlayedAt,
  }) =>
      PlaybackProgress(
        kind: kind,
        itemId: itemId,
        position: position ?? this.position,
        speed: speed ?? this.speed,
        completed: completed ?? this.completed,
        lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      );
}

/// Convenience pairing for the homepage "Continue listening" row.
class ContinueListeningItem {
  const ContinueListeningItem({required this.book, required this.progress});

  final Book book;
  final PlaybackProgress progress;

  double get fraction => book.duration.inMilliseconds == 0
      ? 0
      : (progress.position.inMilliseconds / book.duration.inMilliseconds)
          .clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Remote search results (not stored until the user adds them to the library)
// ---------------------------------------------------------------------------

class RemotePart {
  const RemotePart({
    required this.title,
    required this.url,
    this.duration = Duration.zero,
  });

  final String title;
  final String url;
  final Duration duration;
}

class RemoteBook {
  const RemoteBook({
    required this.provider,
    required this.remoteId,
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    this.duration = Duration.zero,
    this.parts = const [],
  });

  /// e.g. "librivox", "archive".
  final String provider;
  final String remoteId;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final Duration duration;

  /// May be empty in search results and fetched on demand when opened.
  final List<RemotePart> parts;

  String get sourceKey => '$provider:$remoteId';
}

class RemoteTrack {
  const RemoteTrack({
    required this.provider,
    required this.remoteId,
    required this.title,
    required this.streamUrl,
    this.artist,
    this.album,
    this.coverUrl,
    this.duration = Duration.zero,
  });

  /// e.g. "jamendo", "fma".
  final String provider;
  final String remoteId;
  final String title;
  final String? artist;
  final String? album;
  final String streamUrl;
  final String? coverUrl;
  final Duration duration;

  String get sourceKey => '$provider:$remoteId';
}