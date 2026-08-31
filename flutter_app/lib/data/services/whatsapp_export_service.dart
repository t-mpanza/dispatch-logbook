import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/formatters.dart';
import '../models/entry.dart';

class WhatsAppExportService {
  static String formatWhatsAppText(Entry entry, String despatcherName) {
    final trips = entry.loadingSheetTrips ?? [];
    final buffer = StringBuffer();

    buffer.writeln('*DESPATCH LOADING SHEET*');
    buffer.writeln('📅 Date: ${entry.dayKey}');
    buffer.writeln('👤 Despatcher: $despatcherName');
    buffer.writeln();

    int totalTyres = 0;
    int totalMinutes = 0;

    for (var i = 0; i < trips.length; i++) {
      final t = trips[i];
      totalTyres += t.quantityLoaded;
      totalMinutes += t.durationMinutes ?? 0;

      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      final tripTitle = t.tripId.isNotEmpty ? t.tripId : 'TRIP ${i + 1}';
      final regPart = t.reg.isNotEmpty ? ' | ${t.reg}' : '';
      buffer.writeln('${i + 1}. *$tripTitle*$regPart');

      if (t.driverName.isNotEmpty) {
        buffer.writeln('   Driver: ${t.driverName}');
      }
      buffer.writeln('   Tyres: ${t.quantityLoaded}');

      if (t.startTime != null && t.finishTime != null) {
        final startStr = AppFormatters.formatTimeHHmm(t.startTime);
        final finishStr = AppFormatters.formatTimeHHmm(t.finishTime);
        final dur = t.durationMinutes ?? 0;
        buffer.writeln('   Time: $startStr → $finishStr (${dur}m)');
      }
      if (t.note != null && t.note!.isNotEmpty) {
        buffer.writeln('   Note: ${t.note}');
      }
    }

    if (trips.isNotEmpty) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    }

    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final timeFormatted = totalMinutes > 0
        ? (hours > 0 ? '${hours}h ${mins}m (${totalMinutes}m)' : '$totalMinutes mins')
        : '0 mins';

    buffer.writeln();
    buffer.writeln('*SUMMARY*');
    buffer.writeln('🚚 Total Trucks: ${trips.length}');
    buffer.writeln('📦 Total Tyres: $totalTyres');
    buffer.writeln('⏱ Total Time: $timeFormatted');

    return buffer.toString();
  }

  static Future<bool> shareToWhatsApp(String text) async {
    // 1. Copy to clipboard automatically for redundancy
    await Clipboard.setData(ClipboardData(text: text));

    // 2. Try launching WhatsApp directly via url_launcher
    final encoded = Uri.encodeComponent(text);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}

    // 3. Fallback to native system share sheet
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: 'Despatch Loading Sheet'));
      return true;
    } catch (_) {
      return false;
    }
  }
}
