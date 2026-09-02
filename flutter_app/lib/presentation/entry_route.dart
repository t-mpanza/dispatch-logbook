import 'package:flutter/material.dart';

import '../data/models/entry.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/stocks_entry_detail_screen.dart';

/// Smart entry detection: STOCKS (IBT) entries get their dedicated screen,
/// everything else uses the standard entry detail flow.
bool isStocksEntry(Entry entry) {
  final title = entry.title.trim().toUpperCase();
  if (title.startsWith('STOCKS')) return true;
  if (entry.tags.any((t) => t.toLowerCase() == 'stocks')) return true;
  final hasIbt =
      entry.loadingSheetTrips?.any((t) => t.hasIbtDocuments) ?? false;
  return hasIbt;
}

/// Route an entry to the correct detail screen without the flicker of
/// opening the standard screen first.
void openEntryDetail(BuildContext context, Entry entry) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => isStocksEntry(entry)
          ? StocksEntryDetailScreen(entryId: entry.id)
          : EntryDetailScreen(entryId: entry.id),
    ),
  );
}
