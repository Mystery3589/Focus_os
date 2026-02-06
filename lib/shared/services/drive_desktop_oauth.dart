// Desktop OAuth helper (conditional import).
//
// On IO platforms, implements an OAuth 2.0 loopback (localhost) browser flow.
// On non-IO platforms, exports a stub that returns null.

export 'drive_desktop_oauth_stub.dart'
    if (dart.library.io) 'drive_desktop_oauth_io.dart';
