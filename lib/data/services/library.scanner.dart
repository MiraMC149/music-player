import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:music_player/models/enums.dart';
import 'package:path/path.dart' as p;

// ---------------------------------------------------------------------------
// Result types: plain data only, so they can cross the isolate boundary.
// ---------------------------------------------------------------------------

class ScannedTrack {
  const ScannedTrack({
    required this.path,
    required this.title,
    this.artist,
    this.album,
    this.trackNumber,
    this.durationMs = 0,
    this.coverPath,
  });

  final String path;
  final String title;
  final String? artist;
  final String? album;
  final int? trackNumber;
  final int durationMs;
  final String? coverPath;
}

class ScannedPart {
  const ScannedPart({
    required this.path,
    required this.durationMs,
    required this.startOffsetMs,
  });

  final String path;
  final int durationMs;
  final int startOffsetMs;
}

class ScannedBook {
  const ScannedBook({
    required this.sourceKey,
    required this.title,
    required this.parts,
    this.author,
    this.durationMs = 0,
    this.coverPath,
  });

  /// Folder path (multi-file book) or file path (single .m4b).
  final String sourceKey;
  final String title;
  final String? author;
  final int durationMs;
  final String? coverPath;
  final List<ScannedPart> parts;
}

class ScanResult {
  const ScanResult({
    this.tracks = const [],
    this.books = const [],
    this.unreadable = 0,
  });

  final List<ScannedTrack> tracks;
  final List<ScannedBook> books;

  /// Files found but whose tags couldn't be parsed (they're still added,
  /// using the file name as the title).
  final int unreadable;

  bool get foundAny => tracks.isNotEmpty || books.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

class LibraryScanner {
  const LibraryScanner();

  /// Walks [folderPath] recursively and reads tags for every audio file.
  /// Runs on a background isolate so the UI stays smooth on big libraries.
  /// [coverDir] is where extracted cover art is saved.
  Future<ScanResult> scan({
    required String folderPath,
    required FolderKind kind,
    required String coverDir,
  }) {
    return Isolate.run(() => _scan(folderPath, kind, coverDir));
  }
}

// ---------------------------------------------------------------------------
// Implementation (runs inside the isolate)
// ---------------------------------------------------------------------------

const _musicExts = {'.mp3', '.m4a', '.flac', '.ogg', '.opus', '.wav', '.aac'};
const _bookExts = {..._musicExts, '.m4b'};
const _imageExts = ['.jpg', '.jpeg', '.png'];
const _coverNames = ['cover', 'folder', 'front'];

// "CD 1", "Disc2", "Part 03" ... subfolders belong to the book above them.
final _discDir = RegExp(r'^(cd|disc|disk|part)[\s_.-]*\d+$', caseSensitive: false);
final _chunks = RegExp(r'(\d+|\D+)');

Future<ScanResult> _scan(String root, FolderKind kind, String coverDir) async {
  await Directory(coverDir).create(recursive: true);
  final exts = kind == FolderKind.music ? _musicExts : _bookExts;

  final files = <File>[];
  final entries = Directory(root)
      .list(recursive: true, followLinks: false)
      // Skip folders we aren't allowed to read instead of aborting the scan.
      .handleError((_) {}, test: (e) => e is FileSystemException);

  await for (final entry in entries) {
    if (entry is! File) continue;
    if (!exts.contains(p.extension(entry.path).toLowerCase())) continue;
    final relative = p.split(p.relative(entry.path, from: root));
    if (relative.any((segment) => segment.startsWith('.'))) continue; // hidden
    files.add(entry);
  }

  files.sort((a, b) => _naturalCompare(a.path, b.path));

  return kind == FolderKind.music
      ? _scanMusic(files, coverDir)
      : _scanBooks(root, files, coverDir);
}

ScanResult _scanMusic(List<File> files, String coverDir) {
  final tracks = <ScannedTrack>[];
  final triedCovers = <String>{};
  var unreadable = 0;

  for (final file in files) {
    AudioMetadata? meta;
    try {
      meta = readMetadata(file, getImage: false);
    } catch (_) {
      unreadable++;
    }

    final artist = _clean(meta?.artist);
    final album = _clean(meta?.album);
    // One cover file per album instead of one per track.
    final coverKey = album != null ? '${artist ?? ''}|$album' : file.path;

    tracks.add(ScannedTrack(
      path: file.path,
      title: _clean(meta?.title) ?? p.basenameWithoutExtension(file.path),
      artist: artist,
      album: album,
      trackNumber: meta?.trackNumber,
      durationMs: meta?.duration?.inMilliseconds ?? 0,
      coverPath: meta == null
          ? null
          : _extractCover(file, coverKey, coverDir, triedCovers),
    ));
  }

  return ScanResult(tracks: tracks, unreadable: unreadable);
}

ScanResult _scanBooks(String root, List<File> files, String coverDir) {
  // Grouping rules:
  //  * every .m4b file is its own book
  //  * any other audio files are grouped by folder (one folder = one book),
  //    and "CD 1" / "Disc 2" subfolders are merged into their parent book
  final groups = <String, List<File>>{};
  for (final file in files) {
    final isM4b = p.extension(file.path).toLowerCase() == '.m4b';
    final key = isM4b ? file.path : _bookDir(root, file.parent.path);
    groups.putIfAbsent(key, () => []).add(file);
  }

  final books = <ScannedBook>[];
  final triedCovers = <String>{};
  var unreadable = 0;

  for (final entry in groups.entries) {
    final key = entry.key;
    final group = entry.value; // already naturally sorted
    final isSingleFile = File(key).existsSync() && group.length == 1;

    var offset = 0;
    AudioMetadata? firstMeta;
    final parts = <ScannedPart>[];

    for (final file in group) {
      AudioMetadata? meta;
      try {
        meta = readMetadata(file, getImage: false);
      } catch (_) {
        unreadable++;
      }
      firstMeta ??= meta;
      final duration = meta?.duration?.inMilliseconds ?? 0;
      parts.add(ScannedPart(
        path: file.path,
        durationMs: duration,
        startOffsetMs: offset,
      ));
      offset += duration;
    }

    final fallbackTitle = isSingleFile
        ? p.basenameWithoutExtension(key)
        : p.basename(key);

    String? cover = firstMeta == null
        ? null
        : _extractCover(group.first, 'book|$key', coverDir, triedCovers);
    if (cover == null && !isSingleFile) cover = _folderImage(key);

    books.add(ScannedBook(
      sourceKey: key,
      title: _clean(firstMeta?.album) ??
          (isSingleFile ? _clean(firstMeta?.title) : null) ??
          fallbackTitle,
      author: _clean(firstMeta?.artist),
      durationMs: offset,
      coverPath: cover,
      parts: parts,
    ));
  }

  books.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return ScanResult(books: books, unreadable: unreadable);
}

String _bookDir(String root, String dir) {
  if (_discDir.hasMatch(p.basename(dir))) {
    final parent = p.dirname(dir);
    if (p.equals(parent, root) || p.isWithin(root, parent)) return parent;
  }
  return dir;
}

/// Saves the first embedded picture to [coverDir] and returns its path.
/// Each [key] is only attempted once per scan, and reused if already saved.
String? _extractCover(
  File file,
  String key,
  String coverDir,
  Set<String> tried,
) {
  final out = File(p.join(coverDir, '${_stableHash(key)}.jpg'));
  if (out.existsSync()) return out.path;
  if (!tried.add(key)) return null;
  try {
    final pictures = readMetadata(file, getImage: true).pictures;
    if (pictures.isEmpty) return null;
    out.writeAsBytesSync(pictures.first.bytes);
    return out.path;
  } catch (_) {
    return null;
  }
}

/// cover.jpg / folder.png etc. next to the audio files.
String? _folderImage(String dir) {
  for (final name in _coverNames) {
    for (final ext in _imageExts) {
      final f = File(p.join(dir, '$name$ext'));
      if (f.existsSync()) return f.path;
    }
  }
  return null;
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// "Chapter 2" sorts before "Chapter 10".
int _naturalCompare(String a, String b) {
  final pa = _chunks.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final pb = _chunks.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  final n = pa.length < pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = pa[i];
    final y = pb[i];
    final xn = int.tryParse(x);
    final yn = int.tryParse(y);
    final c = (xn != null && yn != null) ? xn.compareTo(yn) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// Stable across app launches (String.hashCode isn't guaranteed to be).
String _stableHash(String input) {
  int fnv(int seed) {
    var h = seed;
    for (final c in input.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  return fnv(0x811c9dc5).toRadixString(16).padLeft(8, '0') +
      fnv(0x01234567).toRadixString(16).padLeft(8, '0');
}