/// Where the audio comes from. Drives how the player resolves `uri`.
enum MediaSource { local, stream }

/// Which kind of item a progress row / UI entry refers to.
enum MediaKind { track, book }

/// What a scanned library folder contains (chosen by the user when adding it).
enum FolderKind { music, audiobooks }