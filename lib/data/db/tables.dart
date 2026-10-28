import 'package:drift/drift.dart';
import 'package:music_player/models/enums.dart';
// @DataClassName avoids clashing with the domain models (Track, Book, ...).

@DataClassName('LibraryFolderRow')
class LibraryFolders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  IntColumn get kind => intEnum<FolderKind>()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
}

@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// File path or stream URL. Unique so rescans/re-adds don't duplicate.
  TextColumn get uri => text().unique()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get source => intEnum<MediaSource>()();
  DateTimeColumn get dateAdded =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('BookRow')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get narrator => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get coverPath => text().nullable()();
  IntColumn get source => intEnum<MediaSource>()();

  /// Folder path (local) or "provider:remoteId" (stream).
  TextColumn get sourceKey => text().unique()();
  DateTimeColumn get dateAdded =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('BookPartRow')
class BookParts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get partIndex => integer()();
  TextColumn get uri => text()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  IntColumn get startOffsetMs => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, partIndex},
      ];
}

@DataClassName('ChapterRow')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  TextColumn get title => text()();
  IntColumn get startMs => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {bookId, chapterIndex},
      ];
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('PlaylistTrackRow')
class PlaylistTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
}

@DataClassName('ProgressRow')
class PlaybackProgresses extends Table {
  IntColumn get kind => intEnum<MediaKind>()();

  /// Points at Tracks.id or Books.id depending on [kind]. No foreign key
  /// (polymorphic), so delete the progress row when deleting the item.
  IntColumn get itemId => integer()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  RealColumn get speed => real().withDefault(const Constant(1.0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastPlayedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {kind, itemId};
}

@DataClassName('BookmarkRow')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get positionMs => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}