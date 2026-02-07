import 'dart:io';

Future<void> openUrl(String url) async {
  try {
    if (Platform.isWindows) {
      // IMPORTANT (Windows): Avoid `cmd /c start <url>` without quotes.
      // `cmd.exe` treats '&' as a command separator, which truncates OAuth URLs
      // (e.g. dropping `response_type=code`) and breaks Google sign-in.
      // Use the Windows URL handler directly.
      final u = url.trim();
      if (u.isEmpty) return;

      // Primary: rundll32 url.dll,FileProtocolHandler <url>
      final r1 = await Process.run('rundll32', ['url.dll,FileProtocolHandler', u]);
      if (r1.exitCode == 0) return;

      // Fallback: explorer.exe <url>
      final r2 = await Process.run('explorer.exe', [u]);
      if (r2.exitCode == 0) return;

      // Last resort: cmd/start with a quoted URL.
      await Process.run('cmd', ['/c', 'start', '""', '"$u"']);
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
