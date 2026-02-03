import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';

/// Safe wrapper around app icon quick actions.
///
/// In widget/unit tests, calling into platform channels may throw
/// [MissingPluginException]. This wrapper catches and ignores those so tests
/// remain stable.
class QuickActionsService {
  QuickActionsService._();

  static final QuickActionsService instance = QuickActionsService._();

  final QuickActions _qa = const QuickActions();

  Future<void> init({required void Function(String shortcutType) onAction}) async {
    try {
      await _qa.initialize(onAction);
    } on MissingPluginException {
      // Expected in tests / unsupported platforms.
    } catch (_) {
      // Non-fatal; quick actions are optional.
    }
  }

  Future<void> setItems(List<ShortcutItem> items) async {
    try {
      await _qa.setShortcutItems(items);
    } on MissingPluginException {
      // Expected in tests / unsupported platforms.
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> clear() async {
    try {
      await _qa.clearShortcutItems();
    } on MissingPluginException {
      // Expected in tests / unsupported platforms.
    } catch (_) {
      // Non-fatal.
    }
  }
}
