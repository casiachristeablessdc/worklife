import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../insights/insights_screen.dart';
import '../profile/profile_screen.dart';
import '../schedule/schedule_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 18) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

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

        final name = _readString(
          data['name'],
          fallback: user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'there',
        );

        final jobTitle = _readString(
          data['jobTitle'],
          fallback: 'Employee',
        );

        final company = _readString(
          data['company'],
          fallback: '',
        );

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

        final weeklyWorkHours = workHours * workdays.length;
        final weeklyCommuteHours =
            (commuteMinutes * workdays.length) / 60;

        return Scaffold(
          backgroundColor: AppColors.ivory,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(
                    greeting: _greeting(),
                    name: name,
                    jobTitle: jobTitle,
                    company: company,
                    onProfileTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const _TodayCard(),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: 'Today',
                    subtitle: 'A simple view of where your time goes.',
                  ),
                  const SizedBox(height: 14),
                  _TimeOverview(
                    workHours: workHours,
                    commuteMinutes: commuteMinutes,
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: 'Your schedule',
                    subtitle: 'Based on your usual workday.',
                  ),
                  const SizedBox(height: 14),
                  _ScheduleCard(
                    workStartTime: workStartTime,
                    workEndTime: workEndTime,
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: 'Side quest',
                    subtitle: 'Something worth making time for.',
                  ),
                  const SizedBox(height: 14),
                  _SideQuestCard(
                    sideQuests: _readStringList(data['sideQuests']),
                    customSideQuests:
                        _readStringList(data['customSideQuests']),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: 'This week',
                    subtitle: 'Your planned work-life structure.',
                  ),
                  const SizedBox(height: 14),
                  _WeeklyOverview(
                    workHours: weeklyWorkHours,
                    commuteHours: weeklyCommuteHours,
                    workdayCount: workdays.length,
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _HomeNavigationBar(
            onScheduleTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ScheduleScreen(),
                ),
              );
            },
            onProfileTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
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
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String jobTitle;
  final String company;
  final VoidCallback onProfileTap;

  const _HomeHeader({
    required this.greeting,
    required this.name,
    required this.jobTitle,
    required this.company,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: GoogleFonts.fraunces(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                company.isEmpty ? jobTitle : '$jobTitle · $company',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.sub,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.eucalyptus,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.eucalyptusDark,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard();

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
                  'TODAY',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make space for life.',
                  style: GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Track your day without letting the day track you.',
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
              Icons.eco_outlined,
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

class _TimeOverview extends StatelessWidget {
  final double workHours;
  final int commuteMinutes;

  const _TimeOverview({
    required this.workHours,
    required this.commuteMinutes,
  });

  String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()}h';
    }

    return '${hours.toStringAsFixed(1)}h';
  }

  String _formatCommute(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remaining = minutes % 60;

      if (remaining == 0) {
        return '${hours}h';
      }

      return '${hours}h ${remaining}m';
    }

    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeTile(
            icon: Icons.work_outline,
            label: 'Work',
            value: _formatHours(workHours),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeTile(
            icon: Icons.directions_car_outlined,
            label: 'Commute',
            value: _formatCommute(commuteMinutes),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _TimeTile(
            icon: Icons.bed_outlined,
            label: 'Sleep',
            value: '—',
          ),
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TimeTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.clayDark,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              color: AppColors.sub,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String workStartTime;
  final String workEndTime;

  const _ScheduleCard({
    required this.workStartTime,
    required this.workEndTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Column(
        children: [
          _ScheduleItem(
            time: workStartTime,
            title: 'Work starts',
            subtitle: 'Your usual workday',
            icon: Icons.work_outline,
            isLast: false,
          ),
          const _ScheduleItem(
            time: '12:00 PM',
            title: 'Lunch',
            subtitle: 'Take a proper break',
            icon: Icons.restaurant_outlined,
            isLast: false,
          ),
          _ScheduleItem(
            time: workEndTime,
            title: 'Work ends',
            subtitle: 'Time to transition out of work',
            icon: Icons.logout_outlined,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ScheduleItem extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLast;

  const _ScheduleItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 67,
            child: Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.sub,
              ),
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 16,
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
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
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

class _SideQuestCard extends StatelessWidget {
  final List<String> sideQuests;
  final List<String> customSideQuests;

  const _SideQuestCard({
    required this.sideQuests,
    required this.customSideQuests,
  });

  @override
  Widget build(BuildContext context) {
    final allSideQuests = [
      ...sideQuests,
      ...customSideQuests,
    ];

    final sideQuest = allSideQuests.isNotEmpty
        ? allSideQuests.first
        : 'Make time for something you enjoy.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 19,
              color: AppColors.clayDark,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY’S SIDE QUEST',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.clayDark,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  sideQuest,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.sub,
          ),
        ],
      ),
    );
  }
}

class _WeeklyOverview extends StatelessWidget {
  final double workHours;
  final double commuteHours;
  final int workdayCount;

  const _WeeklyOverview({
    required this.workHours,
    required this.commuteHours,
    required this.workdayCount,
  });

  String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()}h';
    }

    return '${hours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final totalTrackedHours = workHours + commuteHours;

    final workFlex = workHours.round().clamp(1, 100);
    final commuteFlex = commuteHours.round().clamp(1, 100);
    final remainingFlex =
        (168 - totalTrackedHours).round().clamp(1, 168);

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
          Row(
            children: [
              Expanded(
                child: _WeeklyStat(
                  value: _formatHours(workHours),
                  label: 'Work',
                ),
              ),
              Expanded(
                child: _WeeklyStat(
                  value: _formatHours(commuteHours),
                  label: 'Commute',
                ),
              ),
              Expanded(
                child: _WeeklyStat(
                  value: '$workdayCount days',
                  label: 'Workdays',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: workFlex,
                  child: Container(
                    height: 8,
                    color: AppColors.clay,
                  ),
                ),
                Expanded(
                  flex: commuteFlex,
                  child: Container(
                    height: 8,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
                Expanded(
                  flex: remainingFlex,
                  child: Container(
                    height: 8,
                    color: AppColors.line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Based on your usual $workdayCount day workweek. '
              'Your actual balance will become clearer as you track your days.',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                height: 1.4,
                color: AppColors.sub,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyStat extends StatelessWidget {
  final String value;
  final String label;

  const _WeeklyStat({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.fraunces(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.sub,
          ),
        ),
      ],
    );
  }
}

class _HomeNavigationBar extends StatelessWidget {
  final VoidCallback onScheduleTap;
  final VoidCallback onProfileTap;

  const _HomeNavigationBar({
    required this.onScheduleTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: AppColors.ivory,
      elevation: 0,
      selectedIndex: 0,
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
        if (index == 1) {
          onScheduleTap();
        } else if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const InsightsScreen(),
            ),
          );
        } else if (index == 3) {
          onProfileTap();
        }
      },
    );
  }
}