import 'package:dispatch_diary/dispatch/models/slip_tyre.dart';
import 'package:dispatch_diary/presentation/widgets/tyre_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D11 — tyres as 2-column blocks: SLIP, SERIAL, MAKE, PATTERN, customer,
/// red D badge for anything rejected (scrap OR dump), white → green.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  SlipTyre good = const SlipTyre(
    slipNumber: 96962259,
    serial: '2608E105',
    make: 'GOOD YEAR',
    pattern: 'M90L',
    customerName: 'EPS COURIERS SERVICES',
  );

  SlipTyre scrap = const SlipTyre(
    slipNumber: 98962056,
    serial: 'DUD - DAMAGE BELT',
    make: 'GOOD YEAR',
    pattern: 'MM1',
    customerName: 'KANYI ILANGA',
    rejectAccepted: 2,
  );

  SlipTyre dumped = const SlipTyre(
    slipNumber: 98962062,
    serial: '2608F001',
    make: 'BISON',
    pattern: 'M38',
    dump: 1,
  );

  testWidgets('shows slip, serial, make, pattern and customer',
      (tester) async {
    await tester.pumpWidget(wrap(TyreBlock(tyre: good)));
    expect(find.text('96962259'), findsOneWidget);
    expect(find.text('2608E105'), findsOneWidget);
    expect(find.text('GOOD YEAR · M90L'), findsOneWidget);
    expect(find.text('EPS COURIERS SERVICES'), findsOneWidget);
    expect(find.text('D'), findsNothing);
  });

  testWidgets('rejected tyre carries the D badge', (tester) async {
    await tester.pumpWidget(wrap(TyreBlock(tyre: scrap)));
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('dumped tyre carries the D badge too', (tester) async {
    await tester.pumpWidget(wrap(TyreBlock(tyre: dumped)));
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('tap fires the callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(TyreBlock(tyre: good, onTap: () => taps++)));
    await tester.tap(find.byType(TyreBlock));
    expect(taps, 1);
  });

  testWidgets('grid lays out two columns on a phone width', (tester) async {
    await tester.pumpWidget(wrap(SizedBox(
      width: 360,
      child: TyreBlockGrid(blocks: [
        TyreBlock(tyre: good),
        TyreBlock(tyre: scrap, scanned: true),
        TyreBlock(tyre: dumped),
      ]),
    )));
    final blocks = find.byType(TyreBlock);
    final first = tester.getTopLeft(blocks.at(0));
    final second = tester.getTopLeft(blocks.at(1));
    final third = tester.getTopLeft(blocks.at(2));
    expect(first.dy, second.dy); // side by side
    expect(third.dy, greaterThan(first.dy)); // wrapped to row 2
    expect(tester.takeException(), isNull);
  });
}
