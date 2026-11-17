import 'package:dispatch_diary/data/models/ibt_manifest.dart';
import 'package:dispatch_diary/data/models/loading_sheet_trip.dart';
import 'package:dispatch_diary/presentation/widgets/truck_load_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bug a (deferred, now fixed): editing a trip through TruckLoadDialog
/// must never strip the staged IBT documents.
void main() {
  testWidgets('saving an edit preserves ibtDocuments verbatim',
      (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ibt = IbtDocument(
      documentNo: 'IBT122773',
      total: 151,
      lineItems: const [
        IbtLineItem(
          id: 'IBT122773_line_0',
          description: '315/80R22.5 M90L STOCK RETREAD',
          sizeId: 70,
          rubberId: 36,
          targetTotal: 83,
        ),
      ],
    );
    final existing = LoadingSheetTrip(
      id: 'trip-1',
      entryId: 'entry-1',
      reg: 'MN05XNGP',
      driverName: 'Neil',
      tripId: 'NLH',
      quantityLoaded: 4,
      createdAt: now,
      ibtDocuments: [ibt],
    );

    LoadingSheetTrip? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => Material(
                type: MaterialType.transparency,
                child: TruckLoadDialog(
                  existingTrip: existing,
                  dayKey: '2026-11-17',
                  existingTrips: const [],
                  onSave: (t) => saved = t,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Change the driver, then save.
    await tester.enterText(
      find.widgetWithText(TextField, 'Neil'),
      'Neil Mk II',
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.driverName, 'Neil Mk II');
    expect(saved!.ibtDocuments, isNotNull);
    expect(saved!.ibtDocuments!.single.documentNo, 'IBT122773');
    expect(saved!.ibtDocuments!.single.lineItems, isNotEmpty);
  });
}
