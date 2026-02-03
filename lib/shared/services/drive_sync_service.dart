import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[drive.DriveApi.driveAppdataScope],
  );

  Timer? _uploadDebounce;
  String? _pendingJson;

  Future<bool> isSignedIn() => _googleSignIn.isSignedIn();

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<GoogleSignInAccount?> signInSilently() => _googleSignIn.signInSilently();

  Future<void> signOut() => _googleSignIn.signOut();

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
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return null;
    return drive.DriveApi(client);
  }

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
