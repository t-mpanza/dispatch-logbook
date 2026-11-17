/// D13 — the group-post reminders: fire when a DIBT crosses 90% and
/// 100%, exactly once each, never on the way back down.
///
/// The threshold logic is pure (unit-tested); the notification wiring
/// lives in [DibtProgressNotifier] which the truck hub calls after every
/// tally change.
class DibtProgressReminder {
  DibtProgressReminder._();

  /// Reminder points as fractions (0.9 = 90%, 1.0 = 100%).
  static const List<double> reminderPoints = [0.9, 1.0];

  /// Which reminder points did the progress cross between [before] and
  /// [after]? Only upward crossings count; landing exactly on a point
  /// counts as crossing it.
  static List<double> thresholdsCrossed(double before, double after) {
    return [
      for (final point in reminderPoints)
        if (before < point && after >= point) point,
    ];
  }

  static String messageFor(double point, String documentNo) {
    if (point >= 1.0) {
      return '$documentNo fully loaded — post on the group';
    }
    return '$documentNo 90% loaded — get ready to post on the group';
  }
}
