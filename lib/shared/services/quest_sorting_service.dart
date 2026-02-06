import '../models/focus_session.dart';
import '../models/quest.dart';

/// Sort rule for missions list.
///
/// Supported fields:
/// - latest
/// - priority
/// - due
/// - difficulty
/// - length (expectedMinutes)
/// - type (frequency)
class QuestSortRule {
  final String field;
  final bool ascending;

  const QuestSortRule(this.field, this.ascending);
}

int questDifficultyRank(String difficulty) {
  const order = {'S': 5, 'A': 4, 'B': 3, 'C': 2, 'D': 1};
  return order[difficulty.toUpperCase()] ?? 0;
}

int questPriorityRank(String priority) {
  const order = {'S': 5, 'A': 4, 'B': 3, 'C': 2, 'D': 1};
  return order[priority.toUpperCase()] ?? 0;
}

int questFrequencyRank(String? frequency) {
  final f = (frequency ?? 'none').toLowerCase();
  const order = {
    'none': 0,
    'daily': 1,
    'weekly': 2,
    'monthly': 3,
    'yearly': 4,
  };
  return order[f] ?? 0;
}

bool questMatchesTypeFilter(Quest q, String typeFilter) {
  if (typeFilter == 'all') return true;
  final f = (q.frequency ?? 'none').toLowerCase();
  if (typeFilter == 'one-time') return f == 'none';
  return f == typeFilter;
}

String? questStatusForQuestId(String questId, List<FocusOpenSession> openSessions) {
  try {
    return openSessions.firstWhere((s) => s.questId == questId).status;
  } catch (_) {
    return null;
  }
}

int _compareDue({required Quest a, required Quest b, required bool asc}) {
  final da = a.dueDateMs;
  final db = b.dueDateMs;
  if (da == null && db == null) return 0;
  if (da == null) return 1; // null last
  if (db == null) return -1;
  return asc ? da.compareTo(db) : db.compareTo(da);
}

int _compareLength({required Quest a, required Quest b, required bool asc}) {
  final la = a.expectedMinutes;
  final lb = b.expectedMinutes;
  if (la == null && lb == null) return 0;
  if (la == null) return 1; // null last
  if (lb == null) return -1;
  return asc ? la.compareTo(lb) : lb.compareTo(la);
}

int _compareLatest({required Quest a, required Quest b, required bool asc, required bool isCompleted}) {
  final ta = isCompleted ? (a.completedAt ?? 0) : (a.createdAt ?? 0);
  final tb = isCompleted ? (b.completedAt ?? 0) : (b.createdAt ?? 0);
  return asc ? ta.compareTo(tb) : tb.compareTo(ta);
}

int compareQuests(
  Quest a,
  Quest b, {
  required bool isCompleted,
  required List<QuestSortRule> sortRules,
}) {
  final rules = sortRules.isNotEmpty ? sortRules : const [QuestSortRule('latest', false)];

  for (final r in rules) {
    int c = 0;
    switch (r.field) {
      case 'priority':
        c = r.ascending
            ? questPriorityRank(a.priority).compareTo(questPriorityRank(b.priority))
            : questPriorityRank(b.priority).compareTo(questPriorityRank(a.priority));
        break;
      case 'difficulty':
        c = r.ascending
            ? questDifficultyRank(a.difficulty).compareTo(questDifficultyRank(b.difficulty))
            : questDifficultyRank(b.difficulty).compareTo(questDifficultyRank(a.difficulty));
        break;
      case 'due':
        c = _compareDue(a: a, b: b, asc: r.ascending);
        break;
      case 'length':
        c = _compareLength(a: a, b: b, asc: r.ascending);
        break;
      case 'type':
        c = r.ascending
            ? questFrequencyRank(a.frequency).compareTo(questFrequencyRank(b.frequency))
            : questFrequencyRank(b.frequency).compareTo(questFrequencyRank(a.frequency));
        break;
      case 'latest':
      default:
        c = _compareLatest(a: a, b: b, asc: r.ascending, isCompleted: isCompleted);
        break;
    }

    if (c != 0) return c;
  }

  final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
  if (byTitle != 0) return byTitle;
  return a.id.compareTo(b.id);
}

List<Quest> filterAndSortQuests({
  required List<Quest> quests,
  required bool isCompleted,
  required List<FocusOpenSession> openSessions,
  required List<QuestSortRule> sortRules,
  String? skillFilterId,
  String statusFilter = 'all',
  String difficultyFilter = 'all',
  String priorityFilter = 'all',
  String typeFilter = 'all',
  String searchTerm = '',
}) {
  final term = searchTerm.trim().toLowerCase();

  final filtered = quests.where((q) {
    if (q.completed != isCompleted) return false;

    if (skillFilterId != null && q.skillId != skillFilterId) return false;

    if (difficultyFilter != 'all' && q.difficulty.toUpperCase() != difficultyFilter) return false;

    if (priorityFilter != 'all' && q.priority.toUpperCase() != priorityFilter) return false;

    if (!questMatchesTypeFilter(q, typeFilter)) return false;

    if (!isCompleted && statusFilter != 'all') {
      final status = questStatusForQuestId(q.id, openSessions);
      if (statusFilter == 'none') {
        if (status != null) return false;
      } else {
        if (status != statusFilter) return false;
      }
    }

    if (term.isNotEmpty) {
      return q.title.toLowerCase().contains(term) || q.description.toLowerCase().contains(term);
    }

    return true;
  }).toList(growable: false);

  final sorted = [...filtered]..sort((a, b) => compareQuests(a, b, isCompleted: isCompleted, sortRules: sortRules));
  return sorted;
}
