/// Calculates category allocations for a wake-up-anchored 24-hour window.
///
/// Schedule documents are the source of truth for logged time. A legacy sleep
/// interval is synthesized only for windows created before sleep sessions were
/// stored as schedule documents.
class BalanceWindowCalculator {
  const BalanceWindowCalculator._();

  static BalanceWindowTotals calculate({
    required Map<String, dynamic> window,
    required DateTime startAt,
    required DateTime endAt,
    required List<Map<String, dynamic>> events,
  }) {
    final intervals = <_Interval>[];
    for (final event in events) {
      final category = _categoryFor(event['category']?.toString() ?? '');
      if (category == null) continue;
      final start =
          _dateTime(event['startAt']) ??
          _legacyEventStart(event['date'], event['startMinutes']);
      final duration = _integer(event['durationMinutes']).clamp(0, 1000000);
      final end =
          _dateTime(event['endAt']) ?? start?.add(Duration(minutes: duration));
      if (start != null && end != null && end.isAfter(start)) {
        intervals.add(_Interval(start, end, category));
      }
    }

    // Older windows stored sleep as clock values rather than a session record.
    // Do not synthesize it for new windows: a deleted session must stay deleted.
    if (window['sleepSessionId'] == null) {
      final sleepStart = window['sleepStartMinutes'];
      final sleepEnd = window['sleepEndMinutes'];
      if (sleepStart is num && sleepEnd is num) {
        final sleep = _legacySleepInterval(
          windowStart: startAt,
          startMinutes: sleepStart.round(),
          endMinutes: sleepEnd.round(),
          offsetMinutes: window['utcOffsetMinutes'] is num
              ? (window['utcOffsetMinutes'] as num).round()
              : startAt.timeZoneOffset.inMinutes,
        );
        if (sleep != null) {
          intervals.add(_Interval(sleep.$1, sleep.$2, _Category.sleep));
        }
      }
    }

    final clipped = <_Interval>[];
    for (final interval in intervals) {
      final start = interval.start.isAfter(startAt) ? interval.start : startAt;
      final end = interval.end.isBefore(endAt) ? interval.end : endAt;
      if (end.isAfter(start)) {
        clipped.add(_Interval(start, end, interval.category));
      }
    }

    final boundaries = <int>{
      startAt.millisecondsSinceEpoch,
      endAt.millisecondsSinceEpoch,
    };
    for (final interval in clipped) {
      boundaries
        ..add(interval.start.millisecondsSinceEpoch)
        ..add(interval.end.millisecondsSinceEpoch);
    }
    final sorted = boundaries.toList()..sort();
    var workMillis = 0;
    var sleepMillis = 0;
    var lifeMillis = 0;
    var workLoggedMillis = 0;
    var workSessionMillis = 0;
    var commuteSessionMillis = 0;
    var sleepLoggedMillis = 0;
    var lifeLoggedMillis = 0;
    var overlapMillis = 0;

    for (var index = 0; index + 1 < sorted.length; index++) {
      final segmentStart = sorted[index];
      final segmentEnd = sorted[index + 1];
      final length = segmentEnd - segmentStart;
      if (length <= 0) continue;
      final activeCategories = clipped
          .where(
            (interval) =>
                interval.start.millisecondsSinceEpoch < segmentEnd &&
                interval.end.millisecondsSinceEpoch > segmentStart,
          )
          .map((interval) => interval.category)
          .toSet();
      if (activeCategories.isEmpty) continue;

      if (activeCategories.contains(_Category.work)) {
        workSessionMillis += length;
      }
      if (activeCategories.contains(_Category.commute)) {
        commuteSessionMillis += length;
      }
      final hasWorkTime =
          activeCategories.contains(_Category.work) ||
          activeCategories.contains(_Category.commute);
      if (hasWorkTime) {
        workLoggedMillis += length;
      }
      if (activeCategories.contains(_Category.sleep)) {
        sleepLoggedMillis += length;
      }
      if (activeCategories.contains(_Category.life)) {
        lifeLoggedMillis += length;
      }
      final activeGroups = activeCategories
          .map(
            (category) =>
                category == _Category.work || category == _Category.commute
                ? 'work'
                : category.name,
          )
          .toSet();
      if (activeGroups.length > 1) {
        overlapMillis += length;
      }

      // Resolve cross-category overlaps once, consistently. Duplicate sessions
      // in the same category form a union and never count a minute twice.
      if (hasWorkTime) {
        workMillis += length;
      } else if (activeCategories.contains(_Category.sleep)) {
        sleepMillis += length;
      } else {
        lifeMillis += length;
      }
    }

    final workMinutes = _toMinutes(workMillis);
    final sleepMinutes = _toMinutes(sleepMillis);
    final lifeMinutes = _toMinutes(lifeMillis);
    const windowMinutes = 24 * 60;
    final assignedMinutes = workMinutes + sleepMinutes + lifeMinutes;
    return BalanceWindowTotals(
      workMinutes: workMinutes,
      workSessionMinutes: _toMinutes(workSessionMillis),
      commuteSessionMinutes: _toMinutes(commuteSessionMillis),
      sleepMinutes: sleepMinutes,
      lifeMinutes: lifeMinutes,
      workLoggedMinutes: _toMinutes(workLoggedMillis),
      commuteLoggedMinutes: _toMinutes(commuteSessionMillis),
      sleepLoggedMinutes: _toMinutes(sleepLoggedMillis),
      lifeLoggedMinutes: _toMinutes(lifeLoggedMillis),
      freeMinutes: (windowMinutes - assignedMinutes)
          .clamp(0, windowMinutes)
          .toInt(),
      overlapMinutes: _toMinutes(overlapMillis),
    );
  }

  static int _toMinutes(int milliseconds) => (milliseconds / 60000).round();

  static int _integer(dynamic value) => value is num ? value.round() : 0;

  static DateTime? _dateTime(dynamic value) {
    if (value is DateTime) return value;
    // Keep this pure-Dart utility decoupled from Firestore. Timestamp values
    // passed by the UI are normalized to DateTime before calculation.
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static DateTime? _legacyEventStart(dynamic dateValue, dynamic minutesValue) {
    final dateText = dateValue?.toString();
    if (dateText == null || minutesValue is! num) return null;
    final date = DateTime.tryParse(dateText);
    if (date == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: minutesValue.round()));
  }

  static _Category? _categoryFor(String rawCategory) {
    switch (rawCategory.trim().toLowerCase()) {
      case 'work':
        return _Category.work;
      case 'commute':
        return _Category.commute;
      case 'sleep':
        return _Category.sleep;
      case 'system':
      case 'unallocated':
        return null;
      default:
        return _Category.life;
    }
  }

  static (DateTime, DateTime)? _legacySleepInterval({
    required DateTime windowStart,
    required int startMinutes,
    required int endMinutes,
    required int offsetMinutes,
  }) {
    final start = startMinutes.clamp(0, 1439).toInt();
    final end = endMinutes.clamp(0, 1439).toInt();
    final durationMinutes = (end - start + 1440) % 1440;
    if (durationMinutes == 0) return null;

    final pseudoLocalStart = DateTime.fromMillisecondsSinceEpoch(
      windowStart.millisecondsSinceEpoch + offsetMinutes * 60000,
      isUtc: true,
    );
    var nextSleepStart = DateTime.utc(
      pseudoLocalStart.year,
      pseudoLocalStart.month,
      pseudoLocalStart.day,
    ).add(Duration(minutes: start));
    if (!nextSleepStart.isAfter(pseudoLocalStart)) {
      nextSleepStart = nextSleepStart.add(const Duration(days: 1));
    }
    final startInstant = DateTime.fromMillisecondsSinceEpoch(
      nextSleepStart.millisecondsSinceEpoch - offsetMinutes * 60000,
      isUtc: true,
    );
    return (startInstant, startInstant.add(Duration(minutes: durationMinutes)));
  }
}

class BalanceWindowTotals {
  const BalanceWindowTotals({
    required this.workMinutes,
    required this.workSessionMinutes,
    required this.commuteSessionMinutes,
    required this.sleepMinutes,
    required this.lifeMinutes,
    required this.workLoggedMinutes,
    required this.commuteLoggedMinutes,
    required this.sleepLoggedMinutes,
    required this.lifeLoggedMinutes,
    required this.freeMinutes,
    required this.overlapMinutes,
  });

  final int workMinutes;
  final int workSessionMinutes;
  final int commuteSessionMinutes;
  final int sleepMinutes;
  final int lifeMinutes;
  final int workLoggedMinutes;
  final int commuteLoggedMinutes;
  final int sleepLoggedMinutes;
  final int lifeLoggedMinutes;
  final int freeMinutes;
  final int overlapMinutes;

  Map<String, int> get categoryMinutes => {
    'workAndCommute': workMinutes,
    'work': workSessionMinutes,
    'commute': commuteSessionMinutes,
    'sleep': sleepMinutes,
    'personalLife': lifeMinutes,
  };
}

enum _Category { work, commute, sleep, life }

class _Interval {
  const _Interval(this.start, this.end, this.category);

  final DateTime start;
  final DateTime end;
  final _Category category;
}
