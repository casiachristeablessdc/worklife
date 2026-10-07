import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../profile/profile_screen.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

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

        return Scaffold(
          backgroundColor: AppColors.ivory,
          appBar: AppBar(
            backgroundColor: AppColors.ivory,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 20,
            title: Text(
              'Schedule',
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
                Text(
                  'Your usual work rhythm',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 22),
                _WorkSummaryCard(
                  workStartTime: workStartTime,
                  workEndTime: workEndTime,
                  workdays: workdays,
                  commuteMinutes: commuteMinutes,
                ),
                const SizedBox(height: 28),
                Text(
                  'This week',
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your regular workdays at a glance.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 14),
                _WeekDaysCard(
                  workdays: workdays,
                ),
                const SizedBox(height: 28),
                Text(
                  'Daily flow',
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A simple structure for your usual workday.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 14),
                _DailyFlowCard(
                  workStartTime: workStartTime,
                  workEndTime: workEndTime,
                  commuteMinutes: commuteMinutes,
                ),
              ],
            ),
          ),
          bottomNavigationBar: const _ScheduleNavigationBar(),
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
}

class _WorkSummaryCard extends StatelessWidget {
  final String workStartTime;
  final String workEndTime;
  final List<String> workdays;
  final int commuteMinutes;

  const _WorkSummaryCard({
    required this.workStartTime,
    required this.workEndTime,
    required this.workdays,
    required this.commuteMinutes,
  });

  String _formatCommute() {
    if (commuteMinutes >= 60) {
      final hours = commuteMinutes ~/ 60;
      final remaining = commuteMinutes % 60;

      if (remaining == 0) {
        return '${hours}h';
      }

      return '${hours}h ${remaining}m';
    }

    return '${commuteMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.eucalyptus,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WORKDAY',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.eucalyptusDark,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.login_outlined,
                  label: 'Start',
                  value: workStartTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.logout_outlined,
                  label: 'End',
                  value: workEndTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Workdays',
                  value: workdays.isEmpty
                      ? 'Not set'
                      : '${workdays.length} days',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.directions_car_outlined,
                  label: 'Commute',
                  value: _formatCommute(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: AppColors.eucalyptusDark,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
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

class _WeekDaysCard extends StatelessWidget {
  final List<String> workdays;

  const _WeekDaysCard({
    required this.workdays,
  });

  static const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _shortDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'M';
      case 'tuesday':
        return 'T';
      case 'wednesday':
        return 'W';
      case 'thursday':
        return 'T';
      case 'friday':
        return 'F';
      case 'saturday':
        return 'S';
      case 'sunday':
        return 'S';
      default:
        return '?';
    }
  }

  bool _isWorkday(String day) {
    return workdays.any(
      (workday) => workday.toLowerCase() == day.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isWorkday = _isWorkday(day);

          return Column(
            children: [
              Text(
                _shortDay(day),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isWorkday
                      ? AppColors.clay
                      : AppColors.line.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  isWorkday
                      ? Icons.check_rounded
                      : Icons.remove_rounded,
                  size: 16,
                  color: isWorkday
                      ? Colors.white
                      : AppColors.sub,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DailyFlowCard extends StatelessWidget {
  final String workStartTime;
  final String workEndTime;
  final int commuteMinutes;

  const _DailyFlowCard({
    required this.workStartTime,
    required this.workEndTime,
    required this.commuteMinutes,
  });

  String _commuteLabel() {
    if (commuteMinutes >= 60) {
      final hours = commuteMinutes ~/ 60;
      final remaining = commuteMinutes % 60;

      if (remaining == 0) {
        return '${hours}h commute';
      }

      return '${hours}h ${remaining}m commute';
    }

    return '$commuteMinutes min commute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Column(
        children: [
          _FlowItem(
            icon: Icons.directions_car_outlined,
            title: 'Commute',
            subtitle: _commuteLabel(),
          ),
          const _FlowDivider(),
          _FlowItem(
            icon: Icons.work_outline,
            title: 'Work',
            subtitle: '$workStartTime – $workEndTime',
          ),
          const _FlowDivider(),
          const _FlowItem(
            icon: Icons.restaurant_outlined,
            title: 'Lunch',
            subtitle: '12:00 PM',
          ),
          const _FlowDivider(),
          const _FlowItem(
            icon: Icons.self_improvement_outlined,
            title: 'Personal time',
            subtitle: 'Make room for what matters',
          ),
        ],
      ),
    );
  }
}

class _FlowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FlowItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: AppColors.clayDark,
            ),
          ),
          const SizedBox(width: 13),
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

class _FlowDivider extends StatelessWidget {
  const _FlowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 68,
      endIndent: 17,
      color: AppColors.line,
    );
  }
}

class _ScheduleNavigationBar extends StatelessWidget {
  const _ScheduleNavigationBar();

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: AppColors.ivory,
      elevation: 0,
      selectedIndex: 1,
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
        } else if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const InsightsScreen(),
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