import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/services/drive_sync_service.dart';
import '../../shared/services/local_backup_service.dart';
import '../../shared/widgets/cyber_card.dart';

class CloudSyncScreen extends ConsumerStatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  ConsumerState<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends ConsumerState<CloudSyncScreen> {
  bool _loading = true;
  bool _signedIn = false;
  bool _autoUpload = false;
  DriveSyncStatus? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();

    // Best-effort silent sign-in so returning users feel "synced".
    await DriveSyncService.instance.signInSilently();

    final signedIn = await DriveSyncService.instance.isSignedIn();
    final status = await DriveSyncService.instance.getStatus();

    setState(() {
      _autoUpload = prefs.getBool(DriveSyncService.prefAutoUpload) ?? false;
      _signedIn = signedIn;
      _status = status;
      _loading = false;
    });
  }

  String _fmtMs(int? ms) {
    if (ms == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtRfc3339(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/settings'),
        ),
        title: const Text('Cloud sync', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CyberCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Google Drive (App data)', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Sync uses a hidden AppData folder in your Google Drive. We store a single “latest” JSON plus an optional daily snapshot.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatusPill(
                        label: _signedIn ? 'Signed in' : 'Signed out',
                        color: _signedIn ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      const Spacer(),
                      if (_loading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _kv('Last upload', _fmtMs(_status?.lastUploadAtMs)),
                  _kv('Last download', _fmtMs(_status?.lastDownloadAtMs)),
                  _kv('Last local save', _fmtMs(_status?.lastLocalSaveAtMs)),
                  _kv('Remote modified', _status?.lastRemoteModifiedTimeRfc3339 ?? '—'),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-upload changes', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Best-effort: uploads after local saves (debounced). Requires you to be signed in.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    value: _autoUpload,
                    onChanged: (val) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(DriveSyncService.prefAutoUpload, val);
                      setState(() => _autoUpload = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          await DriveSyncService.instance.signIn();
                          await _refresh();
                        },
                  icon: const Icon(LucideIcons.logIn, size: 16),
                  label: const Text('Sign in'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                ),
                OutlinedButton.icon(
                  onPressed: (!_signedIn || _loading)
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          await DriveSyncService.instance.signOut();
                          await _refresh();
                        },
                  icon: const Icon(LucideIcons.logOut, size: 16),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.borderColor)),
                ),
                OutlinedButton.icon(
                  onPressed: (!_signedIn || _loading)
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          final json = ref.read(userProvider.notifier).exportUserStatsJson(pretty: false);
                          final ok = await DriveSyncService.instance.uploadLatest(json, allowDailySnapshot: true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? 'Uploaded to Google Drive.' : 'Upload failed (not signed in or misconfigured).')),
                            );
                          }
                          await _refresh();
                        },
                  icon: const Icon(LucideIcons.uploadCloud, size: 16),
                  label: const Text('Upload now'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.borderColor)),
                ),
                OutlinedButton.icon(
                  onPressed: (!_signedIn || _loading)
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          final dl = await DriveSyncService.instance.downloadLatest();
                          if (dl == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No remote backup found.')),
                              );
                            }
                            await _refresh();
                            return;
                          }

                          if (!mounted) return;

                          // Capture current local state before any overwrite.
                          final localBefore = ref.read(userProvider.notifier).exportUserStatsJson(pretty: false);

                          // Conflict detection: if local has changes since last upload and remote is newer than last upload.
                          final statusNow = await DriveSyncService.instance.getStatus();
                          final lastUploadAt = statusNow.lastUploadAtMs ?? 0;
                          final lastLocalSaveAt = statusNow.lastLocalSaveAtMs ?? 0;

                          int remoteModifiedMs = 0;
                          final remoteIso = dl.remoteModifiedTimeRfc3339;
                          if (remoteIso != null) {
                            try {
                              remoteModifiedMs = DateTime.parse(remoteIso).toUtc().millisecondsSinceEpoch;
                            } catch (_) {
                              remoteModifiedMs = 0;
                            }
                          }

                          final localHasUnuploadedChanges = lastLocalSaveAt > lastUploadAt;
                          final remoteNewerThanLastUpload = remoteModifiedMs > lastUploadAt;

                          if (localHasUnuploadedChanges && remoteNewerThanLastUpload) {
                            final action = await _resolveConflict(
                              context,
                              remoteModifiedRfc3339: dl.remoteModifiedTimeRfc3339,
                              lastUploadAtMs: statusNow.lastUploadAtMs,
                              lastLocalSaveAtMs: statusNow.lastLocalSaveAtMs,
                            );

                            if (action == _ConflictAction.cancel) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sync cancelled.')),
                              );
                              await _refresh();
                              return;
                            }

                            if (action == _ConflictAction.uploadLocal) {
                              final json = ref.read(userProvider.notifier).exportUserStatsJson(pretty: false);
                              final ok = await DriveSyncService.instance.uploadLatest(json, allowDailySnapshot: true);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ok ? 'Uploaded local version to Google Drive.' : 'Upload failed.')),
                                );
                              }
                              await _refresh();
                              return;
                            }
                            // else: proceed to overwrite with remote.
                          }

                          final confirmed = await _confirmOverwriteFromDrive(
                            context,
                            remoteModifiedRfc3339: dl.remoteModifiedTimeRfc3339,
                          );
                          if (!confirmed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Import cancelled.')),
                            );
                            await _refresh();
                            return;
                          }

                          // Best-effort safety net: save local restore point.
                          await LocalBackupService.instance.saveRestorePoint(
                            json: localBefore,
                            reason: 'drive_download_overwrite',
                          );

                          final ok = await ref.read(userProvider.notifier).importUserStatsJson(dl.json);
                          if (!mounted) return;

                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Import failed (invalid or incompatible backup).')),
                            );
                            await _refresh();
                            return;
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Downloaded and imported.'),
                              duration: const Duration(seconds: 8),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  unawaited(_undoRestoreLocal(localBefore));
                                },
                              ),
                            ),
                          );

                          await _refresh();
                        },
                  icon: const Icon(LucideIcons.downloadCloud, size: 16),
                  label: const Text('Download now'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, side: const BorderSide(color: AppTheme.borderColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CyberCard(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Note: Google Drive sync requires enabling the Drive API for your app in Google Cloud and configuring OAuth consent. If you haven\'t done that yet, sign-in may succeed but uploads/downloads can fail.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _undoRestoreLocal(String json) async {
    final restored = await ref.read(userProvider.notifier).importUserStatsJson(json);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(restored ? 'Restored previous local data.' : 'Undo failed.')),
    );
    await _refresh();
  }

  Future<bool> _confirmOverwriteFromDrive(
    BuildContext context, {
    required String? remoteModifiedRfc3339,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: const Text('Overwrite local data?', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: Text(
            'This will overwrite all local data with the version from Google Drive.\n\n'
            'Remote modified: ${_fmtRfc3339(remoteModifiedRfc3339)}\n\n'
            'Safety: we will create a local restore point before overwriting, and you can Undo right after import.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
              child: const Text('Overwrite'),
            ),
          ],
        );
      },
    );

    return ok == true;
  }

  Future<_ConflictAction> _resolveConflict(
    BuildContext context, {
    required String? remoteModifiedRfc3339,
    required int? lastUploadAtMs,
    required int? lastLocalSaveAtMs,
  }) async {
    final res = await showDialog<_ConflictAction>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: const Text('Sync conflict detected', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: Text(
            'Both your device and Google Drive have changes.\n\n'
            'Last local save: ${_fmtMs(lastLocalSaveAtMs)}\n'
            'Last upload: ${_fmtMs(lastUploadAtMs)}\n'
            'Remote modified: ${_fmtRfc3339(remoteModifiedRfc3339)}\n\n'
            'Choose what to keep:',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_ConflictAction.cancel),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(_ConflictAction.uploadLocal),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              child: const Text('Upload local'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_ConflictAction.overwriteLocal),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
              child: const Text('Overwrite local'),
            ),
          ],
        );
      },
    );
    return res ?? _ConflictAction.cancel;
  }
}

enum _ConflictAction {
  cancel,
  uploadLocal,
  overwriteLocal,
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4),
      ),
    );
  }
}
