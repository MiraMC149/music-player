import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:riverpod/riverpod.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  LibraryFolders,
  Tracks,
  Books,
  BookParts,
  Chapters,
  Playlists,
  PlaylistTracks,
  PlaybackProgresses,
  Bookmarks,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'library'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // Add onUpgrade steps here whenever schemaVersion increases.
        beforeOpen: (details) async {
          // Required for ON DELETE CASCADE to actually work in SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});