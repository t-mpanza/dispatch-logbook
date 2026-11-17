/// D13 — the group-post reminders: fire when a DIBT crosses 90% and
/// 100%, exactly once each, never on the way back down.
///
/// Wording is Sir Kiddow's, verbatim (2026-11-17):
///
/// - 90%:  `{trip} is almost done. Dont forget to post on the group.`
/// - 100%: `{trip} is done. Post on the group.`
///
/// The threshold logic is pure (unit-tested); the notification wiring
/// lives in NotificationService.showNow, called by the truck hub after
/// every tally change.
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

  /// [label] is the trip name (NLS, PLK, HI-Q, DBN, BFN…) — the number
  /// the floor thinks in; falls back to the document number.
  static String messageFor(double point, String label) {
    if (point >= 1.0) {
      return '$label is done. Post on the group.';
    }
    return '$label is almost done. Dont forget to post on the group.';
  }
}
