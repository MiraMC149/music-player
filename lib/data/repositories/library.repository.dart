import 'package:drift/drift.dart';
import 'package:music_player/data/db/database.dart';
import 'package:music_player/data/db/mappers.dart';
import 'package:music_player/data/services/library.scanner.dart';
import 'package:music_player/models/enums.dart';
import 'package:music_player/models/models.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LibraryException implements Exception {
  const LibraryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ScanSummary {
  const ScanSummary({
    required this.kind,
    this.tracks = 0,
    this.books = 0,
    this.unreadable = 0,
  });

  final FolderKind kind;
  final int tracks;
  final int books;
  final int unreadable;
}

class LibraryRepository {
  LibraryRepository(this._db, this._scanner);

  final AppDatabase _db;
  final LibraryScanner _scanner;

  // ---- Reads (watch streams drive the UI) ---------------------------------

  Stream<List<LibraryFolder>> watchFolders(FolderKind kind) {
    final query = _db.select(_db.libraryFolders)
      ..where((f) => f.kind.equalsValue(kind));
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  Stream<List<Track>> watchTracks() {
    final query = _db.select(_db.tracks)
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  /// Parts/chapters are not loaded here, which keeps the list query cheap.
  Stream<List<Book>> watchBooks() {
    final query = _db.select(_db.books)
      ..orderBy([(b) => OrderingTerm.asc(b.title)]);
    return query.watch().map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  // ---- Folders ------------------------------------------------------------

  /// Saved progress for every book that has been played, keyed by book id.
  Stream<Map<int, PlaybackProgress>> watchBookProgress() {
    final query = _db.select(_db.playbackProgresses)
      ..where((row) => row.kind.equalsValue(MediaKind.book));
    return query.watch().map(
          (rows) => {for (final r in rows) r.itemId: r.toDomain()},
        );
  }

  /// Registers [path] as a library folder and scans it immediately.
  Future<ScanSummary> addFolder(String path, FolderKind kind) async {
    final existing = await (_db.select(_db.libraryFolders)
          ..where((f) => f.path.equals(path)))
        .getSingleOrNull();

    if (existing != null && existing.kind != kind) {
      final other = existing.kind == FolderKind.music ? 'music' : 'audiobook';
      throw LibraryException('This folder is already added as a $other folder.');
    }

    final folderId = existing?.id ??
        await _db
            .into(_db.libraryFolders)
            .insert(LibraryFoldersCompanion.insert(path: path, kind: kind));

    return rescanFolder(folderId);
  }

  Future<ScanSummary> rescanFolder(int folderId) async {
    final folder = await (_db.select(_db.libraryFolders)
          ..where((f) => f.id.equals(folderId)))
        .getSingle();

    final support = await getApplicationSupportDirectory();
    final result = await _scanner.scan(
      folderPath: folder.path,
      kind: folder.kind,
      coverDir: p.join(support.path, 'covers'),
    );

    if (!result.foundAny) {
      throw const LibraryException(
        'No audio files were found in that folder (or it could not be read).',
      );
    }

    await _save(result);

    await (_db.update(_db.libraryFolders)..where((f) => f.id.equals(folderId)))
        .write(LibraryFoldersCompanion(lastScannedAt: Value(DateTime.now())));

    return ScanSummary(
      kind: folder.kind,
      tracks: result.tracks.length,
      books: result.books.length,
      unreadable: result.unreadable,
    );
  }

  // ---- Writes -------------------------------------------------------------

  /// Upserts by `uri` / `sourceKey`, so rescans and overlapping folders never
  /// create duplicates. Omitted columns (dateAdded) keep their existing values.
  Future<void> _save(ScanResult result) {
    return _db.transaction(() async {
      await _db.batch((batch) {
        for (final t in result.tracks) {
          final row = TracksCompanion(
            title: Value(t.title),
            artist: Value(t.artist),
            album: Value(t.album),
            trackNumber: Value(t.trackNumber),
            durationMs: Value(t.durationMs),
            uri: Value(t.path),
            coverPath: Value(t.coverPath),
            source: const Value(MediaSource.local),
          );
          batch.insert(
            _db.tracks,
            row,
            onConflict: DoUpdate((_) => row, target: [_db.tracks.uri]),
          );
        }
      });

      for (final b in result.books) {
        final row = BooksCompanion(
          title: Value(b.title),
          author: Value(b.author),
          durationMs: Value(b.durationMs),
          coverPath: Value(b.coverPath),
          source: const Value(MediaSource.local),
          sourceKey: Value(b.sourceKey),
        );

        // Same book id is kept on rescan, so saved progress isn't lost.
        final saved = await _db.into(_db.books).insertReturning(
              row,
              onConflict: DoUpdate((_) => row, target: [_db.books.sourceKey]),
            );

        await (_db.delete(_db.bookParts)
              ..where((part) => part.bookId.equals(saved.id)))
            .go();

        await _db.batch((batch) {
          for (var i = 0; i < b.parts.length; i++) {
            final part = b.parts[i];
            batch.insert(
              _db.bookParts,
              BookPartsCompanion.insert(
                bookId: saved.id,
                partIndex: i,
                uri: part.path,
                durationMs: Value(part.durationMs),
                startOffsetMs: Value(part.startOffsetMs),
              ),
            );
          }
        });
      }
    });
  }
}