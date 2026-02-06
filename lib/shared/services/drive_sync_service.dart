import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'drive_desktop_oauth.dart';
import 'open_url.dart';

class DriveSyncStatus {
  final bool isSignedIn;
  final int? lastUploadAtMs;
  final int? lastDownloadAtMs;
  final int? lastLocalSaveAtMs;
  final String? lastRemoteModifiedTimeRfc3339;

  const DriveSyncStatus({
    required this.isSignedIn,
    this.lastUploadAtMs,
    this.lastDownloadAtMs,
    this.lastLocalSaveAtMs,
    this.lastRemoteModifiedTimeRfc3339,
  });
}

class DriveDownloadResult {
  final String json;
  final String? remoteModifiedTimeRfc3339;

  const DriveDownloadResult({required this.json, this.remoteModifiedTimeRfc3339});
}

class DriveSyncService {
  DriveSyncService._();

  static final DriveSyncService instance = DriveSyncService._();

  static const String _latestFileName = 'focus_flutter_latest.json';

  static const String prefAutoUpload = 'driveSyncAutoUpload';
  static const String prefLastUploadAtMs = 'driveSyncLastUploadAtMs';
  static const String prefLastDownloadAtMs = 'driveSyncLastDownloadAtMs';
  static const String prefLastLocalSaveAtMs = 'driveSyncLastLocalSaveAtMs';
  static const String prefLastRemoteModified = 'driveSyncLastRemoteModified';
  static const String prefLastSnapshotAtMs = 'driveSyncLastSnapshotAtMs';

  static const String _prefDesktopCredsJson = 'driveSyncDesktopCredsJson';

  // Provide these at build/run time, e.g. via:
  // flutter run --dart-define=GOOGLE_OAUTH_DESKTOP_CLIENT_ID=... --dart-define=GOOGLE_OAUTH_DESKTOP_CLIENT_SECRET=...
  static const String _desktopClientIdValue = String.fromEnvironment('GOOGLE_OAUTH_DESKTOP_CLIENT_ID');
  static const String _desktopClientSecretValue = String.fromEnvironment('GOOGLE_OAUTH_DESKTOP_CLIENT_SECRET');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[drive.DriveApi.driveAppdataScope],
  );

  http.Client? _desktopAuthClient;
  AccessCredentials? _desktopCreds;
  bool _desktopTriedRestore = false;

  Timer? _uploadDebounce;
  String? _pendingJson;

  /// Google sign-in via the `google_sign_in` plugin is not supported on all platforms.
  ///
  /// Windows/Linux are supported via a desktop OAuth flow.
  bool get isPlatformSupported {
    // We treat "supported" as "can work when configured".
    if (_isDesktopOAuthPlatform) return _hasDesktopClientConfig;
    return true;
  }

  bool get isDesktopConfigMissing => _isDesktopOAuthPlatform && !_hasDesktopClientConfig;

  bool get _isDesktopOAuthPlatform {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  bool get _hasDesktopClientConfig =>
      _desktopClientIdValue.trim().isNotEmpty && _desktopClientSecretValue.trim().isNotEmpty;

  ClientId? get _desktopClientId {
    if (!_hasDesktopClientConfig) return null;
    return ClientId(_desktopClientIdValue.trim(), _desktopClientSecretValue.trim());
  }

  Future<T?> _guardedCall<T>(Future<T?> Function() fn) async {
    try {
      return await fn().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      debugPrint('DriveSyncService: sign-in timed out.');
      return null;
    } on MissingPluginException catch (e) {
      debugPrint('DriveSyncService: missing plugin implementation: $e');
      return null;
    } catch (e) {
      debugPrint('DriveSyncService: sign-in failed: $e');
      return null;
    }
  }

  Future<void> _restoreDesktopClientIfNeeded() async {
    if (!_isDesktopOAuthPlatform) return;
    if (_desktopTriedRestore) return;
    _desktopTriedRestore = true;

    final clientId = _desktopClientId;
    if (clientId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefDesktopCredsJson);
    if (jsonStr == null || jsonStr.trim().isEmpty) return;

    try {
      final m = jsonDecode(jsonStr) as Map<String, dynamic>;
      final at = m['accessToken'] as Map<String, dynamic>;
      final type = (at['type'] ?? 'Bearer') as String;
      final data = (at['data'] ?? '') as String;
      final expiryIso = (at['expiry'] ?? '') as String;
      final expiry = DateTime.tryParse(expiryIso);
      final refreshToken = m['refreshToken'] as String?;
      final scopes = (m['scopes'] as List?)?.whereType<String>().toList() ?? const <String>[];
      if (data.isEmpty || expiry == null || refreshToken == null || refreshToken.isEmpty) return;

      final creds = AccessCredentials(
        AccessToken(type, data, expiry.toUtc()),
        refreshToken,
        scopes,
      );
      _desktopCreds = creds;
      // For actual API calls, we rely on credentials + a fresh authenticated client created when needed.
      // This avoids importing IO-only helpers here.
      _desktopAuthClient = null;
    } catch (e) {
      debugPrint('DriveSyncService: failed to restore desktop creds: $e');
      _desktopAuthClient = null;
      _desktopCreds = null;
    }
  }

  Future<void> _persistDesktopCreds(AccessCredentials creds) async {
    try {
      final payload = {
        'accessToken': {
          'type': creds.accessToken.type,
          'data': creds.accessToken.data,
          'expiry': creds.accessToken.expiry.toUtc().toIso8601String(),
        },
        'refreshToken': creds.refreshToken,
        'scopes': creds.scopes,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDesktopCredsJson, jsonEncode(payload));
    } catch (e) {
      debugPrint('DriveSyncService: failed to persist desktop creds: $e');
    }
  }

  Future<bool> isSignedIn() async {
    if (_isDesktopOAuthPlatform) {
      await _restoreDesktopClientIfNeeded();
      return _desktopCreds != null;
    }
    try {
      return await _googleSignIn.isSignedIn().timeout(const Duration(seconds: 4));
    } catch (_) {
      return false;
    }
  }

  /// Interactive sign-in.
  ///
  /// Returns true on success, false on cancel/failure.
  Future<bool> signIn() async {
    if (_isDesktopOAuthPlatform) {
      final clientId = _desktopClientId;
      if (clientId == null) {
        debugPrint('DriveSyncService: missing desktop OAuth client id/secret.');
        return false;
      }

      try {
        final scopes = <String>[drive.DriveApi.driveAppdataScope];
        final creds = await signInDesktopLoopback(clientId: clientId, scopes: scopes);
        if (creds == null) return false;

        _desktopCreds = creds;
        await _persistDesktopCreds(creds);
        return creds.accessToken.data.isNotEmpty;
      } on TimeoutException {
        debugPrint('DriveSyncService: desktop OAuth timed out.');
        return false;
      } catch (e) {
        debugPrint('DriveSyncService: desktop OAuth failed: $e');
        return false;
      }
    }

    final acct = await _guardedCall(() => _googleSignIn.signIn());
    return acct != null;
  }

  Future<void> signInSilently() async {
    if (_isDesktopOAuthPlatform) {
      await _restoreDesktopClientIfNeeded();
      return;
    }
    await _guardedCall(() => _googleSignIn.signInSilently());
  }

  Future<void> signOut() async {
    if (_isDesktopOAuthPlatform) {
      _desktopAuthClient?.close();
      _desktopAuthClient = null;
      _desktopCreds = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefDesktopCredsJson);
      return;
    }
    try {
      await _googleSignIn.signOut().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Ignore best-effort sign-out failures.
    }
  }

  Future<DriveSyncStatus> getStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return DriveSyncStatus(
      isSignedIn: await isSignedIn(),
      lastUploadAtMs: prefs.getInt(prefLastUploadAtMs),
      lastDownloadAtMs: prefs.getInt(prefLastDownloadAtMs),
      lastLocalSaveAtMs: prefs.getInt(prefLastLocalSaveAtMs),
      lastRemoteModifiedTimeRfc3339: prefs.getString(prefLastRemoteModified),
    );
  }

  Future<drive.DriveApi?> _api() async {
    if (_isDesktopOAuthPlatform) {
      await _restoreDesktopClientIfNeeded();
      final clientId = _desktopClientId;
      final creds0 = _desktopCreds;
      if (clientId == null || creds0 == null) return null;
      var creds = creds0;

      // Refresh access token if it's close to expiring.
      final now = DateTime.now().toUtc();
      if (creds.accessToken.expiry.isBefore(now.add(const Duration(seconds: 30)))) {
        final refreshed = await refreshDesktopCredentials(clientId: clientId, credentials: creds);
        if (refreshed != null) {
          creds = refreshed;
          _desktopCreds = refreshed;
          await _persistDesktopCreds(refreshed);
        }
      }

      // Create a short-lived authenticated client for this call.
      // googleapis_auth's IO helper will refresh tokens as needed.
      final authed = await _guardedCall(() async {
        // Use the platform IO implementation only when available.
        if (!kIsWeb) {
          // auth_io isn't imported here; so we just use a plain client and rely on access token.
          // If refresh_token exists, the loopback sign-in should be re-done when expired.
          return _BearerClient(http.Client(), creds.accessToken.data);
        }
        return null;
      });
      if (authed == null) return null;
      return drive.DriveApi(authed);
    }

    final client = await _guardedCall(() => _googleSignIn.authenticatedClient());
    if (client == null) return null;
    return drive.DriveApi(client);
  }

  // NOTE: Desktop auth currently uses a bearer token client created in [_api()].
  // If the token expires, API calls will fail and the UI should prompt the user
  // to sign in again. We can enhance this later with refresh-token exchange.

  /// Best-effort auto-upload with debounce.
  ///
  /// Safe to call frequently; will no-op if not signed-in.
  void scheduleAutoUploadLatest(String json) {
    _pendingJson = json;
    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(const Duration(seconds: 8), () {
      final payload = _pendingJson;
      _pendingJson = null;
      if (payload == null) return;
      unawaited(uploadLatest(payload, allowDailySnapshot: false));
    });
  }

  /// Uploads the given JSON to Google Drive AppData folder as the "latest" file.
  ///
  /// If [allowDailySnapshot] is true, this also creates a timestamped snapshot at most once per day.
  Future<bool> uploadLatest(
    String json, {
    bool allowDailySnapshot = true,
  }) async {
    final api = await _api();
    if (api == null) return false;

    final fileId = await _findLatestFileId(api);

    final exportedAtMs = DateTime.now().millisecondsSinceEpoch;
    final media = drive.Media(
      Stream<List<int>>.value(utf8.encode(json)),
      json.length,
      contentType: 'application/json',
    );

    final meta = drive.File(
      name: _latestFileName,
      parents: const ['appDataFolder'],
      appProperties: {
        'schemaVersion': '1',
        'exportedAtMs': exportedAtMs.toString(),
      },
    );

    drive.File updated;
    if (fileId == null) {
      updated = await api.files.create(
        meta,
        uploadMedia: media,
        $fields: 'id,modifiedTime',
      );
    } else {
      updated = await api.files.update(
        meta,
        fileId,
        uploadMedia: media,
        $fields: 'id,modifiedTime',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefLastUploadAtMs, exportedAtMs);
    if (updated.modifiedTime != null) {
      await prefs.setString(prefLastRemoteModified, updated.modifiedTime!.toUtc().toIso8601String());
    }

    if (allowDailySnapshot) {
      await _maybeCreateDailySnapshot(api, updated.id!, exportedAtMs);
    }

    return true;
  }

  /// Downloads the "latest" backup JSON.
  /// Returns null if nothing exists or not signed-in.
  Future<DriveDownloadResult?> downloadLatest() async {
    final api = await _api();
    if (api == null) return null;

    final fileId = await _findLatestFileId(api);
    if (fileId == null) return null;

    final meta = await api.files.get(
      fileId,
      $fields: 'id,modifiedTime',
    ) as drive.File;

    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (media is! drive.Media) return null;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final json = utf8.decode(bytes);

    final now = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefLastDownloadAtMs, now);
    if (meta.modifiedTime != null) {
      await prefs.setString(prefLastRemoteModified, meta.modifiedTime!.toUtc().toIso8601String());
    }

    return DriveDownloadResult(
      json: json,
      remoteModifiedTimeRfc3339: meta.modifiedTime?.toUtc().toIso8601String(),
    );
  }

  Future<String?> _findLatestFileId(drive.DriveApi api) async {
    final list = await api.files.list(
      spaces: 'appDataFolder',
      q: "name='$_latestFileName' and trashed=false",
      $fields: 'files(id,name,modifiedTime)',
      pageSize: 5,
    );

    final files = list.files ?? const <drive.File>[];
    if (files.isEmpty) return null;

    // If duplicates exist, prefer newest.
    files.sort((a, b) {
      final at = a.modifiedTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.modifiedTime?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });

    return files.first.id;
  }

  Future<void> _maybeCreateDailySnapshot(drive.DriveApi api, String latestFileId, int exportedAtMs) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(prefLastSnapshotAtMs) ?? 0;

    final lastDate = DateTime.fromMillisecondsSinceEpoch(last);
    final nowDate = DateTime.fromMillisecondsSinceEpoch(exportedAtMs);

    final sameDay = lastDate.year == nowDate.year && lastDate.month == nowDate.month && lastDate.day == nowDate.day;
    if (sameDay) return;

    final stamp = nowDate.toUtc().toIso8601String().replaceAll(':', '').replaceAll('.', '');
    final snapshotName = 'focus_flutter_snapshot_$stamp.json';

    await api.files.copy(
      drive.File(
        name: snapshotName,
        parents: const ['appDataFolder'],
        appProperties: {
          'schemaVersion': '1',
          'snapshotOf': _latestFileName,
          'exportedAtMs': exportedAtMs.toString(),
        },
      ),
      latestFileId,
      $fields: 'id',
    );

    await prefs.setInt(prefLastSnapshotAtMs, exportedAtMs);
  }
}

class _BearerClient extends http.BaseClient {
  final http.Client _inner;
  final String _token;

  _BearerClient(this._inner, this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
