import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/entry_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/migration_service.dart';
import 'data/services/supabase_service.dart';
import 'presentation/viewmodels/entries_viewmodel.dart';
import 'presentation/viewmodels/loading_sheet_viewmodel.dart';
import 'presentation/widgets/app_shell.dart';
import 'presentation/screens/today_screen.dart';
import 'presentation/screens/loading_sheet_screen.dart';
import 'presentation/screens/counter_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/archive_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }


  // Edge-to-edge status and navigation bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Supabase client
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase init error (app will work offline): $e');
  }

  // Initialize Repositories
  final entryRepository = EntryRepository();
  final settingsRepository = SettingsRepository();
  await settingsRepository.loadSettings();

  // One-time data repairs: split squashed entries, reconcile counts, and
  // de-duplicate trucks so Home and Sheet always agree.
  await MigrationService.runIfNeeded();

  // Initialize Realtime & initial background sync
  entryRepository.initRealtime();
  entryRepository.syncNow();

  runApp(
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
}

class DispatchDiaryApp extends StatefulWidget {
  const DispatchDiaryApp({super.key});

  @override
  State<DispatchDiaryApp> createState() => _DispatchDiaryAppState();
}

class _DispatchDiaryAppState extends State<DispatchDiaryApp> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TodayScreen(),
    LoadingSheetScreen(),
    CounterScreen(),
    SearchScreen(),
    ArchiveScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsRepository>(
      builder: (context, settings, _) {
        return MaterialApp(
          title: 'Dispatch Diary',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.isSunlightMode ? ThemeMode.light : ThemeMode.dark,
          home: AppShell(
            currentIndex: _currentIndex,
            onTabSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        );
      },
    );
  }
}
