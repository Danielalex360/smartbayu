// Platform-safe re-export of dart:io
// On web: exports stubs. On mobile/desktop: exports real dart:io.
export 'platform_io_stub.dart' if (dart.library.io) 'dart:io';
