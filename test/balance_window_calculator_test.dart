import 'package:flutter_test/flutter_test.dart';
import 'package:worklife/services/balance_window_calculator.dart';

void main() {
  final windowStart = DateTime(2026, 10, 15, 7);
  final windowEnd = windowStart.add(const Duration(hours: 24));

  Map<String, dynamic> session({
    required String id,
    required String category,
    required int startMinute,
    required int durationMinutes,
  }) {
    final startAt = windowStart.add(Duration(minutes: startMinute));
    return {
      'id': id,
      'category': category,
      'startAt': startAt,
      'endAt': startAt.add(Duration(minutes: durationMinutes)),
      'durationMinutes': durationMinutes,
    };
  }

  BalanceWindowTotals calculate(
    Iterable<Map<String, dynamic>> sessions, {
    Map<String, dynamic> window = const {},
  }) {
    return BalanceWindowCalculator.calculate(
      window: window,
      startAt: windowStart,
      endAt: windowEnd,
      events: sessions.toList(),
    );
  }

  group('BalanceWindowCalculator', () {
    test('editing one sleep session replaces its previous duration', () {
      final savedById = <String, Map<String, dynamic>>{
        'sleep-main': session(
          id: 'sleep-main',
          category: 'Sleep',
          startMinute: 16 * 60,
          durationMinutes: 7 * 60,
        ),
      };
      expect(calculate(savedById.values).sleepMinutes, 7 * 60);

      savedById['sleep-main'] = session(
        id: 'sleep-main',
        category: 'Sleep',
        startMinute: 16 * 60,
        durationMinutes: 8 * 60,
      );
      expect(calculate(savedById.values).sleepMinutes, 8 * 60);

      // Saving the same record again must not add another copy.
      savedById['sleep-main'] = session(
        id: 'sleep-main',
        category: 'Sleep',
        startMinute: 16 * 60,
        durationMinutes: 8 * 60,
      );
      expect(calculate(savedById.values).sleepMinutes, 8 * 60);

      savedById['sleep-main'] = session(
        id: 'sleep-main',
        category: 'Sleep',
        startMinute: 16 * 60,
        durationMinutes: 6 * 60,
      );
      expect(calculate(savedById.values).sleepMinutes, 6 * 60);

      savedById['nap'] = session(
        id: 'nap',
        category: 'Sleep',
        startMinute: 4 * 60,
        durationMinutes: 60,
      );
      expect(calculate(savedById.values).sleepMinutes, 7 * 60);
    });

    test('work, commute, and personal life edits use the latest records', () {
      final savedById = <String, Map<String, dynamic>>{
        'work': session(
          id: 'work',
          category: 'Work',
          startMinute: 60,
          durationMinutes: 8 * 60,
        ),
        'commute': session(
          id: 'commute',
          category: 'Commute',
          startMinute: 9 * 60,
          durationMinutes: 2 * 60,
        ),
        'life': session(
          id: 'life',
          category: 'Life',
          startMinute: 12 * 60,
          durationMinutes: 3 * 60,
        ),
      };
      final initialTotals = calculate(savedById.values);
      expect(initialTotals.workSessionMinutes, 8 * 60);
      expect(initialTotals.commuteSessionMinutes, 2 * 60);
      expect(initialTotals.workMinutes, 10 * 60);
      expect(calculate(savedById.values).lifeMinutes, 3 * 60);

      savedById['work'] = session(
        id: 'work',
        category: 'Work',
        startMinute: 60,
        durationMinutes: 9 * 60,
      );
      savedById['commute'] = session(
        id: 'commute',
        category: 'Commute',
        startMinute: 10 * 60,
        durationMinutes: 60,
      );
      savedById['life'] = session(
        id: 'life',
        category: 'Life',
        startMinute: 12 * 60,
        durationMinutes: 4 * 60,
      );

      final totals = calculate(savedById.values);
      expect(totals.workMinutes, 10 * 60);
      expect(totals.workSessionMinutes, 9 * 60);
      expect(totals.commuteSessionMinutes, 60);
      expect(totals.workLoggedMinutes, 10 * 60);
      expect(totals.lifeMinutes, 4 * 60);
    });

    test('does not add legacy sleep twice when a linked session is saved', () {
      final totals = calculate(
        [
          session(
            id: 'sleep-main',
            category: 'Sleep',
            startMinute: 16 * 60,
            durationMinutes: 8 * 60,
          ),
        ],
        window: {
          'sleepSessionId': 'sleep-main',
          'sleepStartMinutes': 22 * 60,
          'sleepEndMinutes': 6 * 60,
          'utcOffsetMinutes': windowStart.timeZoneOffset.inMinutes,
        },
      );

      expect(totals.sleepMinutes, 8 * 60);
    });

    test(
      'clips intervals to the window, resolves overlaps once, and frees gaps',
      () {
        final totals = calculate([
          {
            ...session(
              id: 'work',
              category: 'Work',
              startMinute: -60,
              durationMinutes: 3 * 60,
            ),
            'startAt': windowStart.subtract(const Duration(hours: 1)),
            'endAt': windowStart.add(const Duration(hours: 2)),
          },
          session(
            id: 'life',
            category: 'Life',
            startMinute: 60,
            durationMinutes: 2 * 60,
          ),
        ]);

        expect(totals.workMinutes, 2 * 60);
        expect(totals.lifeMinutes, 60);
        expect(totals.overlapMinutes, 60);
        expect(totals.freeMinutes, 21 * 60);
        expect(
          totals.workMinutes +
              totals.sleepMinutes +
              totals.lifeMinutes +
              totals.freeMinutes,
          24 * 60,
        );
      },
    );

    test('empty window is entirely free and full window has no free time', () {
      expect(calculate([]).freeMinutes, 24 * 60);

      final fullyAllocated = calculate([
        session(
          id: 'work',
          category: 'Work',
          startMinute: 0,
          durationMinutes: 11 * 60,
        ),
        session(
          id: 'sleep',
          category: 'Sleep',
          startMinute: 11 * 60,
          durationMinutes: 8 * 60,
        ),
        session(
          id: 'life',
          category: 'Life',
          startMinute: 19 * 60,
          durationMinutes: 5 * 60,
        ),
      ]);
      expect(fullyAllocated.freeMinutes, 0);
    });
  });
}
