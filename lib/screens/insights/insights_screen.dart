import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/balance_window_calculator.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../goals/goals_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/schedule_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  late DateTime _selectedWeek = _weekStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final previousWeek = _selectedWeek.subtract(const Duration(days: 7));

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(child: _InsightsIntro()),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Copy weekly summary',
                    onPressed: () =>
                        _copySummary(context, user.uid, _selectedWeek),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.eucalyptusDark,
                      side: BorderSide(color: AppColors.line),
                    ),
                    icon: const Icon(Icons.ios_share_outlined, size: 19),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAnalytics(user.uid, previousWeek),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _InsightsNavigationBar(),
    );
  }

  Widget _buildAnalytics(String userId, DateTime previousWeek) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().activitiesForWeek(userId, _selectedWeek),
      builder: (context, activitySnapshot) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().activitiesForWeek(userId, previousWeek),
            builder: (context, previousActivitySnapshot) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService().checkInsForWeek(
                    userId,
                    _selectedWeek,
                  ),
                  builder: (context, checkInSnapshot) =>
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirestoreService().checkInsForWeek(
                          userId,
                          previousWeek,
                        ),
                        builder: (context, previousCheckInSnapshot) {
                          final loading =
                              !activitySnapshot.hasData ||
                              !previousActivitySnapshot.hasData ||
                              !checkInSnapshot.hasData ||
                              !previousCheckInSnapshot.hasData;
                          final error =
                              activitySnapshot.hasError ||
                              previousActivitySnapshot.hasError ||
                              checkInSnapshot.hasError ||
                              previousCheckInSnapshot.hasError;
                          if (error) return const _InsightsError();
                          if (loading) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 50),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final timedActivities = _timedActivities(
                            activitySnapshot.data!.docs,
                          );
                          final previousTimedActivities = _timedActivities(
                            previousActivitySnapshot.data!.docs,
                          );
                          final energyByDay = _energyByDay(
                            checkInSnapshot.data!.docs,
                          );
                          final dailyCheckIns = _uniqueCheckInsByDay(
                            checkInSnapshot.data!.docs,
                          );
                          final previousEnergyByDay = _energyByDay(
                            previousCheckInSnapshot.data!.docs,
                          );
                          final workMinutes =
                              _minutesForArea(timedActivities, 'Work') +
                              _minutesForArea(timedActivities, 'Commute');
                          final personalMinutes =
                              _minutesForArea(timedActivities, 'Sleep') +
                              _minutesForArea(timedActivities, 'Rest') +
                              _minutesForArea(timedActivities, 'Life');
                          final previousWorkMinutes =
                              _minutesForArea(previousTimedActivities, 'Work') +
                              _minutesForArea(
                                previousTimedActivities,
                                'Commute',
                              );
                          final previousPersonalMinutes =
                              _minutesForArea(
                                previousTimedActivities,
                                'Sleep',
                              ) +
                              _minutesForArea(previousTimedActivities, 'Rest') +
                              _minutesForArea(previousTimedActivities, 'Life');
                          final dayTotals = _dailyTimeTotals(
                            timedActivities,
                            _selectedWeek,
                          );
                          final pattern = _patternInsight(
                            dailyCheckIns,
                            energyByDay,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _WeeklyBalanceCard(
                                userId: userId,
                                weekStart: _selectedWeek,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TimeSummaryCard(
                                      label: 'Work time',
                                      minutes: workMinutes,
                                      previousMinutes: previousWorkMinutes,
                                      icon: Icons.work_outline_rounded,
                                      color: AppColors.clay,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _TimeSummaryCard(
                                      label: 'Personal time',
                                      minutes: personalMinutes,
                                      previousMinutes: previousPersonalMinutes,
                                      icon: Icons.favorite_border_rounded,
                                      color: AppColors.eucalyptusDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _WeeklyGlanceCard(
                                weekStart: _selectedWeek,
                                dayTotals: dayTotals,
                                onPrevious: () => setState(
                                  () => _selectedWeek = _selectedWeek.subtract(
                                    const Duration(days: 7),
                                  ),
                                ),
                                onNext: () => setState(
                                  () => _selectedWeek = _selectedWeek.add(
                                    const Duration(days: 7),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _PatternCard(insight: pattern),
                              const SizedBox(height: 12),
                              _EnergyTrendCard(
                                weekStart: _selectedWeek,
                                dailyScores: energyByDay,
                                averageEnergy: _average(energyByDay.values),
                                previousAverage: _average(
                                  previousEnergyByDay.values,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                ),
          ),
    );
  }

  Future<void> _copySummary(
    BuildContext context,
    String userId,
    DateTime weekStart,
  ) async {
    try {
      final end = weekStart.add(const Duration(days: 6));
      final activitySnapshot = await FirestoreService()
          .activitiesForWeek(userId, weekStart)
          .first;
      final checkInSnapshot = await FirestoreService()
          .checkInsForWeek(userId, weekStart)
          .first;
      final scores = _energyByDay(checkInSnapshot.docs);
      final average = _average(scores.values);
      final activities = activitySnapshot.docs;
      final trackedActivities = _timedActivities(activities);
      final workMinutes =
          _minutesForArea(trackedActivities, 'Work') +
          _minutesForArea(trackedActivities, 'Commute');
      final lifeMinutes = _totalMinutes(trackedActivities) - workMinutes;
      final totalTrackedMinutes = workMinutes + lifeMinutes;
      final workShare = totalTrackedMinutes == 0
          ? 0
          : (workMinutes * 100 / totalTrackedMinutes).round();
      final lifeShare = totalTrackedMinutes == 0 ? 0 : 100 - workShare;
      final topActivity = _topTrackedActivity(trackedActivities);
      final activityCount = activities.length;
      final averageText = average == null
          ? 'No energy check-ins'
          : 'Average energy ${average.toStringAsFixed(1)}/10';
      final summary = [
        'WorkLife weekly summary',
        '${_formatDate(weekStart)} – ${_formatDate(end)}',
        averageText,
        '$activityCount activities logged',
        'Durations include activities whether checked off or not',
        if (totalTrackedMinutes > 0)
          'Work–life split: Work $workShare% (${_formatMinutes(workMinutes)}), Life $lifeShare% (${_formatMinutes(lifeMinutes)})',
        if (topActivity != null)
          'Largest activity duration: ${topActivity.title} (${topActivity.category}) · ${_formatMinutes(topActivity.minutes)}',
        if (totalTrackedMinutes == 0)
          'No activity durations recorded this week',
      ].join('\n');
      await Clipboard.setData(ClipboardData(text: summary));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Weekly summary copied.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Weekly summary export failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare weekly summary.')),
        );
      }
    }
  }

  static Map<String, int> _energyByDay(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = <String, int>{};
    for (final doc in _uniqueCheckInsByDay(docs)) {
      final rawScore = doc.data()['energyScore'];
      final dayKey = _checkInDayKey(doc);
      if (rawScore is num && dayKey != null) {
        result[dayKey] = rawScore.round().clamp(1, 10);
      }
    }
    return result;
  }

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _uniqueCheckInsByDay(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final byDay = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final dayKey = _checkInDayKey(doc);
      if (dayKey == null) continue;
      final existing = byDay[dayKey];
      if (existing == null || _isNewerCheckIn(doc, existing)) {
        byDay[dayKey] = doc;
      }
    }
    return byDay.values.toList(growable: false);
  }

  static String? _checkInDayKey(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final date =
        DateTime.tryParse(data['date']?.toString() ?? '') ??
        DateTime.tryParse(doc.id);
    if (date == null) return null;
    return _dateKey(DateTime(date.year, date.month, date.day));
  }

  static bool _isNewerCheckIn(
    QueryDocumentSnapshot<Map<String, dynamic>> candidate,
    QueryDocumentSnapshot<Map<String, dynamic>> existing,
  ) {
    final candidateUpdated = _checkInUpdatedAt(candidate);
    final existingUpdated = _checkInUpdatedAt(existing);
    if (candidateUpdated != existingUpdated) {
      return candidateUpdated > existingUpdated;
    }
    return candidate.data()['energyScore'] is num &&
        existing.data()['energyScore'] is! num;
  }

  static int _checkInUpdatedAt(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final value = doc.data()['updatedAt'];
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is num) return value.round();
    return 0;
  }

  static double? _average(Iterable<int> values) {
    final scores = values.toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  static Map<String, _DailyTimeTotals> _dailyTimeTotals(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
    DateTime weekStart,
  ) {
    final result = <String, _DailyTimeTotals>{};
    for (var index = 0; index < 7; index++) {
      final date = weekStart.add(Duration(days: index));
      result[_dateKey(date)] = _DailyTimeTotals();
    }

    for (final activity in activities) {
      final data = activity.data();
      final date = data['date']?.toString() ?? '';
      final current = result[date];
      final duration = data['durationMinutes'];
      if (current == null || duration is! num || duration <= 0) continue;

      final minutes = duration.round();
      final area = _canonicalArea(data['category']?.toString());
      if (area == 'Work' || area == 'Commute') {
        current.workMinutes += minutes;
      } else {
        current.personalMinutes += minutes;
      }
    }
    return result;
  }

  static _PatternInsight _patternInsight(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, int> energyByDay,
  ) {
    var lunchMarkedEnergyTotal = 0;
    var lunchMarkedCount = 0;
    var lunchUnmarkedEnergyTotal = 0;
    var lunchUnmarkedCount = 0;

    for (final doc in docs) {
      final data = doc.data();
      final score = data['energyScore'];
      final meals = data['mealStatus'];
      if (score is! num || meals is! Map) continue;
      final lunchMarked = meals['lunch'];
      if (lunchMarked is! bool) continue;
      if (lunchMarked) {
        lunchMarkedEnergyTotal += score.round().clamp(1, 10).toInt();
        lunchMarkedCount++;
      } else {
        lunchUnmarkedEnergyTotal += score.round().clamp(1, 10).toInt();
        lunchUnmarkedCount++;
      }
    }

    if (lunchMarkedCount >= 2 && lunchUnmarkedCount >= 2) {
      final markedAverage = lunchMarkedEnergyTotal / lunchMarkedCount;
      final unmarkedAverage = lunchUnmarkedEnergyTotal / lunchUnmarkedCount;
      final difference = markedAverage - unmarkedAverage;
      final title = difference.abs() < 0.35
          ? 'Energy was similar across lunch check-ins'
          : 'Energy was ${difference > 0 ? 'higher' : 'lower'} on lunch days';
      return _PatternInsight(
        title: title,
        description:
            'Your average was ${markedAverage.toStringAsFixed(1)}/10 on days you marked lunch and ${unmarkedAverage.toStringAsFixed(1)}/10 on days you did not ($lunchMarkedCount and $lunchUnmarkedCount check-ins).',
        note: 'A weekly pattern, not proof of cause.',
        icon: Icons.local_cafe_outlined,
      );
    }

    if (energyByDay.length >= 2) {
      final bestDay = _bestDay(energyByDay);
      final dayName = bestDay?.split(' · ').first;
      final score = bestDay?.split(' · ').last;
      return _PatternInsight(
        title: 'One day to notice',
        description: bestDay == null
            ? 'Your check-ins are beginning to show how your energy changes through the week.'
            : 'Your highest energy check-in was $dayName at $score. Keep noticing what your days feel like as you check in.',
        note: 'Based on this week’s Home check-ins.',
        icon: Icons.wb_sunny_outlined,
      );
    }

    return const _PatternInsight(
      title: 'A pattern takes time to form',
      description:
          'Check in with your energy and meals on more days to uncover what your week tends to feel like.',
      note: 'Your Home check-ins will appear here.',
      icon: Icons.auto_awesome_outlined,
    );
  }

  static int _minutesForArea(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
    String area,
  ) => activities
      .where(
        (activity) =>
            _canonicalArea(activity.data()['category']?.toString()) == area,
      )
      .fold<int>(0, (total, activity) {
        final duration = activity.data()['durationMinutes'];
        return total + (duration is num ? duration.round() : 0);
      });

  static String _canonicalArea(String? rawCategory) {
    switch (rawCategory?.trim().toLowerCase()) {
      case 'work':
        return 'Work';
      case 'commute':
        return 'Commute';
      case 'sleep':
        return 'Sleep';
      case 'rest':
        return 'Rest';
      default:
        return 'Life';
    }
  }

  static int _totalMinutes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
  ) => activities.fold<int>(0, (total, activity) {
    final duration = activity.data()['durationMinutes'];
    return total + (duration is num ? duration.round() : 0);
  });

  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _timedActivities(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
  ) => activities
      .where((activity) {
        final duration = activity.data()['durationMinutes'];
        return duration is num && duration > 0;
      })
      .toList(growable: false);

  static _TopTrackedActivity? _topTrackedActivity(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
  ) {
    final totals = <String, _TopTrackedActivity>{};
    for (final activity in activities) {
      final data = activity.data();
      final rawTitle = data['title']?.toString().trim() ?? '';
      final rawCategory = data['category']?.toString().trim() ?? '';
      final title = rawTitle.isEmpty ? 'Untitled activity' : rawTitle;
      final category = _canonicalArea(rawCategory);
      final duration = data['durationMinutes'];
      if (duration is! num || duration <= 0) continue;

      final key = '${category.toLowerCase()}|${title.toLowerCase()}';
      final existing = totals[key];
      totals[key] = _TopTrackedActivity(
        title: title,
        category: category,
        minutes: (existing?.minutes ?? 0) + duration.round(),
        entries: (existing?.entries ?? 0) + 1,
      );
    }

    _TopTrackedActivity? top;
    for (final activity in totals.values) {
      if (top == null || activity.minutes > top.minutes) top = activity;
    }
    return top;
  }

  static String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours == 0) return '${remainingMinutes}m';
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}m';
  }

  static String? _bestDay(Map<String, int> dailyScores) {
    if (dailyScores.isEmpty) return null;
    final entry = dailyScores.entries.reduce(
      (best, item) => item.value > best.value ? item : best,
    );
    final date = DateTime.tryParse(entry.key);
    if (date == null) return null;
    return '${_weekdayName(date.weekday)} · ${entry.value}/10';
  }

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _weekdayName(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];

  static String _formatDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';
}

class _DailyTimeTotals {
  int workMinutes = 0;
  int personalMinutes = 0;
}

class _PatternInsight {
  const _PatternInsight({
    required this.title,
    required this.description,
    required this.note,
    required this.icon,
  });

  final String title;
  final String description;
  final String note;
  final IconData icon;
}

class _TopTrackedActivity {
  const _TopTrackedActivity({
    required this.title,
    required this.category,
    required this.minutes,
    required this.entries,
  });

  final String title;
  final String category;
  final int minutes;
  final int entries;
}

String _insightsDateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _InsightsIntro extends StatelessWidget {
  const _InsightsIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A MOMENT FOR YOU',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.clayDark,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Balance insights',
          style: GoogleFonts.fraunces(
            fontSize: 27,
            height: 1.05,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Let’s take a gentle look at how your time and energy felt this week.',
          style: GoogleFonts.inter(
            fontSize: 11,
            height: 1.35,
            color: AppColors.sub,
          ),
        ),
      ],
    );
  }
}

class _WeeklyBalanceCard extends StatelessWidget {
  const _WeeklyBalanceCard({required this.userId, required this.weekStart});

  final String userId;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final startAt = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final endAt = startAt.add(const Duration(days: 7));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().scheduleForWindow(
        userId: userId,
        startAt: startAt,
        endAt: endAt,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _InsightsError();
        if (!snapshot.hasData) {
          return const _WeeklyBalanceLoadingCard();
        }
        final totals = _weeklyAllocation(startAt, snapshot.data!.docs);
        final slices = [
          _WeeklyAllocationSlice(
            'Work + commute',
            totals.workMinutes,
            AppColors.clayDark,
          ),
          _WeeklyAllocationSlice(
            'Sleep',
            totals.sleepMinutes,
            AppColors.eucalyptusDark,
          ),
          _WeeklyAllocationSlice(
            'Personal life',
            totals.lifeMinutes,
            const Color(0xFF8A6545),
          ),
          _WeeklyAllocationSlice(
            'Free time',
            totals.freeMinutes,
            const Color(0xFFB4B5A5),
          ),
        ];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.pistachio.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.eucalyptusDark.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WEEKLY BALANCE',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.85,
                  color: AppColors.eucalyptusDark,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _WeeklyAllocationRingPainter(slices),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _InsightsScreenState._formatMinutes(
                                totals.freeMinutes,
                              ),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fraunces(
                                fontSize: 12,
                                height: 1.05,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              'FREE',
                              style: GoogleFonts.inter(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.sub,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Free time to allocate',
                          style: GoogleFonts.fraunces(
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Across seven 24-hour windows. Same categories and overlap rules as Home.',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            height: 1.4,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: slices
                        .map(
                          (slice) => SizedBox(
                            width: width,
                            child: _WeeklyAllocationLegend(slice: slice),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static _WeeklyAllocationTotals _weeklyAllocation(
    DateTime weekStart,
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final events = docs
        .map((doc) {
          final data = doc.data();
          return <String, dynamic>{
            ...data,
            'startAt': _dateTime(data['startAt']),
            'endAt': _dateTime(data['endAt']),
          };
        })
        .toList(growable: false);
    var workMinutes = 0;
    var sleepMinutes = 0;
    var lifeMinutes = 0;
    var freeMinutes = 0;
    for (var index = 0; index < 7; index++) {
      final startAt = weekStart.add(Duration(days: index));
      final day = BalanceWindowCalculator.calculate(
        window: const <String, dynamic>{},
        startAt: startAt,
        endAt: startAt.add(const Duration(hours: 24)),
        events: events,
      );
      workMinutes += day.workMinutes;
      sleepMinutes += day.sleepMinutes;
      lifeMinutes += day.lifeMinutes;
      freeMinutes += day.freeMinutes;
    }
    return _WeeklyAllocationTotals(
      workMinutes: workMinutes,
      sleepMinutes: sleepMinutes,
      lifeMinutes: lifeMinutes,
      freeMinutes: freeMinutes,
    );
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.round());
    return null;
  }
}

class _WeeklyBalanceLoadingCard extends StatelessWidget {
  const _WeeklyBalanceLoadingCard();

  @override
  Widget build(BuildContext context) => Container(
    height: 180,
    decoration: BoxDecoration(
      color: AppColors.pistachio.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: AppColors.eucalyptusDark.withValues(alpha: 0.12),
      ),
    ),
    child: const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _WeeklyAllocationTotals {
  const _WeeklyAllocationTotals({
    required this.workMinutes,
    required this.sleepMinutes,
    required this.lifeMinutes,
    required this.freeMinutes,
  });

  final int workMinutes;
  final int sleepMinutes;
  final int lifeMinutes;
  final int freeMinutes;
}

class _WeeklyAllocationSlice {
  const _WeeklyAllocationSlice(this.label, this.minutes, this.color);

  final String label;
  final int minutes;
  final Color color;
}

class _WeeklyAllocationRingPainter extends CustomPainter {
  const _WeeklyAllocationRingPainter(this.slices);

  final List<_WeeklyAllocationSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.shortestSide / 2 - strokeWidth / 2,
    );
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.eucalyptus.withValues(alpha: 0.45);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, backgroundPaint);

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.minutes <= 0) continue;
      final sweepAngle = slice.minutes / (7 * 24 * 60) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyAllocationRingPainter oldDelegate) =>
      true;
}

class _WeeklyAllocationLegend extends StatelessWidget {
  const _WeeklyAllocationLegend({required this.slice});

  final _WeeklyAllocationSlice slice;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          slice.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 8, color: AppColors.sub),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        _InsightsScreenState._formatMinutes(slice.minutes),
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    ],
  );
}

class _TimeSummaryCard extends StatelessWidget {
  const _TimeSummaryCard({
    required this.label,
    required this.minutes,
    required this.previousMinutes,
    required this.icon,
    required this.color,
  });

  final String label;
  final int minutes;
  final int previousMinutes;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final difference = minutes - previousMinutes;
    final comparison = previousMinutes == 0
        ? minutes == 0
              ? 'No time logged yet'
              : 'No time logged last week'
        : difference == 0
        ? 'Same as last week'
        : '${_InsightsScreenState._formatMinutes(difference.abs())} ${difference > 0 ? 'more' : 'less'} than last week';

    return Container(
      constraints: const BoxConstraints(minHeight: 99),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sub,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _InsightsScreenState._formatMinutes(minutes),
            style: GoogleFonts.fraunces(
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            comparison,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 8.5, color: AppColors.sub),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGlanceCard extends StatelessWidget {
  const _WeeklyGlanceCard({
    required this.weekStart,
    required this.dayTotals,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final Map<String, _DailyTimeTotals> dayTotals;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final now = DateTime.now();
    final currentWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final isCurrentWeek = DateUtils.isSameDay(weekStart, currentWeekStart);
    final values = List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      return dayTotals[_insightsDateKey(date)] ?? _DailyTimeTotals();
    });
    final maxMinutes = values.fold<int>(
      0,
      (maximum, day) =>
          math.max(maximum, math.max(day.workMinutes, day.personalMinutes)),
    );
    final dateLabel =
        '${MaterialLocalizations.of(context).formatMediumDate(weekStart)} – ${MaterialLocalizations.of(context).formatMediumDate(weekEnd)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your week at a glance',
                  style: GoogleFonts.fraunces(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                isCurrentWeek ? 'This week' : '7 days',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 30,
                child: IconButton(
                  tooltip: 'Previous week',
                  padding: EdgeInsets.zero,
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left, size: 18),
                ),
              ),
              Expanded(
                child: Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                height: 30,
                child: IconButton(
                  tooltip: 'Next week',
                  padding: EdgeInsets.zero,
                  onPressed: isCurrentWeek ? null : onNext,
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 94,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(7, (index) {
                final day = values[index];
                final workHeight = maxMinutes == 0
                    ? 2.0
                    : math.max(3.0, day.workMinutes / maxMinutes * 66);
                final personalHeight = maxMinutes == 0
                    ? 2.0
                    : math.max(3.0, day.personalMinutes / maxMinutes * 66);
                final label = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index];
                return Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 6,
                                height: workHeight.toDouble(),
                                decoration: BoxDecoration(
                                  color: AppColors.eucalyptusDark,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Container(
                                width: 6,
                                height: personalHeight.toDouble(),
                                decoration: BoxDecoration(
                                  color: AppColors.clay,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(color: AppColors.eucalyptusDark, label: 'Work'),
              const SizedBox(width: 15),
              _ChartLegend(color: AppColors.clay, label: 'Personal'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 8, color: AppColors.sub)),
    ],
  );
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.insight});

  final _PatternInsight insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A pattern worth keeping',
            style: GoogleFonts.fraunces(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(insight.icon, size: 24, color: AppColors.clayDark),
          ),
          const SizedBox(height: 9),
          Text(
            insight.title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight.description,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              height: 1.4,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.pistachio.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 10,
                  color: AppColors.eucalyptusDark,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    insight.note,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      color: AppColors.eucalyptusDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.clayDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.fraunces(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.sub),
        ),
      ],
    );
  }
}

class _EnergyTrendCard extends StatelessWidget {
  final DateTime weekStart;
  final Map<String, int> dailyScores;
  final double? averageEnergy;
  final double? previousAverage;

  const _EnergyTrendCard({
    required this.weekStart,
    required this.dailyScores,
    required this.averageEnergy,
    required this.previousAverage,
  });

  @override
  Widget build(BuildContext context) {
    final values = List<int?>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final key = _insightsDateKey(date);
      return dailyScores[key];
    });
    final scoreCount = values.whereType<int>().length;
    final difference = averageEnergy == null || previousAverage == null
        ? null
        : averageEnergy! - previousAverage!;
    final trendIcon = difference == null || difference.abs() < 0.05
        ? Icons.remove
        : difference > 0
        ? Icons.trending_up
        : Icons.trending_down;
    final trendColor = difference == null || difference.abs() < 0.05
        ? AppColors.sub
        : difference > 0
        ? AppColors.eucalyptusDark
        : AppColors.clayDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your energy this week',
            style: GoogleFonts.fraunces(
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'From your Home check-ins, day by day.',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
          ),
          const SizedBox(height: 12),
          if (scoreCount < 2)
            SizedBox(
              height: 130,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.show_chart, color: AppColors.clayDark),
                    const SizedBox(height: 8),
                    Text(
                      scoreCount == 0
                          ? 'No energy check-ins this week yet.'
                          : 'One check-in so far. Add another day to see a trend.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(painter: _EnergyTrendPainter(values)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var index = 0; index < 7; index++)
                  Expanded(
                    child: Text(
                      _weekdayInitial(index),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppColors.sub,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  icon: Icons.bolt_outlined,
                  value: averageEnergy == null
                      ? '—'
                      : '${averageEnergy!.toStringAsFixed(1)}/10',
                  label: 'Average energy',
                ),
              ),
              Container(width: 1, height: 46, color: AppColors.line),
              Expanded(
                child: _SummaryStat(
                  icon: trendIcon,
                  value: difference == null
                      ? '—'
                      : '${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(1)}',
                  label: 'vs last week',
                  color: trendColor,
                ),
              ),
              Container(width: 1, height: 46, color: AppColors.line),
              Expanded(
                child: _SummaryStat(
                  icon: Icons.check_circle_outline,
                  value: '$scoreCount/7',
                  label: 'Check-ins',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _weekdayInitial(int index) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index];
}

class _EnergyTrendPainter extends CustomPainter {
  final List<int?> values;

  const _EnergyTrendPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 18.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 12.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = AppColors.eucalyptusDark
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()
      ..color = AppColors.clayDark
      ..style = PaintingStyle.fill;

    for (var guide = 0; guide < 3; guide++) {
      final y = top + chartHeight * guide / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final points = <Offset?>[];
    for (var index = 0; index < values.length; index++) {
      final score = values[index];
      if (score == null) {
        points.add(null);
      } else {
        final x = left + chartWidth * index / 6;
        final y = top + chartHeight * (10 - score) / 9;
        points.add(Offset(x, y));
      }
    }

    var path = Path();
    var hasPoint = false;
    for (final point in points) {
      if (point == null) {
        if (hasPoint) canvas.drawPath(path, linePaint);
        path = Path();
        hasPoint = false;
      } else {
        if (hasPoint) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          hasPoint = true;
        }
        canvas.drawCircle(point, 4, pointPaint);
      }
    }
    if (hasPoint) canvas.drawPath(path, linePaint);

    final labelStyle = TextStyle(
      color: AppColors.sub,
      fontSize: 9,
      fontFamily: GoogleFonts.inter().fontFamily,
    );
    for (final label in [10, 5, 1]) {
      final y = top + chartHeight * (10 - label) / 9 - 5;
      final text = TextPainter(
        text: TextSpan(text: '$label', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y));
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyTrendPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _NotEnoughDataCard extends StatelessWidget {
  final String message;

  const _NotEnoughDataCard({
    this.message =
        'Not enough data for this week yet. Energy check-ins and logged activities will build your reflection here.',
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppColors.peach,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        const Icon(Icons.insights_outlined, color: AppColors.clayDark),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InsightsError extends StatelessWidget {
  const _InsightsError();

  @override
  Widget build(BuildContext context) => const _NotEnoughDataCard(
    message:
        'Weekly insights could not be loaded. Check your connection and retry.',
  );
}

class _InsightsNavigationBar extends StatelessWidget {
  const _InsightsNavigationBar();

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: AppColors.ivory,
      elevation: 0,
      selectedIndex: 3,
      indicatorColor: AppColors.eucalyptus,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today),
          label: 'Schedule',
        ),
        NavigationDestination(
          icon: Icon(Icons.flag_outlined),
          selectedIcon: Icon(Icons.flag),
          label: 'Goals',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          selectedIcon: Icon(Icons.insights),
          label: 'Insights',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onDestinationSelected: (index) {
        if (index == 0) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (index == 1) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ScheduleScreen()),
          );
        } else if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          );
        } else if (index == 4) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      },
    );
  }
}
