import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/data/repositories/settings_repository.dart';
import 'package:dispatch_diary/presentation/viewmodels/entries_viewmodel.dart';
import 'package:dispatch_diary/presentation/viewmodels/loading_sheet_viewmodel.dart';
import 'package:dispatch_diary/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App renders the field dock navigation without errors', (
    WidgetTester tester,
  ) async {
    final entryRepository = EntryRepository();
    final settingsRepository = SettingsRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: entryRepository),
          ChangeNotifierProvider.value(value: settingsRepository),
          ChangeNotifierProvider(
            create: (ctx) => EntriesViewModel(ctx.read<EntryRepository>()),
          ),
          ChangeNotifierProvider(
            create: (ctx) => LoadingSheetViewModel(ctx.read<EntryRepository>()),
          ),
        ],
        child: const DispatchDiaryApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify presence of the three navigation destinations
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Flush the automatic GitHub update check timer scheduled on launch
    // (fires a silent UpdateService check, which resolves to "no update").
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 11));
  });
}
