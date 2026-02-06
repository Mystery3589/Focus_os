import '../models/focus_session.dart';
import '../models/quest.dart';

/// Utilities for rolling up focus logs from sub-missions into their parent
/// mission for analytics.
class MissionRollupService {
  static bool isCustomLog(FocusSessionLogEntry log) {
    return log.questId.startsWith('custom-') || (log.difficulty ?? '').toUpperCase() == 'CUSTOM';
  }

  /// Returns the mission id that should be used for analytics rollups.
  ///
  /// - Custom sessions stay as-is.
  /// - If the quest is a sub-mission with a valid parent in [questsById], the
  ///   parent id is returned.
  /// - Otherwise returns [questId].
  static String rolledUpMissionIdFor({
    required String questId,
    required Map<String, Quest> questsById,
  }) {
    final q = questsById[questId];
    final parentId = q?.parentQuestId;
    if (parentId != null && questsById.containsKey(parentId)) {
      return parentId;
    }
    return questId;
  }

  static String rolledUpMissionTitleForLog({
    required FocusSessionLogEntry log,
    required Map<String, Quest> questsById,
  }) {
    if (isCustomLog(log)) {
      return log.questTitle ?? 'Custom Session';
    }

    final rolledUpId = rolledUpMissionIdFor(questId: log.questId, questsById: questsById);
    return questsById[rolledUpId]?.title ?? log.questTitle ?? 'Mission';
  }
}
