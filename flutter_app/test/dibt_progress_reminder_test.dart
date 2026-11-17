import 'package:dispatch_diary/data/services/dibt_progress_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

/// D13 — the group-post reminders: fire at 90% and 100% of a DIBT,
/// exactly once each, and never on the way back down.
void main() {
  group('DibtProgressReminder.thresholdsCrossed', () {
    test('fires 90% when crossing it upward', () {
      expect(DibtProgressReminder.thresholdsCrossed(0.89, 0.91), [0.9]);
      expect(DibtProgressReminder.thresholdsCrossed(0.85, 0.95), [0.9]);
    });

    test('fires 100% when the last tyre lands', () {
      expect(DibtProgressReminder.thresholdsCrossed(0.9, 1.0), [1.0]);
      expect(DibtProgressReminder.thresholdsCrossed(0.99, 1.0), [1.0]);
    });

    test('can fire both if a batch jumps over 90%', () {
      expect(
        DibtProgressReminder.thresholdsCrossed(0.88, 1.0),
        [0.9, 1.0],
      );
    });

    test('never re-fires when already at or above the threshold', () {
      expect(DibtProgressReminder.thresholdsCrossed(0.9, 0.95), isEmpty);
      expect(DibtProgressReminder.thresholdsCrossed(1.0, 1.0), isEmpty);
    });

    test('never fires on the way down (removals)', () {
      expect(DibtProgressReminder.thresholdsCrossed(0.95, 0.8), isEmpty);
      expect(DibtProgressReminder.thresholdsCrossed(1.0, 0.5), isEmpty);
    });

    test('no fire for small upward moves below 90%', () {
      expect(DibtProgressReminder.thresholdsCrossed(0.5, 0.8), isEmpty);
      expect(DibtProgressReminder.thresholdsCrossed(0.0, 0.89), isEmpty);
    });

    test('exact landing on a threshold counts', () {
      expect(DibtProgressReminder.thresholdsCrossed(0.89, 0.9), [0.9]);
    });
  });

  group('DibtProgressReminder.messageFor — Sir Kiddow\'s wording', () {
    test('90% uses the almost-done wording with the trip label', () {
      expect(
        DibtProgressReminder.messageFor(0.9, 'NLS'),
        'NLS is almost done. Dont forget to post on the group.',
      );
    });

    test('100% uses the done wording with the trip label', () {
      expect(
        DibtProgressReminder.messageFor(1.0, 'PLK'),
        'PLK is done. Post on the group.',
      );
    });
  });
}
