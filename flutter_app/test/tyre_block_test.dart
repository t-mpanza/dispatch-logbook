import 'package:dispatch_diary/presentation/widgets/tyre_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D11 — tyres as 2-column blocks: slip number, customer prominent,
/// scrap D badge, white = unscanned / green = scanned.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders slip number and customer name', (tester) async {
    await tester.pumpWidget(wrap(const TyreBlock(
      slipNumber: '96962259',
      customer: 'EPS COURIERS SERVICES',
      detail: '315/80R22.5 · GOOD YEAR',
      scanned: false,
    )));
    expect(find.text('96962259'), findsOneWidget);
    expect(find.text('EPS COURIERS SERVICES'), findsOneWidget);
    expect(find.text('315/80R22.5 · GOOD YEAR'), findsOneWidget);
    expect(find.text('D'), findsNothing);
  });

  testWidgets('scrap blocks carry the D badge', (tester) async {
    await tester.pumpWidget(wrap(const TyreBlock(
      slipNumber: '98962056',
      customer: 'KANYI ILANGA',
      isScrap: true,
    )));
    expect(find.text('D'), findsOneWidget);
  });

  testWidgets('tap fires the callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(TyreBlock(
      slipNumber: '1',
      onTap: () => taps++,
    )));
    await tester.tap(find.byType(TyreBlock));
    expect(taps, 1);
  });

  testWidgets('grid lays out two columns on a phone width', (tester) async {
    await tester.pumpWidget(wrap(SizedBox(
      width: 360,
      child: TyreBlockGrid(blocks: [
        const TyreBlock(slipNumber: '1', scanned: false),
        const TyreBlock(slipNumber: '2', scanned: true),
        const TyreBlock(slipNumber: '3', scanned: true),
      ]),
    )));
    final first = tester.getTopLeft(find.text('1'));
    final second = tester.getTopLeft(find.text('2'));
    final third = tester.getTopLeft(find.text('3'));
    expect(first.dy, second.dy); // side by side
    expect(third.dy, greaterThan(first.dy)); // wrapped to row 2
    expect(tester.takeException(), isNull);
  });
}
