import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/data/models/entry.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/preset.dart';
import 'package:dispatch_diary/data/services/whatsapp_export_service.dart';

void main() {
  group('WhatsApp Export Tests', () {
    test('Formats WhatsApp markdown message with header, truck list and summary', () {
      final now = 1788163200000; // Fixed epoch
      final entry = Entry(
        id: 'entry-1',
        title: 'Daily Sheet',
        tags: [],
        notes: [],
        attachments: [],
        loadingSheetTrips: [
          LoadingSheetTrip(
            id: 'trip-1',
            reg: 'MN05XNGP',
            driverName: 'Neil',
            tripId: 'STOCKS 1',
            presetKey: PresetKey.STOCKS,
            startTime: now,
            finishTime: now + (45 * 60 * 1000),
            durationMinutes: 45,
            quantityLoaded: 50,
            createdAt: now,
          ),
          LoadingSheetTrip(
            id: 'trip-2',
            reg: 'CA123456',
            driverName: 'John',
            tripId: 'DBN',
            presetKey: PresetKey.DBN,
            startTime: now + (60 * 60 * 1000),
            finishTime: now + (90 * 60 * 1000),
            durationMinutes: 30,
            quantityLoaded: 35,
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        dayKey: '2026-08-30',
        monthKey: '2026-08',
        yearKey: '2026',
      );

      final text = WhatsAppExportService.formatWhatsAppText(entry, 'Theolus');

      expect(text, contains('*DESPATCH LOADING SHEET*'));
      expect(text, contains('📅 Date: 2026-08-30'));
      expect(text, contains('👤 Despatcher: Theolus'));
      expect(text, contains('1. *STOCKS 1* | MN05XNGP'));
      expect(text, contains('Driver: Neil'));
      expect(text, contains('Tyres: 50'));
      expect(text, contains('2. *DBN* | CA123456'));
      expect(text, contains('Driver: John'));
      expect(text, contains('Tyres: 35'));
      expect(text, contains('*SUMMARY*'));
      expect(text, contains('🚚 Total Trucks: 2'));
      expect(text, contains('📦 Total Tyres: 85'));
      expect(text, contains('⏱ Total Time: 1h 15m (75m)'));
    });
  });
}
