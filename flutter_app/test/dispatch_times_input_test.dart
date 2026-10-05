import 'package:flutter_test/flutter_test.dart';
import 'package:dispatch_diary/dispatch/dispatch_api.dart';

void main() {
  group('DispatchApi times input — board regression', () {
    test('todayRange returns start-of-day and now in epoch seconds', () {
      final now = DateTime(2026, 10, 4, 14, 30, 15);
      final (start, end) = DispatchApi.todayRange(now);

      final nowSec = now.millisecondsSinceEpoch ~/ 1000;
      expect(end, nowSec);
      // start = latest UTC-midnight boundary at or before now (the same
      // convention the dispatch-app board cubit uses for the backend)
      expect(start, nowSec - (nowSec % 86400));
      expect(start <= end, isTrue);
      expect(end - start < 86400, isTrue);
    });

    test('todayRange is stable across DST-free SAST clock times', () {
      // 06:00 and 22:00 on the same local day must share the same start
      final morning = DateTime(2026, 10, 4, 6, 0, 0);
      final evening = DateTime(2026, 10, 4, 22, 0, 0);
      final (mStart, _) = DispatchApi.todayRange(morning);
      final (eStart, _) = DispatchApi.todayRange(evening);
      expect(mStart, eStart);
    });

    test('timesInput builds the object the times! enum expects', () {
      final payload = DispatchApi.timesInput(1000, 2000);
      expect(payload, {'start_time': 1000, 'end_time': 2000});
    });
  });
}
