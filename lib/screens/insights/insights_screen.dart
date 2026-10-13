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
                          final workMinutes = _minutesFor(activities, {'work'});
                          final healthMinutes = _minutesFor(activities, {
                            'health',
                          });
                          final personalMinutes = _minutesFor(activities, {
                            'personal',
                            'leisure',
                            'learning',
                            'other',
                          });
                          final workCount = _countFor(activities, {'work'});
                          final healthCount = _countFor(activities, {'health'});
                          final personalCount = _countFor(activities, {
                            'personal',
                            'leisure',
                            'learning',
                            'other',
                          });
                          final totalBreakdown =
                              workMinutes + healthMinutes + personalMinutes;
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
                                title: 'Activity breakdown',
                                subtitle:
                                    'Based on durations you logged this week.',
                              ),
                              const SizedBox(height: 12),
                              _ActivityBreakdownCard(
                                workPercentage: totalBreakdown == 0
                                    ? 0
                                    : workMinutes / totalBreakdown * 100,
                                healthPercentage: totalBreakdown == 0
                                    ? 0
                                    : healthMinutes / totalBreakdown * 100,
                                personalPercentage: totalBreakdown == 0
                                    ? 0
                                    : personalMinutes / totalBreakdown * 100,
                                workMinutes: workMinutes,
                                healthMinutes: healthMinutes,
                                personalMinutes: personalMinutes,
                                totalMinutes: totalBreakdown,
                                workCount: workCount,
                                healthCount: healthCount,
                                personalCount: personalCount,
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
      final activityCount = activitySnapshot.docs.length;
      final averageText = average == null
          ? 'No energy check-ins'
          : 'Average energy ${average.toStringAsFixed(1)}/10';
      final summary = [
        'WorkLife weekly summary',
        '${_formatDate(weekStart)} – ${_formatDate(end)}',
        averageText,
        '$activityCount activities logged',
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

  static int _minutesFor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
    Set<String> categories,
  ) => activities
      .where(
        (activity) => categories.contains(
          activity.data()['category']?.toString().toLowerCase(),
        ),
      )
      .fold<int>(0, (total, activity) {
        final duration = activity.data()['durationMinutes'];
        return total + (duration is num ? duration.round() : 0);
      });

  static int _countFor(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> activities,
    Set<String> categories,
  ) => activities
      .where(
        (activity) => categories.contains(
          activity.data()['category']?.toString().toLowerCase(),
        ),
      )
      .length;

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
                  'Look back at your energy, completed goals, and time you chose to track.',
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
  final double healthPercentage;
  final double personalPercentage;

  const _TimeAllocationCard({
    required this.workPercentage,
    required this.healthPercentage,
    required this.personalPercentage,
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
                if (healthPercentage > 0)
                  Expanded(
                    flex: (healthPercentage * 10).round().clamp(1, 1000),
                    child: Container(height: 12, color: AppColors.eucalyptus),
                  ),
                if (personalPercentage > 0)
                  Expanded(
                    flex: (personalPercentage * 10).round().clamp(1, 1000),
                    child: Container(height: 12, color: AppColors.peach),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LegendItem(
                  color: AppColors.clay,
                  label: 'Work',
                  percentage: workPercentage,
                ),
              ),
              Expanded(
                child: _LegendItem(
                  color: AppColors.eucalyptus,
                  label: 'Health',
                  percentage: healthPercentage,
                ),
              ),
              Expanded(
                child: _LegendItem(
                  color: AppColors.peach,
                  label: 'Personal',
                  percentage: personalPercentage,
                ),
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

class _ActivityBreakdownCard extends StatelessWidget {
  final int workMinutes;
  final int healthMinutes;
  final int personalMinutes;
  final int totalMinutes;
  final int workCount;
  final int healthCount;
  final int personalCount;
  final double workPercentage;
  final double healthPercentage;
  final double personalPercentage;

  const _ActivityBreakdownCard({
    required this.workMinutes,
    required this.healthMinutes,
    required this.personalMinutes,
    required this.totalMinutes,
    required this.workCount,
    required this.healthCount,
    required this.personalCount,
    required this.workPercentage,
    required this.healthPercentage,
    required this.personalPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (totalMinutes > 0) ...[
          _TimeAllocationCard(
            workPercentage: workPercentage,
            healthPercentage: healthPercentage,
            personalPercentage: personalPercentage,
          ),
          const SizedBox(height: 10),
        ] else
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _NotEnoughDataCard(
              message:
                  'Activities were logged, but no durations were entered. Counts are shown below; add durations to compare time.',
            ),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BreakdownValue(
                  label: 'Work',
                  minutes: workMinutes,
                  activityCount: workCount,
                ),
              ),
              Expanded(
                child: _BreakdownValue(
                  label: 'Health',
                  minutes: healthMinutes,
                  activityCount: healthCount,
                ),
              ),
              Expanded(
                child: _BreakdownValue(
                  label: 'Personal',
                  minutes: personalMinutes,
                  activityCount: personalCount,
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
