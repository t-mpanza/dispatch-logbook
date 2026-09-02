import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/data/models/trip.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/data/services/update_service.dart';
import 'package:dispatch_diary/presentation/viewmodels/loading_sheet_viewmodel.dart';
import 'package:dispatch_diary/presentation/widgets/counter_panel.dart';
import 'package:dispatch_diary/presentation/widgets/ibt_line_items_sheet.dart';
import 'package:dispatch_diary/presentation/widgets/aws_auth_dialog.dart';
import 'package:dispatch_diary/presentation/widgets/update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IBT UI & Auth Widget Tests', () {
    testWidgets('CounterPanel hard-clamps overshoot to the manifest target (no over-logging)', (WidgetTester tester) async {
      List<Trip> currentTrips = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CounterPanel(
                  trips: currentTrips,
                  currentTotal: 18,
                  targetTotal: 20,
                  onChange: (nextTrips) {
                    setState(() {
                      currentTrips = nextTrips;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap the '+4' quick add button (18 + 4 = 22 > 20)
      final plus4 = find.text('+4');
      expect(plus4, findsOneWidget);
      await tester.tap(plus4);
      await tester.pump();

      // Find 'LOG 4 SCANNED' button
      final logBtn = find.text('LOG 4 SCANNED');
      expect(logBtn, findsOneWidget);
      await tester.tap(logBtn);
      await tester.pump();

      // No "log over anyway" dialog — the count is hard-clamped to remaining 2.
      expect(find.text('Over IBT Target'), findsNothing);
      expect(find.text('Log +2 over anyway'), findsNothing);

      // Verify trip was logged with the clamped count of 2 (18 + 2 = 20).
      expect(currentTrips.length, 1);
      expect(currentTrips.first.count, 2);
    });

    testWidgets('IbtLineItemsSheet renders line items and progress correctly', (WidgetTester tester) async {
      final repo = EntryRepository();
      final vm = LoadingSheetViewModel(repo);

      const trip = LoadingSheetTrip(
        id: 't_test',
        reg: 'CA12345',
        driverName: 'John Doe',
        tripId: 'STOCKS 1',
        quantityLoaded: 15,
        createdAt: 1000,
        ibtDocuments: [
          IbtDocument(
            documentNo: 'IBT-9988',
            total: 30,
            lineItems: [
              IbtLineItem(
                id: 'item_1',
                description: '315/80R22.5 RD2+',
                size: '315/80R22.5',
                rubber: 'RD2+',
                targetTotal: 20,
                loadedQuantity: 15,
              ),
              IbtLineItem(
                id: 'item_2',
                description: '11R22.5 M90L',
                size: '11R22.5',
                rubber: 'M90L',
                targetTotal: 10,
                loadedQuantity: 0,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: repo),
            ChangeNotifierProvider.value(value: vm),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: IbtLineItemsSheet(trip: trip),
            ),
          ),
        ),
      );

      expect(find.text('STOCKS 1 — IBT Breakdown'), findsOneWidget);
      expect(find.text('IBT-9988'), findsOneWidget);
      expect(find.text('315/80R22.5'), findsOneWidget);
      expect(find.text('RD2+'), findsOneWidget);
      expect(find.text('15 / 20'), findsOneWidget);
      expect(find.text('11R22.5'), findsOneWidget);
      expect(find.text('0 / 10'), findsOneWidget);
    });

    testWidgets('AwsAuthDialog renders login and status tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AwsAuthDialog(),
          ),
        ),
      );

      expect(find.text('AWS AppSync Authentication'), findsOneWidget);
      expect(find.text('Sign In with AWS Web Login (SSO)'), findsOneWidget);
      expect(find.text('Direct Login'), findsOneWidget);
      expect(find.text('Paste Token / SSO'), findsOneWidget);
    });

    testWidgets('UpdateDialog renders update info and action buttons', (WidgetTester tester) async {
      final updateInfo = UpdateInfo(
        hasUpdate: true,
        currentVersion: 'v2.0.0',
        latestVersion: 'v2.1.0-rc7',
        releaseTitle: 'v2.1.0-rc7 (IBT Edition)',
        releaseNotes: 'Added full IBT manifest tracking subsystem.',
        apkDownloadUrl: 'https://github.com/t-mpanza/dispatch-logbook/releases/download/v2.1.0-rc7-ibt/app-release.apk',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateDialog(updateInfo: updateInfo),
          ),
        ),
      );

      expect(find.text('UPDATE CANDIDATE'), findsOneWidget);
      expect(find.text('New Version Available'), findsOneWidget);
      expect(find.text('v2.0.0'), findsOneWidget);
      expect(find.text('v2.1.0-rc7'), findsOneWidget);
      expect(find.text('Added full IBT manifest tracking subsystem.'), findsOneWidget);
      expect(find.text('AUTO-UPDATE NOW (v2.1.0-rc7)'), findsOneWidget);
      expect(find.text('View Release on GitHub'), findsOneWidget);
    });
  });
}
