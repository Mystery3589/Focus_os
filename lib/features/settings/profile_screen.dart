import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/cyber_card.dart';
import '../../shared/widgets/page_entrance.dart';
import '../../shared/widgets/ai_inbox_bell_action.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final stats = ref.read(userProvider);
    _nameController = TextEditingController(text: stats.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(userProvider);
    final jobValue = (stats.job != null && stats.unlockedJobs.contains(stats.job))
      ? stats.job
      : (stats.unlockedJobs.isNotEmpty ? stats.unlockedJobs.first : null);
    final titleValue = (stats.title != null && stats.unlockedTitles.contains(stats.title))
      ? stats.title
      : (stats.unlockedTitles.isNotEmpty ? stats.unlockedTitles.first : null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text('Profile', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        actions: const [
          AiInboxBellAction(),
        ],
      ),
      body: PageEntrance(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CyberCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const Text('Player Profile', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _textField('Name', _nameController),
              const SizedBox(height: 12),
              _dropdownField(
                label: 'Job (Unlocked)',
                value: jobValue,
                items: stats.unlockedJobs,
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(userProvider.notifier).setActiveJob(value);
                },
              ),
              const SizedBox(height: 12),
              _dropdownField(
                label: 'Title (Unlocked)',
                value: titleValue,
                items: stats.unlockedTitles,
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(userProvider.notifier).setActiveTitle(value);
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Jobs and titles are granted by your AI mentor over time. You can only select from what you’ve unlocked.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(userProvider.notifier).updateProfile(
                          name: _nameController.text.trim(),
                        );
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/settings');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(LucideIcons.save, size: 16),
                  label: const Text('Save'),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final unique = items.toSet().toList()..sort();
    return DropdownButtonFormField<String>(
      value: value != null && unique.contains(value) ? value : (unique.isNotEmpty ? unique.first : null),
      items: unique
          .map(
            (v) => DropdownMenuItem<String>(
              value: v,
              child: Text(v, style: const TextStyle(color: AppTheme.textPrimary)),
            ),
          )
          .toList(),
      onChanged: unique.isEmpty ? null : onChanged,
      dropdownColor: AppTheme.background,
      decoration: const InputDecoration(
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ).copyWith(labelText: label),
      iconEnabledColor: AppTheme.textSecondary,
      style: const TextStyle(color: AppTheme.textPrimary),
    );
  }
}
