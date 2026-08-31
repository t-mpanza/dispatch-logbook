import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/note_block.dart';
import 'package:dispatch_diary/data/models/preset.dart';
import 'package:dispatch_diary/data/models/trip.dart';

void main() {
  group('Entry & Models Serialization Tests', () {
    test('Entry model serializes to and from Map correctly', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final entry = Entry(
        id: 'entry-123',
        title: 'STOCKS 1',
        tags: ['stocks', 'tyres'],
        expectedTotal: 120,
        notes: [
          NoteBlock(id: 'note-1', text: 'Loaded properly', createdAt: now),
        ],
        attachments: [],
        trips: [
          Trip(id: 'trip-1', count: 45, createdAt: now),
        ],
        loadingSheetTrips: [
          LoadingSheetTrip(
            id: 'lst-1',
            reg: 'MN05XNGP',
            driverName: 'Neil',
            tripId: 'STOCKS 1',
            presetKey: PresetKey.STOCKS,
            startTime: now,
            finishTime: now + 1800000,
            durationMinutes: 30,
            quantityLoaded: 45,
            createdAt: now,
          ),
        ],
        despatcherName: 'Theolus',
        createdAt: now,
        updatedAt: now,
        dayKey: '2026-08-30',
        monthKey: '2026-08',
        yearKey: '2026',
      );

      final map = entry.toMap();
      expect(map['id'], equals('entry-123'));
      expect(map['expected_total'], equals(120));

      final restored = Entry.fromMap(map);
      expect(restored.id, equals('entry-123'));
      expect(restored.title, equals('STOCKS 1'));
      expect(restored.tags, contains('stocks'));
      expect(restored.notes.length, equals(1));
      expect(restored.notes.first.text, equals('Loaded properly'));
      expect(restored.trips?.length, equals(1));
      expect(restored.trips?.first.count, equals(45));
      expect(restored.loadingSheetTrips?.length, equals(1));
      expect(restored.loadingSheetTrips?.first.driverName, equals('Neil'));
      expect(restored.loadingSheetTrips?.first.durationMinutes, equals(30));
    });
  });
}
