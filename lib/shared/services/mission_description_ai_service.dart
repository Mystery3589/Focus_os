class MissionDescriptionAiService {
  static String enhance({
    required String title,
    required String description,
    int? expectedMinutes,
  }) {
    final t = title.trim();
    final d = description.trim();

    if (t.isEmpty && d.isEmpty) {
      return '';
    }

    final steps = _suggestSteps(t.isNotEmpty ? t : d);
    final timebox = expectedMinutes != null && expectedMinutes > 0
        ? 'Timebox: ~$expectedMinutes min.'
        : 'Timebox: pick a quick first sprint (15–25 min).';

    final objective = t.isNotEmpty ? t : _titleFromDescription(d);

    final buffer = StringBuffer();
    buffer.writeln('Objective: $objective');
    buffer.writeln(timebox);
    buffer.writeln();

    buffer.writeln('Plan:');
    for (final s in steps) {
      buffer.writeln('- $s');
    }
    buffer.writeln();

    buffer.writeln('Done when:');
    buffer.writeln('- You can point to a concrete outcome (notes, commit, completed set, sent message, etc.).');
    buffer.writeln('- Next step is written down (so you restart fast next time).');

    if (d.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Notes:');
      buffer.writeln(d);
    }

    return buffer.toString().trim();
  }

  static String _titleFromDescription(String d) {
    if (d.isEmpty) return 'Make progress';
    final line = d.split(RegExp(r'\r?\n')).first.trim();
    if (line.isEmpty) return 'Make progress';
    return line.length > 60 ? '${line.substring(0, 60).trim()}…' : line;
  }

  static List<String> _suggestSteps(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('study') || lower.contains('learn') || lower.contains('read')) {
      return const [
        'Pick one sub-topic (avoid “everything”).',
        'Do 20 minutes of focused input (read/watch).',
        'Write a 5-bullet summary + 1 question to answer next.',
      ];
    }

    if (lower.contains('code') || lower.contains('build') || lower.contains('implement') || lower.contains('bug')) {
      return const [
        'Define “done” in one sentence.',
        'Do the smallest possible next change (one file / one function).',
        'Run/verify, then write the next step before you stop.',
      ];
    }

    if (lower.contains('workout') || lower.contains('gym') || lower.contains('lift') || lower.contains('run')) {
      return const [
        'Warm up (2–5 minutes).',
        'Do the main set (track reps/time).',
        'Cool down + log what to improve next session.',
      ];
    }

    if (lower.contains('clean') || lower.contains('organize') || lower.contains('tidy')) {
      return const [
        'Choose a single area (desk, room corner, inbox).',
        'Set a 10–20 min timer and remove obvious clutter first.',
        'Stop when the timer ends; note the next area to tackle.',
      ];
    }

    return const [
      'Choose the smallest next action.',
      'Work in one focused sprint (no multitasking).',
      'Capture the result + the next step.',
    ];
  }
}
