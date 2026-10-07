import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/schedule_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().userDocument(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final workStartTime = _readString(
          data['workStartTime'],
          fallback: '9:00 AM',
        );

        final workEndTime = _readString(
          data['workEndTime'],
          fallback: '6:00 PM',
        );

        final workdays = _readStringList(data['workdays']);

        final commuteMinutes = _readInt(
          data['commuteMinutes'],
          fallback: 60,
        );

        final workHours = _calculateWorkHours(
          workStartTime,
          workEndTime,
        );

        final workdayCount = workdays.isEmpty ? 5 : workdays.length;

        final weeklyWorkHours = workHours * workdayCount;
        final weeklyCommuteHours =
            (commuteMinutes * workdayCount) / 60;

        final weeklyWorkAndCommute =
            weeklyWorkHours + weeklyCommuteHours;

        final remainingHours =
            (168 - weeklyWorkAndCommute).clamp(0, 168).toDouble();

        final workPercentage =
            (weeklyWorkHours / 168 * 100).clamp(0, 100).toDouble();

        final commutePercentage =
            (weeklyCommuteHours / 168 * 100).clamp(0, 100).toDouble();

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
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InsightsIntro(
                  workdayCount: workdayCount,
                ),
                const SizedBox(height: 24),
                const _SectionTitle(
                  title: 'Your week at a glance',
                  subtitle: 'Based on the routine you set up.',
                ),
                const SizedBox(height: 14),
                _WeeklySummaryCard(
                  workHours: weeklyWorkHours,
                  commuteHours: weeklyCommuteHours,
                  remainingHours: remainingHours,
                ),
                const SizedBox(height: 28),
                const _SectionTitle(
                  title: 'Where your time goes',
                  subtitle: 'Your planned weekly time allocation.',
                ),
                const SizedBox(height: 14),
                _TimeAllocationCard(
                  workPercentage: workPercentage,
                  commutePercentage: commutePercentage,
                  remainingPercentage:
                      (100 - workPercentage - commutePercentage)
                          .clamp(0, 100)
                          .toDouble(),
                ),
                const SizedBox(height: 28),
                const _SectionTitle(
                  title: 'What stands out',
                  subtitle: 'A simple read of your current routine.',
                ),
                const SizedBox(height: 14),
                _InsightCard(
                  icon: Icons.work_outline,
                  title: 'Work takes the largest share',
                  description:
                      'Your usual schedule allocates '
                      '${_formatHours(weeklyWorkHours)} to work each week. '
                      'That is about ${workPercentage.toStringAsFixed(0)}% '
                      'of the full week.',
                ),
                const SizedBox(height: 10),
                _InsightCard(
                  icon: Icons.directions_car_outlined,
                  title: 'Your commute adds up',
                  description:
                      'Your usual commute accounts for about '
                      '${_formatHours(weeklyCommuteHours)} each week. '
                      'Tracking your actual days will show whether this '
                      'matches your real routine.',
                ),
                const SizedBox(height: 10),
                _InsightCard(
                  icon: Icons.self_improvement_outlined,
                  title: 'There is still time outside work',
                  description:
                      'You have approximately '
                      '${_formatHours(remainingHours)} outside your planned '
                      'work and commute time. This includes sleep, meals, '
                      'personal responsibilities, hobbies, and leisure.',
                ),
                const SizedBox(height: 28),
                _RealityCheckCard(
                  workHours: weeklyWorkHours,
                  commuteHours: weeklyCommuteHours,
                  workdayCount: workdayCount,
                ),
              ],
            ),
          ),
          bottomNavigationBar: const _InsightsNavigationBar(),
        );
      },
    );
  }

  static String _readString(
    dynamic value, {
    required String fallback,
  }) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

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

  static int _readInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return fallback;
  }

  static double _calculateWorkHours(
    String startTime,
    String endTime,
  ) {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);

    if (start == null || end == null) {
      return 8;
    }

    var difference = end - start;

    if (difference <= 0) {
      difference += 24;
    }

    return difference;
  }

  static double? _parseTime(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) {
      return null;
    }

    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();

    if (hour == null || minute == null) {
      return null;
    }

    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) {
      return null;
    }

    if (period == 'AM' && hour == 12) {
      hour = 0;
    } else if (period == 'PM' && hour != 12) {
      hour += 12;
    }

    return hour + (minute / 60);
  }

  static String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()}h';
    }

    return '${hours.toStringAsFixed(1)}h';
  }
}

class _InsightsIntro extends StatelessWidget {
  final int workdayCount;

  const _InsightsIntro({
    required this.workdayCount,
  });

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
                  'YOUR WEEK',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'See the bigger picture.',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Your current routine is based on '
                  '$workdayCount workdays. As you track more days, '
                  'these insights can become more personal.',
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

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

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
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: AppColors.sub,
          ),
        ),
      ],
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final double workHours;
  final double commuteHours;
  final double remainingHours;

  const _WeeklySummaryCard({
    required this.workHours,
    required this.commuteHours,
    required this.remainingHours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              icon: Icons.work_outline,
              value: _formatHours(workHours),
              label: 'Work',
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: AppColors.line,
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.directions_car_outlined,
              value: _formatHours(commuteHours),
              label: 'Commute',
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: AppColors.line,
          ),
          Expanded(
            child: _SummaryStat(
              icon: Icons.spa_outlined,
              value: _formatHours(remainingHours),
              label: 'Other time',
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()}h';
    }

    return '${hours.toStringAsFixed(1)}h';
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.clayDark,
        ),
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
          style: GoogleFonts.inter(
            fontSize: 9.5,
            color: AppColors.sub,
          ),
        ),
      ],
    );
  }
}

class _TimeAllocationCard extends StatelessWidget {
  final double workPercentage;
  final double commutePercentage;
  final double remainingPercentage;

  const _TimeAllocationCard({
    required this.workPercentage,
    required this.commutePercentage,
    required this.remainingPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
        ),
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
                    child: Container(
                      height: 12,
                      color: AppColors.clay,
                    ),
                  ),
                if (commutePercentage > 0)
                  Expanded(
                    flex:
                        (commutePercentage * 10).round().clamp(1, 1000),
                    child: Container(
                      height: 12,
                      color: AppColors.eucalyptusDark,
                    ),
                  ),
                if (remainingPercentage > 0)
                  Expanded(
                    flex:
                        (remainingPercentage * 10).round().clamp(1, 1000),
                    child: Container(
                      height: 12,
                      color: AppColors.line,
                    ),
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
                  color: AppColors.eucalyptusDark,
                  label: 'Commute',
                  percentage: commutePercentage,
                ),
              ),
              Expanded(
                child: _LegendItem(
                  color: AppColors.line,
                  label: 'Other',
                  percentage: remainingPercentage,
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
            style: GoogleFonts.inter(
              fontSize: 9.5,
              color: AppColors.sub,
            ),
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
        border: Border.all(
          color: AppColors.line,
        ),
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
            child: Icon(
              icon,
              size: 18,
              color: AppColors.clayDark,
            ),
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

class _RealityCheckCard extends StatelessWidget {
  final double workHours;
  final double commuteHours;
  final int workdayCount;

  const _RealityCheckCard({
    required this.workHours,
    required this.commuteHours,
    required this.workdayCount,
  });

  @override
  Widget build(BuildContext context) {
    final total = workHours + commuteHours;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.eucalyptus,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              size: 19,
              color: AppColors.eucalyptusDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reality check',
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Across your $workdayCount workdays, work and '
                  'commute currently account for '
                  '${_formatHours(total)} of your week. '
                  'Once you start tracking activities, WorkLife can '
                  'compare this plan with what actually happened.',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    height: 1.45,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()} hours';
    }

    return '${hours.toStringAsFixed(1)} hours';
  }
}

class _InsightsNavigationBar extends StatelessWidget {
  const _InsightsNavigationBar();

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: AppColors.ivory,
      elevation: 0,
      selectedIndex: 2,
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
            MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            ),
          );
        } else if (index == 1) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ScheduleScreen(),
            ),
          );
        } else if (index == 3) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            ),
          );
        }
      },
    );
  }
}