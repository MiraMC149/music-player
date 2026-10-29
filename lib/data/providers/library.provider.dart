import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_player/data/db/database.dart';
import 'package:music_player/data/repositories/library.repository.dart';
import 'package:music_player/data/services/library.scanner.dart';
import 'package:music_player/models/enums.dart';
import 'package:music_player/models/models.dart';
import 'package:permission_handler/permission_handler.dart';

// ---- Wiring -----------------------------------------------------------------

final libraryScannerProvider = Provider<LibraryScanner>(
  (ref) => const LibraryScanner(),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(libraryScannerProvider),
  ),
);

// ---- Data for the UI (auto-updates whenever the scanner writes rows) ---------

final tracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchTracks(),
);

final booksProvider = StreamProvider<List<Book>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchBooks(),
);

final bookProgressProvider = StreamProvider<Map<int, PlaybackProgress>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchBookProgress(),
);

final foldersProvider =
    StreamProvider.family<List<LibraryFolder>, FolderKind>(
  (ref, kind) => ref.watch(libraryRepositoryProvider).watchFolders(kind),
);

// ---- "Add folder" action ----------------------------------------------------

/// State: null = idle, loading = scanning, data = summary of the last scan,
/// error = something the user should be told about.
class AddFolderController extends AsyncNotifier<ScanSummary?> {
  @override
  Future<ScanSummary?> build() async => null;

  Future<void> addFolder(FolderKind kind) async {
    if (!await _ensureAudioPermission()) {
      state = AsyncError(
        const LibraryException('Audio permission is needed to scan folders.'),
        StackTrace.current,
      );
      return;
    }

    // In older file_picker versions this is FilePicker.platform.getDirectoryPath().
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: kind == FolderKind.music
          ? 'Choose your music folder'
          : 'Choose your audiobooks folder',
    );
    if (path == null) return; // user cancelled

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // file_picker returns "/" when Android blocks access to the chosen folder.
      if (path == '/') {
        throw const LibraryException(
          'That folder can\'t be read. Try Music, Documents or a folder you created.',
        );
      }
      return ref.read(libraryRepositoryProvider).addFolder(path, kind);
    });
  }

  Future<bool> _ensureAudioPermission() async {
    if (!Platform.isAndroid) return true;
    // Android 13+ uses READ_MEDIA_AUDIO, older versions use storage.
    if ((await Permission.audio.request()).isGranted) return true;
    return (await Permission.storage.request()).isGranted;
  }
}

final addFolderControllerProvider =
    AsyncNotifierProvider<AddFolderController, ScanSummary?>(
  AddFolderController.new,
);