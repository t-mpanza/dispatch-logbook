import 'package:flutter/material.dart';

import '../data/models/entry.dart';
import '../data/repositories/staged_document_repository.dart';
import '../data/services/database_service.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/scraps_screen.dart';
import 'screens/stocks_entry_detail_screen.dart';
import 'screens/truck_hub_screen.dart';

/// Smart entry detection: STOCKS (IBT) entries get their dedicated screen,
/// SCRAPS entries get the scrap run-out screen, entries with staged
/// documents get the truck hub, everything else uses the standard entry
/// detail flow.
bool isStocksEntry(Entry entry) {
  final title = entry.title.trim().toUpperCase();
  if (title.startsWith('STOCKS')) return true;
  if (entry.tags.any((t) => t.toLowerCase() == 'stocks')) return true;
  final hasIbt =
      entry.loadingSheetTrips?.any((t) => t.hasIbtDocuments) ?? false;
  return hasIbt;
}

bool isScrapsEntry(Entry entry) {
  if (entry.title.trim().toUpperCase() == 'SCRAPS') return true;
  return entry.tags.any((t) => t.toLowerCase() == 'scraps');
}

/// The hub owns entries with staged documents (multi-document trucks);
/// every other entry keeps its legacy screen until the hub reaches full
/// parity (P5). One SQLite read decides — routing stays honest.
Future<bool> hasStagedDocuments(String entryId) async {
  final db = await DatabaseService.database;
  final docs = await StagedDocumentRepository(db).listForEntry(entryId);
  return docs.isNotEmpty;
}

/// Route an entry to the correct detail screen without the flicker of
/// opening the standard screen first.
Future<void> openEntryDetail(BuildContext context, Entry entry) async {
  final hub = await hasStagedDocuments(entry.id);
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => hub
          ? TruckHubScreen(entryId: entry.id)
          : isScrapsEntry(entry)
              ? ScrapsScreen(entryId: entry.id)
              : isStocksEntry(entry)
                  ? StocksEntryDetailScreen(entryId: entry.id)
                  : EntryDetailScreen(entryId: entry.id),
    ),
  );
}

/// Same smart routing, but replaces the current route (used after creating
/// a brand-new entry so the back button does not return to the composer).
Future<void> openEntryDetailReplacing(BuildContext context, Entry entry) async {
  final hub = await hasStagedDocuments(entry.id);
  if (!context.mounted) return;
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => hub
          ? TruckHubScreen(entryId: entry.id)
          : isScrapsEntry(entry)
              ? ScrapsScreen(entryId: entry.id)
              : isStocksEntry(entry)
                  ? StocksEntryDetailScreen(entryId: entry.id)
                  : EntryDetailScreen(entryId: entry.id),
    ),
  );
}
