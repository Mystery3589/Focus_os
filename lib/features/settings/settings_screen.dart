import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/models/focus_session.dart';
import '../../shared/services/local_backup_service.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      final next = _searchController.text.trim();
      if (next == _query) return;
      setState(() => _query = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userStats = ref.watch(userProvider);
    final focusSettings = userStats.focus.settings;

    final options = <_SettingsOption>[
      _SettingsOption(
        title: 'Profile',
        subtitle: 'Name, job, title',
        icon: LucideIcons.user,
        onTap: () => context.push('/settings/profile'),
        keywords: const ['profile', 'name', 'job', 'title', 'player'],
      ),
      _SettingsOption(
        title: 'Instructions',
        subtitle: 'How to use the app',
        icon: LucideIcons.bookOpen,
        onTap: () => context.push('/settings/instructions'),
        keywords: const ['instructions', 'help', 'guide', 'how', 'tutorial'],
      ),
      _SettingsOption(
        title: 'Focus defaults',
        subtitle: 'Pomodoro/Stopwatch and timer defaults',
        icon: LucideIcons.timer,
        onTap: () => _showFocusDefaultsDialog(context, ref, focusSettings),
        keywords: const ['focus', 'defaults', 'pomodoro', 'stopwatch', 'timer', 'break'],
      ),
      _SettingsOption(
        title: 'Backup & restore',
        subtitle: 'Export/import JSON (local backup)',
        icon: LucideIcons.save,
        onTap: () => _showBackupDialog(context, ref),
        keywords: const ['backup', 'restore', 'export', 'import', 'json', 'sync', 'copy'],
      ),
      _SettingsOption(
        title: 'Cloud sync',
        subtitle: 'Google Drive (App data)',
        icon: LucideIcons.cloud,
        onTap: () => context.push('/settings/sync'),
        keywords: const ['cloud', 'sync', 'google', 'drive', 'backup', 'restore'],
      ),
      _SettingsOption(
        title: 'Reset data',
        subtitle: 'Wipe local data and start fresh',
        icon: LucideIcons.trash2,
        isDestructive: true,
        onTap: () => _confirmReset(context, ref),
        keywords: const ['reset', 'wipe', 'clear', 'data', 'factory'],
      ),
    ];

    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? options
        : options.where((o) {
            final hay = '${o.title} ${o.subtitle} ${o.keywords.join(' ')}'.toLowerCase();
            return hay.contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: const [
          AiInboxBellAction(),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            CyberCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search settings', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      border: Border.all(color: AppTheme.borderColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.search, size: 18, color: AppTheme.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Search… (profile, focus, reset)',
                              hintStyle: TextStyle(color: AppTheme.textSecondary),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _searchController.clear(),
                            icon: const Icon(LucideIcons.x, size: 18, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CyberCard(
              padding: const EdgeInsets.all(8),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No matching settings.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < filtered.length; i++) ...[
                          _SettingsTile(option: filtered[i]),
                          if (i != filtered.length - 1)
                            const Divider(height: 1, color: AppTheme.borderColor),
                        ]
                      ],
                    ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: const Text('Reset all data?', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: const Text(
            'This will wipe your local saved data (missions, skills, inventory, focus history). This cannot be undone.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.black),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      await ref.read(userProvider.notifier).resetAllData();
      if (context.mounted) context.go('/');
    }
  }

  Future<void> _showBackupDialog(BuildContext context, WidgetRef ref) async {
    final json = ref.read(userProvider.notifier).exportUserStatsJson(pretty: true);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderColor),
          ),
          title: const Text('Backup & restore', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export your data as JSON and keep it somewhere safe.\n\nTo restore, use Import and paste the JSON. Import overwrites all local data.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      json,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_importFromFile(context, ref));
              },
              child: const Text('Import file', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showImportDialog(context, ref);
              },
              child: const Text('Import', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup JSON copied to clipboard.')),
                  );
                }
              },
              child: const Text('Copy', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file contents.')),
          );
        }
        return;
      }

      final jsonString = utf8.decode(bytes);

      if (!context.mounted) return;
      final confirm = await _confirmDestructiveImport(context, sourceLabel: file.name);
      if (confirm != true) return;

      final localBefore = ref.read(userProvider.notifier).exportUserStatsJson(pretty: false);
      unawaited(LocalBackupService.instance.saveRestorePoint(
        json: localBefore,
        reason: 'import_from_file',
      ));

      final ok = await ref.read(userProvider.notifier).importUserStatsJson(jsonString);
      if (!context.mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed (invalid or incompatible backup).')),
        );
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Backup imported from file.'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              unawaited(ref.read(userProvider.notifier).importUserStatsJson(localBefore));
            },
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed.')),
        );
      }
    }
  }

  Future<bool?> _confirmDestructiveImport(BuildContext context, {required String sourceLabel}) {
    return showDialog<bool>(
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
            'This will overwrite all local data with the backup from:\n$sourceLabel\n\n'
            'Safety: we will create a local restore point before importing, and you can Undo right after.',
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
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              title: const Text('Import backup', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paste your exported JSON below.\nThis will overwrite all local data (missions, skills, inventory, focus history).',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: error == null ? AppTheme.borderColor : Colors.redAccent),
                      ),
                      child: TextField(
                        controller: controller,
                        maxLines: 10,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '{\n  "name": "...",\n  ...\n}',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      setState(() => error = 'Paste your JSON backup first.');
                      return;
                    }

                    final ok = await ref.read(userProvider.notifier).importUserStatsJson(text);
                    if (!ok) {
                      setState(() => error = 'That doesn\'t look like a valid backup JSON for this app.');
                      return;
                    }

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup imported successfully.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  void _showFocusDefaultsDialog(BuildContext context, WidgetRef ref, FocusSettings current) {
    final focusMins = TextEditingController(text: current.pomodoro.focusMinutes.toString());
    final breakMins = TextEditingController(text: current.pomodoro.breakMinutes.toString());
    final pausedReminderMins = TextEditingController(text: current.notifications.pausedMissionReminderMinutes.toString());
    final dueReminderHour = TextEditingController(text: current.notifications.dueDateReminderHour.toString());
    final eventReminderHour = TextEditingController(text: current.notifications.eventReminderHour.toString());
    var mode = current.mode;
    var clockStyle = current.clockStyle;

    var notifEnabled = current.notifications.enabled;
    var pausedReminder = current.notifications.pausedMissionReminder;
    var dueReminder = current.notifications.dueDateReminder;
    var eventReminder = current.notifications.eventReminder;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              title: Row(
                children: [
                  const Expanded(
                    child: Text('Focus defaults', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, color: AppTheme.textSecondary),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Default mode', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Pomodoro'),
                            selected: mode == 'pomodoro',
                            onSelected: (_) => setState(() => mode = 'pomodoro'),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(color: mode == 'pomodoro' ? Colors.black : AppTheme.textSecondary),
                          ),
                          ChoiceChip(
                            label: const Text('Stopwatch'),
                            selected: mode == 'stopwatch',
                            onSelected: (_) => setState(() => mode = 'stopwatch'),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(color: mode == 'stopwatch' ? Colors.black : AppTheme.textSecondary),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Text('Clock style', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Normal'),
                            selected: clockStyle == 'normal',
                            onSelected: (_) => setState(() => clockStyle = 'normal'),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(color: clockStyle == 'normal' ? Colors.black : AppTheme.textSecondary),
                          ),
                          ChoiceChip(
                            label: const Text('Flip'),
                            selected: clockStyle == 'flip',
                            onSelected: (_) => setState(() => clockStyle = 'flip'),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(color: clockStyle == 'flip' ? Colors.black : AppTheme.textSecondary),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Text('Pomodoro defaults', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _numField(label: 'Focus (minutes)', controller: focusMins),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _numField(label: 'Break (minutes)', controller: breakMins),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Custom sessions earn 1 XP/min.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),

                      const SizedBox(height: 14),
                      const Text('Notifications', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: notifEnabled,
                        onChanged: (v) => setState(() => notifEnabled = v),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable notifications', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Requires permission (Android).', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ),

                      const SizedBox(height: 4),
                      SwitchListTile(
                        value: pausedReminder,
                        onChanged: notifEnabled ? (v) => setState(() => pausedReminder = v) : null,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Paused mission reminder', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      if (notifEnabled && pausedReminder)
                        Row(
                          children: [
                            Expanded(child: _numField(label: 'After (minutes)', controller: pausedReminderMins)),
                          ],
                        ),

                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: dueReminder,
                        onChanged: notifEnabled ? (v) => setState(() => dueReminder = v) : null,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mission due-date reminders', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      if (notifEnabled && dueReminder)
                        Row(
                          children: [
                            Expanded(child: _numField(label: 'Due reminder hour (0-23)', controller: dueReminderHour)),
                          ],
                        ),

                      const SizedBox(height: 6),
                      SwitchListTile(
                        value: eventReminder,
                        onChanged: notifEnabled ? (v) => setState(() => eventReminder = v) : null,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Calendar event reminders', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Only for events where “Remind me” is enabled.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      ),
                      if (notifEnabled && eventReminder)
                        Row(
                          children: [
                            Expanded(child: _numField(label: 'Event reminder hour (0-23)', controller: eventReminderHour)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final f = (int.tryParse(focusMins.text) ?? current.pomodoro.focusMinutes).clamp(1, 999);
                    final b = (int.tryParse(breakMins.text) ?? current.pomodoro.breakMinutes).clamp(1, 999);

                    final pausedM = (int.tryParse(pausedReminderMins.text) ?? current.notifications.pausedMissionReminderMinutes).clamp(1, 24 * 60);
                    final dueH = (int.tryParse(dueReminderHour.text) ?? current.notifications.dueDateReminderHour).clamp(0, 23);
                    final eventH = (int.tryParse(eventReminderHour.text) ?? current.notifications.eventReminderHour).clamp(0, 23);

                    ref.read(userProvider.notifier).updateFocusSettings(
                          current.copyWith(
                            mode: mode,
                            clockStyle: clockStyle,
                            pomodoro: current.pomodoro.copyWith(focusMinutes: f, breakMinutes: b),
                            notifications: current.notifications.copyWith(
                              enabled: notifEnabled,
                              pausedMissionReminder: pausedReminder,
                              pausedMissionReminderMinutes: pausedM,
                              dueDateReminder: dueReminder,
                              dueDateReminderHour: dueH,
                              eventReminder: eventReminder,
                              eventReminderHour: eventH,
                            ),
                          ),
                        );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      focusMins.dispose();
      breakMins.dispose();
      pausedReminderMins.dispose();
      dueReminderHour.dispose();
      eventReminderHour.dispose();
    });
  }

  Widget _numField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border.all(color: AppTheme.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final List<String> keywords;

  const _SettingsOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.keywords,
    this.isDestructive = false,
  });
}

class _SettingsTile extends StatelessWidget {
  final _SettingsOption option;

  const _SettingsTile({required this.option});

  @override
  Widget build(BuildContext context) {
    final titleColor = option.isDestructive ? Colors.redAccent : AppTheme.textPrimary;
    final iconColor = option.isDestructive ? Colors.redAccent : AppTheme.primary;
    return InkWell(
      onTap: option.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Icon(option.icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(option.subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
