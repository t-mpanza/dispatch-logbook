import 'package:intl/intl.dart';

class AppFormatters {
  static String dayKey(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  static String dayKeyFromEpoch(int epochMs) {
    return dayKey(DateTime.fromMillisecondsSinceEpoch(epochMs));
  }

  static String monthKey(DateTime dt) {
    return DateFormat('yyyy-MM').format(dt);
  }

  static String yearKey(DateTime dt) {
    return DateFormat('yyyy').format(dt);
  }

  static String formatTimeHHmm(int? epochMs) {
    if (epochMs == null || epochMs == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    return DateFormat('HH:mm').format(dt);
  }

  static String formatDayLabel(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    if (itemDate == today) {
      return 'Today, ${DateFormat('d MMM').format(dt)}';
    } else if (itemDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('d MMM').format(dt)}';
    } else {
      return DateFormat('EEEE, d MMM yyyy').format(dt);
    }
  }

  static String formatShortDay(DateTime dt) {
    return DateFormat('EEE, d MMM').format(dt);
  }

  static String formatMonth(DateTime dt) {
    return DateFormat('MMMM yyyy').format(dt);
  }

  static int getWeekNumber(DateTime date) {
    // ISO 8601 week number calculation
    final dayOfYear = int.parse(DateFormat("D").format(date));
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    return woy;
  }

  static String getWeekRangeLabel(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM');
    return '${fmt.format(startOfWeek)} – ${fmt.format(endOfWeek)}';
  }

  static int? timeStringToMs(String timeStr, int baseDateMs) {
    if (timeStr.trim().isEmpty) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length != 2) return null;
    final hours = int.tryParse(parts[0]);
    final mins = int.tryParse(parts[1]);
    if (hours == null || mins == null) return null;

    final base = DateTime.fromMillisecondsSinceEpoch(baseDateMs);
    final result = DateTime(base.year, base.month, base.day, hours, mins, 0, 0);
    return result.millisecondsSinceEpoch;
  }
}
