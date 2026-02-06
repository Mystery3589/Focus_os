import 'dart:io';

Future<void> openUrl(String url) async {
  try {
    if (Platform.isWindows) {
      // cmd /c start "" <url>
      await Process.run('cmd', ['/c', 'start', '', url], runInShell: true);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
      return;
    }
    // Linux and others
    await Process.run('xdg-open', [url]);
  } catch (_) {
    // Best-effort.
  }
}
