import 'package:dispatch_diary/presentation/widgets/offload_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D5 — the offload window: fail loud, then a yes/no. OFFLOAD commits
/// loaded:0; CONTINUE keeps scanning.
void main() {
  testWidgets('shows the question and returns true on OFFLOAD',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showOffloadDialog(
              context,
              label: '96962259 · EPS',
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('OFFLOAD?'), findsOneWidget);
    expect(find.textContaining('96962259'), findsWidgets);
    await tester.tap(find.text('OFFLOAD'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('returns false on CONTINUE', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showOffloadDialog(context, label: '96962259');
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE SCANNING'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
