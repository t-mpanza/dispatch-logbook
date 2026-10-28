import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/presentation/widgets/time_entry_field.dart';

void main() {
  group('TimeDigits — smart time entry', () {
    test('four digits insert the colon', () {
      expect(TimeDigits.format('1110'), '11:10');
      expect(TimeDigits.format('0830'), '08:30');
      expect(TimeDigits.format('2359'), '23:59');
    });

    test('short buffers pad safely (the cleared-field regression)', () {
      expect(TimeDigits.format(''), '00:00');
      expect(TimeDigits.format('1'), '10:00');
      expect(TimeDigits.format('11'), '11:00');
      expect(TimeDigits.format('111'), '11:10');
    });

    test('clearing then typing never crashes or rejects', () {
      // Regression: after removing everything, "1" then "1" must be valid.
      expect(TimeDigits.isValid(''), isTrue);
      expect(TimeDigits.isValid('1'), isTrue);
      expect(TimeDigits.isValid('11'), isTrue);
      expect(TimeDigits.isValid('1110'), isTrue);
    });

    test('impossible times are rejected', () {
      expect(TimeDigits.isValid('2460'), isFalse);
      expect(TimeDigits.isValid('2360'), isFalse);
      expect(TimeDigits.isValid('2500'), isFalse);
    });

    test('toEpochMs uses today at the entered time', () {
      final now = DateTime(2026, 10, 6, 14, 30);
      final value = TimeDigits.toEpochMs('0815', now: now)!;
      final dt = DateTime.fromMillisecondsSinceEpoch(value);
      expect(dt.year, 2026);
      expect(dt.month, 10);
      expect(dt.day, 6);
      expect(dt.hour, 8);
      expect(dt.minute, 15);
      expect(TimeDigits.toEpochMs(''), isNull);
    });
  });

  group('LoadingSheetTrip.effectiveDurationMinutes — stocks in the time counter', () {
    test('uses stored duration when present', () {
      const trip = LoadingSheetTrip(
        id: 't1',
        reg: '',
        driverName: '',
        tripId: 'STOCKS 1',
        quantityLoaded: 10,
        durationMinutes: 45,
        createdAt: 0,
      );
      expect(trip.effectiveDurationMinutes, 45);
    });

    test('derives duration from start/finish when not stored (IBT trips)', () {
      final start = DateTime(2026, 10, 6, 8, 0).millisecondsSinceEpoch;
      final finish = DateTime(2026, 10, 6, 9, 15).millisecondsSinceEpoch;
      const trip = LoadingSheetTrip(
        id: 't1',
        reg: '',
        driverName: '',
        tripId: 'STOCKS 1',
        quantityLoaded: 10,
        startTime: null,
        finishTime: null,
        createdAt: 0,
      );
      final withTimes = trip.copyWith(startTime: start, finishTime: finish);
      expect(withTimes.durationMinutes, isNull);
      expect(withTimes.effectiveDurationMinutes, 75);
    });

    test('returns null without timestamps or stored duration', () {
      const trip = LoadingSheetTrip(
        id: 't1',
        reg: '',
        driverName: '',
        tripId: 'STOCKS 1',
        quantityLoaded: 0,
        createdAt: 0,
      );
      expect(trip.effectiveDurationMinutes, isNull);
    });

    test('finish before start is ignored (midnight guard)', () {
      final start = DateTime(2026, 10, 6, 23, 0).millisecondsSinceEpoch;
      final finish = DateTime(2026, 10, 6, 1, 0).millisecondsSinceEpoch;
      const trip = LoadingSheetTrip(
        id: 't1',
        reg: '',
        driverName: '',
        tripId: 'STOCKS 1',
        quantityLoaded: 0,
        createdAt: 0,
      );
      final weird = trip.copyWith(startTime: start, finishTime: finish);
      expect(weird.effectiveDurationMinutes, isNull);
    });
  });
}
