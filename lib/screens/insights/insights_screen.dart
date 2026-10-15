import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().userDocument(user.uid).snapshots(),
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data?.data() ?? {};
        final workdays = _readStringList(profile['workdays']);
        return Scaffold(
          backgroundColor: AppColors.ivory,
          appBar: AppBar(
            backgroundColor: AppColors.ivory,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 20,
            title: Text(
              'Insights',
              style: GoogleFonts.fraunces(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Copy weekly summary',
                onPressed: () => _copySummary(context, user.uid, _selectedWeek),
                icon: const Icon(Icons.ios_share_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InsightsIntro(),
                const SizedBox(height: 20),
                _WeekSelector(
                  weekStart: _selectedWeek,
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
                const SizedBox(height: 22),
                _buildAnalytics(
                  context,
                  user.uid,
                  previousWeek,
                  workdays.length,
                ),
              ],
            ),
          ),
          bottomNavigationBar: const _InsightsNavigationBar(),
        );
      },
    );
  }

  Widget _buildAnalytics(
    BuildContext context,
    String userId,
    DateTime previousWeek,
    int workdayCount,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().activitiesForWeek(userId, _selectedWeek),
      builder: (context, activitySnapshot) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().checkInsForWeek(userId, _selectedWeek),
            builder: (context, checkInSnapshot) =>
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService().checkInsForWeek(
                    userId,
                    previousWeek,
                  ),
                  builder: (context, previousCheckInSnapshot) =>
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirestoreService().activeGoals(userId),
                        builder: (context, goalSnapshot) {
                          final loading =
                              !activitySnapshot.hasData ||
                              !checkInSnapshot.hasData ||
                              !previousCheckInSnapshot.hasData ||
                              !goalSnapshot.hasData;
                          final error =
                              activitySnapshot.hasError ||
                              checkInSnapshot.hasError ||
                              previousCheckInSnapshot.hasError ||
                              goalSnapshot.hasError;
                          if (error) {
                            return const _InsightsError();
                          }
                          if (loading) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 50),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final activities = activitySnapshot.data!.docs;
                          final trackedActivities = _completedTimedActivities(
                            activities,
                          );
                          final energyByDay = _energyByDay(
                            checkInSnapshot.data!.docs,
                          );
                          final previousEnergyByDay = _energyByDay(
                            previousCheckInSnapshot.data!.docs,
                          );
                          final goals = goalSnapshot.data!.docs.where((goal) {
                            final date = goal.data()['date']?.toString() ?? '';
                            return date.compareTo(_dateKey(_selectedWeek)) >=
                                    0 &&
                                date.compareTo(
                                      _dateKey(
                                        _selectedWeek.add(
                                          const Duration(days: 6),
                                        ),
                                      ),
                                    ) <=
                                    0;
                          }).toList();

                          final currentAverage = _average(energyByDay.values);
                          final previousAverage = _average(
                            previousEnergyByDay.values,
                          );
                          final workMinutes = _minutesForArea(
                            trackedActivities,
                            'Work',
                          );
                          final commuteMinutes = _minutesForArea(
                            trackedActivities,
                            'Commute',
                          );
                          final sleepMinutes = _minutesForArea(
                            trackedActivities,
                            'Sleep',
                          );
                          final restMinutes = _minutesForArea(
                            trackedActivities,
                            'Rest',
                          );
                          final lifeMinutes = _minutesForArea(
                            trackedActivities,
                            'Life',
                          );
                          final workCount = _countForArea(
                            trackedActivities,
                            'Work',
                          );
                          final commuteCount = _countForArea(
                            trackedActivities,
                            'Commute',
                          );
                          final sleepCount = _countForArea(
                            trackedActivities,
                            'Sleep',
                          );
                          final restCount = _countForArea(
                            trackedActivities,
                            'Rest',
                          );
                          final lifeCount = _countForArea(
                            trackedActivities,
                            'Life',
                          );
                          final totalBreakdown =
                              workMinutes +
                              commuteMinutes +
                              sleepMinutes +
                              restMinutes +
                              lifeMinutes;
                          final topActivity = _topTrackedActivity(
                            trackedActivities,
                          );
                          final completedWithoutDuration = activities.where((
                            activity,
                          ) {
                            final data = activity.data();
                            final duration = data['durationMinutes'];
                            return data['completed'] == true &&
                                (duration is! num || duration <= 0);
                          }).length;
                          final unfinishedWithDuration = activities.where((
                            activity,
                          ) {
                            final data = activity.data();
                            final duration = data['durationMinutes'];
                            return data['completed'] != true &&
                                duration is num &&
                                duration > 0;
                          }).length;
                          final completedGoals = goals
                              .where((goal) => goal.data()['completed'] == true)
                              .length;
                          final bestDay = energyByDay.length > 1
                              ? _bestDay(energyByDay)
                              : null;
                          final anyData =
                              activities.isNotEmpty ||
                              energyByDay.isNotEmpty ||
                              goals.isNotEmpty;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!anyData) ...[
                                const _NotEnoughDataCard(),
                                const SizedBox(height: 18),
                              ],
                              const _SectionTitle(
                                title: 'Work–life time balance',
                                subtitle:
                                    'A split of completed activities with a duration.',
                              ),
                              const SizedBox(height: 12),
                              _WorkLifeBalanceCard(
                                workMinutes: workMinutes + commuteMinutes,
                                lifeMinutes:
                                    sleepMinutes + restMinutes + lifeMinutes,
                                topActivity: topActivity,
                                completedWithoutDuration:
                                    completedWithoutDuration,
                                unfinishedWithDuration: unfinishedWithDuration,
                              ),
                              const SizedBox(height: 24),
                              const _SectionTitle(
                                title: 'Time by activity type',
                                subtitle:
                                    'Completed activities with durations, grouped by category.',
                              ),
                              const SizedBox(height: 12),
                              _ActivityBreakdownCard(
                                workPercentage: _share(
                                  workMinutes,
                                  totalBreakdown,
                                ),
                                commutePercentage: _share(
                                  commuteMinutes,
                                  totalBreakdown,
                                ),
                                sleepPercentage: _share(
                                  sleepMinutes,
                                  totalBreakdown,
                                ),
                                restPercentage: _share(
                                  restMinutes,
                                  totalBreakdown,
                                ),
                                lifePercentage: _share(
                                  lifeMinutes,
                                  totalBreakdown,
                                ),
                                workMinutes: workMinutes,
                                commuteMinutes: commuteMinutes,
                                sleepMinutes: sleepMinutes,
                                restMinutes: restMinutes,
                                lifeMinutes: lifeMinutes,
                                totalMinutes: totalBreakdown,
                                workCount: workCount,
                                commuteCount: commuteCount,
                                sleepCount: sleepCount,
                                restCount: restCount,
                                lifeCount: lifeCount,
                              ),
                              const SizedBox(height: 24),
                              const _SectionTitle(
                                title: 'Energy trend',
                                subtitle: 'Your check-ins, day by day.',
                              ),
                              const SizedBox(height: 12),
                              _EnergyTrendCard(
                                weekStart: _selectedWeek,
                                dailyScores: energyByDay,
                              ),
                              const SizedBox(height: 12),
                              _WeeklySummaryCard(
                                averageEnergy: currentAverage,
                                previousAverage: previousAverage,
                                checkInCount: energyByDay.length,
                              ),
                              const SizedBox(height: 24),
                              const _SectionTitle(
                                title: 'Goals and activity',
                                subtitle:
                                    'Your completed goals and logged activity.',
                              ),
                              const SizedBox(height: 12),
                              _WeeklyProgressCard(
                                goalsCompleted: completedGoals,
                                goalsTotal: goals.length,
                                activitiesLogged: activities.length,
                              ),
                              if (bestDay != null) ...[
                                const SizedBox(height: 24),
                                _BestDayCard(day: bestDay),
                              ],
                              if (workdayCount == 0) ...[
                                const SizedBox(height: 14),
                                const _NotEnoughDataCard(
                                  message:
                                      'Set your usual workdays in your profile for routine comparisons.',
                                ),
                              ],
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
      final trackedActivities = _completedTimedActivities(activities);
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
        if (totalTrackedMinutes > 0)
          'Work–life split: Work $workShare% (${_formatMinutes(workMinutes)}), Life $lifeShare% (${_formatMinutes(lifeMinutes)})',
        if (topActivity != null)
          'Most tracked activity: ${topActivity.title} (${topActivity.category}) · ${_formatMinutes(topActivity.minutes)}',
        if (totalTrackedMinutes == 0)
          'No completed activity durations recorded this week',
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
    for (final doc in docs) {
      final rawScore = doc.data()['energyScore'];
      if (rawScore is num) result[doc.id] = rawScore.round().clamp(1, 10);
    }
    return result;
  }

  static double? _average(Iterable<int> values) {
    final scores = values.toList();
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
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

  static double _share(int value, int total) =>
      total == 0 ? 0 : value / total * 100;

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

  static List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _completedTimedActivities(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
  ) => activities
      .where((activity) {
        final data = activity.data();
        final duration = data['durationMinutes'];
        return data['completed'] == true && duration is num && duration > 0;
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

  static int _countForArea(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
    String area,
  ) => activities
      .where(
        (activity) =>
            _canonicalArea(activity.data()['category']?.toString()) == area,
      )
      .length;

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

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }
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

class _WeekSelector extends StatelessWidget {
  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _WeekSelector({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final isCurrentWeek = DateUtils.isSameDay(
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
      weekStart,
    );
    final localizations = MaterialLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '${localizations.formatMediumDate(weekStart)} – ${localizations.formatMediumDate(weekEnd)}${isCurrentWeek ? ' · This week' : ''}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next week',
            onPressed: isCurrentWeek ? null : onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _InsightsIntro extends StatelessWidget {
  const _InsightsIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.eucalyptus,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEKLY REFLECTION',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'How was your week, really?',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'See where your completed activity time went, alongside your energy and goals.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.45,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_outlined,
              color: AppColors.eucalyptusDark,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.fraunces(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.sub),
        ),
      ],
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final double? averageEnergy;
  final double? previousAverage;
  final int checkInCount;

  const _WeeklySummaryCard({
    required this.averageEnergy,
    required this.previousAverage,
    required this.checkInCount,
  });

  @override
  Widget build(BuildContext context) {
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
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
              value: '$checkInCount/7',
              label: 'Check-ins',
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

class _TimeAllocationCard extends StatelessWidget {
  final double workPercentage;
  final double commutePercentage;
  final double sleepPercentage;
  final double restPercentage;
  final double lifePercentage;

  const _TimeAllocationCard({
    required this.workPercentage,
    required this.commutePercentage,
    required this.sleepPercentage,
    required this.restPercentage,
    required this.lifePercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Row(
              children: [
                if (workPercentage > 0)
                  Expanded(
                    flex: (workPercentage * 10).round().clamp(1, 1000),
                    child: Container(height: 12, color: AppColors.clay),
                  ),
                if (commutePercentage > 0)
                  Expanded(
                    flex: (commutePercentage * 10).round().clamp(1, 1000),
                    child: Container(
                      height: 12,
                      color: AppColors.clay.withValues(alpha: 0.58),
                    ),
                  ),
                if (sleepPercentage > 0)
                  Expanded(
                    flex: (sleepPercentage * 10).round().clamp(1, 1000),
                    child: Container(height: 12, color: AppColors.pistachio),
                  ),
                if (restPercentage > 0)
                  Expanded(
                    flex: (restPercentage * 10).round().clamp(1, 1000),
                    child: Container(height: 12, color: AppColors.eucalyptus),
                  ),
                if (lifePercentage > 0)
                  Expanded(
                    flex: (lifePercentage * 10).round().clamp(1, 1000),
                    child: Container(
                      height: 12,
                      color: AppColors.eucalyptusDark,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 11,
            runSpacing: 7,
            children: [
              _LegendItem(
                color: AppColors.clay,
                label: 'Work',
                percentage: workPercentage,
              ),
              _LegendItem(
                color: AppColors.clay.withValues(alpha: 0.58),
                label: 'Commute',
                percentage: commutePercentage,
              ),
              _LegendItem(
                color: AppColors.pistachio,
                label: 'Sleep',
                percentage: sleepPercentage,
              ),
              _LegendItem(
                color: AppColors.eucalyptus,
                label: 'Rest',
                percentage: restPercentage,
              ),
              _LegendItem(
                color: AppColors.eucalyptusDark,
                label: 'Life',
                percentage: lifePercentage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double percentage;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label ${percentage.toStringAsFixed(0)}%',
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.sub),
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: AppColors.clayDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    height: 1.45,
                    color: AppColors.sub,
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

class _EnergyTrendCard extends StatelessWidget {
  final DateTime weekStart;
  final Map<String, int> dailyScores;

  const _EnergyTrendCard({required this.weekStart, required this.dailyScores});

  @override
  Widget build(BuildContext context) {
    final values = List<int?>.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final key = _insightsDateKey(date);
      return dailyScores[key];
    });
    final scoreCount = values.whereType<int>().length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: scoreCount < 2
          ? Column(
              children: [
                const Icon(Icons.show_chart, color: AppColors.clayDark),
                const SizedBox(height: 8),
                Text(
                  scoreCount == 0
                      ? 'No energy check-ins this week yet.'
                      : 'One check-in so far. Add another day to see a trend.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
                ),
              ],
            )
          : Column(
              children: [
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
                const SizedBox(height: 8),
                Text(
                  'Scores out of 10 · $scoreCount check-ins',
                  style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.sub),
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

class _WorkLifeBalanceCard extends StatelessWidget {
  const _WorkLifeBalanceCard({
    required this.workMinutes,
    required this.lifeMinutes,
    required this.topActivity,
    required this.completedWithoutDuration,
    required this.unfinishedWithDuration,
  });

  final int workMinutes;
  final int lifeMinutes;
  final _TopTrackedActivity? topActivity;
  final int completedWithoutDuration;
  final int unfinishedWithDuration;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = workMinutes + lifeMinutes;
    final workShare = totalMinutes == 0
        ? 0
        : (workMinutes * 100 / totalMinutes).round();
    final lifeShare = totalMinutes == 0 ? 0 : 100 - workShare;
    final workFlex = totalMinutes == 0
        ? 1
        : (workMinutes / totalMinutes * 1000).round().clamp(1, 1000).toInt();
    final lifeFlex = totalMinutes == 0
        ? 1
        : (lifeMinutes / totalMinutes * 1000).round().clamp(1, 1000).toInt();
    final difference = (workMinutes - lifeMinutes).abs();
    final balanceMessage = workMinutes == 0 || lifeMinutes == 0
        ? 'No completed ${workMinutes == 0 ? 'work' : 'life'} time was logged in the selected week’s activities.'
        : workMinutes == lifeMinutes
        ? 'Your tracked work and life time were evenly split.'
        : '${workMinutes > lifeMinutes ? 'Work' : 'Life'} took ${_InsightsScreenState._formatMinutes(difference)} more in your tracked activities.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.eucalyptus,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.balance,
                  size: 19,
                  color: AppColors.eucalyptusDark,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Work and life time split',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (totalMinutes == 0) ...[
            Text(
              'There is not enough completed activity time to compare yet.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Add a duration to an activity and mark it complete to count it as time spent.',
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.45,
                color: AppColors.sub,
              ),
            ),
          ] else ...[
            Text(
              balanceMessage,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _BalanceTimeValue(
                    label: 'Work',
                    minutes: workMinutes,
                    percentage: workShare,
                    color: AppColors.clay,
                  ),
                ),
                Container(width: 1, height: 44, color: AppColors.line),
                Expanded(
                  child: _BalanceTimeValue(
                    label: 'Life',
                    minutes: lifeMinutes,
                    percentage: lifeShare,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  if (workMinutes > 0)
                    Expanded(
                      flex: workFlex,
                      child: Container(height: 10, color: AppColors.clay),
                    ),
                  if (lifeMinutes > 0)
                    Expanded(
                      flex: lifeFlex,
                      child: Container(height: 10, color: AppColors.eucalyptus),
                    ),
                ],
              ),
            ),
            if (topActivity != null) ...[
              const SizedBox(height: 16),
              Text(
                'Largest time commitment',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${topActivity!.title} · ${topActivity!.category}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '${_InsightsScreenState._formatMinutes(topActivity!.minutes)} across ${topActivity!.entries} completed ${topActivity!.entries == 1 ? 'entry' : 'entries'}',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
              ),
            ],
          ],
          if (completedWithoutDuration > 0 || unfinishedWithDuration > 0) ...[
            const SizedBox(height: 12),
            Text(
              [
                if (completedWithoutDuration > 0)
                  '$completedWithoutDuration completed ${completedWithoutDuration == 1 ? 'activity has' : 'activities have'} no duration.',
                if (unfinishedWithDuration > 0)
                  '$unfinishedWithDuration unfinished ${unfinishedWithDuration == 1 ? 'activity is' : 'activities are'} excluded until marked complete.',
              ].join(' '),
              style: GoogleFonts.inter(
                fontSize: 10,
                height: 1.4,
                color: AppColors.sub,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Work includes commute; the other side includes Sleep, Rest, and Life. This compares completed activities with durations, not every hour in your day.',
            style: GoogleFonts.inter(
              fontSize: 10,
              height: 1.45,
              color: AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceTimeValue extends StatelessWidget {
  const _BalanceTimeValue({
    required this.label,
    required this.minutes,
    required this.percentage,
    required this.color,
  });

  final String label;
  final int minutes;
  final int percentage;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _InsightsScreenState._formatMinutes(minutes),
          style: GoogleFonts.fraunces(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        Text(
          '$percentage% of tracked time',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 9, color: AppColors.sub),
        ),
      ],
    ),
  );
}

class _ActivityBreakdownCard extends StatelessWidget {
  final int workMinutes;
  final int commuteMinutes;
  final int sleepMinutes;
  final int restMinutes;
  final int lifeMinutes;
  final int totalMinutes;
  final int workCount;
  final int commuteCount;
  final int sleepCount;
  final int restCount;
  final int lifeCount;
  final double workPercentage;
  final double commutePercentage;
  final double sleepPercentage;
  final double restPercentage;
  final double lifePercentage;

  const _ActivityBreakdownCard({
    required this.workMinutes,
    required this.commuteMinutes,
    required this.sleepMinutes,
    required this.restMinutes,
    required this.lifeMinutes,
    required this.totalMinutes,
    required this.workCount,
    required this.commuteCount,
    required this.sleepCount,
    required this.restCount,
    required this.lifeCount,
    required this.workPercentage,
    required this.commutePercentage,
    required this.sleepPercentage,
    required this.restPercentage,
    required this.lifePercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (totalMinutes > 0) ...[
          _TimeAllocationCard(
            workPercentage: workPercentage,
            commutePercentage: commutePercentage,
            sleepPercentage: sleepPercentage,
            restPercentage: restPercentage,
            lifePercentage: lifePercentage,
          ),
          const SizedBox(height: 10),
        ] else
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _NotEnoughDataCard(
              message:
                  'No completed activities with durations to break down yet. Add durations and mark activities complete to see time by type.',
            ),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 9,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 64,
                child: _BreakdownValue(
                  label: 'Work',
                  minutes: workMinutes,
                  activityCount: workCount,
                ),
              ),
              SizedBox(
                width: 64,
                child: _BreakdownValue(
                  label: 'Commute',
                  minutes: commuteMinutes,
                  activityCount: commuteCount,
                ),
              ),
              SizedBox(
                width: 64,
                child: _BreakdownValue(
                  label: 'Sleep',
                  minutes: sleepMinutes,
                  activityCount: sleepCount,
                ),
              ),
              SizedBox(
                width: 64,
                child: _BreakdownValue(
                  label: 'Rest',
                  minutes: restMinutes,
                  activityCount: restCount,
                ),
              ),
              SizedBox(
                width: 64,
                child: _BreakdownValue(
                  label: 'Life',
                  minutes: lifeMinutes,
                  activityCount: lifeCount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BreakdownValue extends StatelessWidget {
  final String label;
  final int minutes;
  final int activityCount;

  const _BreakdownValue({
    required this.label,
    required this.minutes,
    required this.activityCount,
  });

  @override
  Widget build(BuildContext context) {
    final duration = Duration(minutes: minutes);
    final value = activityCount == 0
        ? '0 activities'
        : minutes == 0
        ? 'Duration not set'
        : duration.inHours > 0
        ? '${duration.inHours}h ${duration.inMinutes.remainder(60)}m'
        : '${duration.inMinutes}m';
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.fraunces(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          activityCount == 0 ? label : '$label · $activityCount',
          style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.sub),
        ),
      ],
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  final int goalsCompleted;
  final int goalsTotal;
  final int activitiesLogged;

  const _WeeklyProgressCard({
    required this.goalsCompleted,
    required this.goalsTotal,
    required this.activitiesLogged,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goalsTotal == 0 ? 0.0 : goalsCompleted / goalsTotal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goalsTotal == 0
                      ? 'No goals scheduled this week'
                      : '$goalsCompleted of $goalsTotal goals completed',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '$activitiesLogged activities',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: AppColors.eucalyptusDark,
              backgroundColor: AppColors.line,
            ),
          ),
        ],
      ),
    );
  }
}

class _BestDayCard extends StatelessWidget {
  final String day;

  const _BestDayCard({required this.day});

  @override
  Widget build(BuildContext context) => _InsightCard(
    icon: Icons.wb_sunny_outlined,
    title: 'Your energy peaked on ${day.split(' · ').first}',
    description:
        'Your highest check-in this week was ${day.split(' · ').last}.',
  );
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
