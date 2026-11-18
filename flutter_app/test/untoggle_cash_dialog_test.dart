import 'package:dispatch_diary/presentation/widgets/untoggle_cash_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Audit #5 — KEEP CASH is the safe default on the RIGHT (thumb side);
/// UNTOGGLE is the disruptive action on the LEFT.
void main() {
  testWidgets('KEEP CASH sits to the RIGHT of UNTOGGLE', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showUntoggleCashDialog(
              context,
              documentNo: 'IBT122773',
            );
          },
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('This tyre is on IBT122773 — untoggle cash?'),
        findsOneWidget);
    final keepX = tester.getCenter(find.text('KEEP CASH')).dx;
    final untoggleX = tester.getCenter(find.text('UNTOGGLE')).dx;
    expect(keepX, greaterThan(untoggleX));

    await tester.tap(find.text('KEEP CASH'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UNTOGGLE returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showUntoggleCashDialog(
              context,
              documentNo: 'IBT122773',
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UNTOGGLE'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
