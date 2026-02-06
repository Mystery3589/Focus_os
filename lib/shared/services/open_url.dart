// Conditional openUrl implementation.
//
// - IO platforms (Windows/macOS/Linux): uses platform shell to open the browser.
// - Web: uses window.open.
// - Fallback: no-op.

import 'open_url_stub.dart'
    if (dart.library.io) 'open_url_io.dart'
    if (dart.library.html) 'open_url_web.dart';

export 'open_url_stub.dart'
    if (dart.library.io) 'open_url_io.dart'
    if (dart.library.html) 'open_url_web.dart';
