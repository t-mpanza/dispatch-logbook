import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:dispatch_diary/data/repositories/entry_repository.dart';
import 'package:dispatch_diary/data/repositories/settings_repository.dart';
import 'package:dispatch_diary/presentation/viewmodels/entries_viewmodel.dart';
import 'package:dispatch_diary/presentation/viewmodels/loading_sheet_viewmodel.dart';
import 'package:dispatch_diary/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders AppShell dock navigation without errors', (WidgetTester tester) async {
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

    // Verify presence of navigation items
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Counter'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
  });
}
