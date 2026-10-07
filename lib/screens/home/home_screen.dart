import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

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

    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'there';

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
              ),
              const SizedBox(height: 28),
              const _TodayCard(),
              const SizedBox(height: 28),
              const _SectionTitle(
                title: 'Today',
                subtitle: 'A simple view of where your time goes.',
              ),
              const SizedBox(height: 14),
              const _TimeOverview(),
              const SizedBox(height: 28),
              const _SectionTitle(
                title: 'Your schedule',
                subtitle: 'What your day looks like.',
              ),
              const SizedBox(height: 14),
              const _ScheduleCard(),
              const SizedBox(height: 28),
              const _SectionTitle(
                title: 'Side quest',
                subtitle: 'Something worth making time for.',
              ),
              const SizedBox(height: 14),
              const _SideQuestCard(),
              const SizedBox(height: 28),
              const _SectionTitle(
                title: 'This week',
                subtitle: 'Your time, at a glance.',
              ),
              const SizedBox(height: 14),
              const _WeeklyOverview(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _HomeNavigationBar(),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String name;

  const _HomeHeader({
    required this.greeting,
    required this.name,
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
            ],
          ),
        ),
        Container(
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
  const _TimeOverview();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimeTile(
            icon: Icons.work_outline,
            label: 'Work',
            value: '8h',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeTile(
            icon: Icons.directions_car_outlined,
            label: 'Commute',
            value: '1h',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
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
  const _ScheduleCard();

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
            time: '9:00 AM',
            title: 'Work starts',
            subtitle: 'Your usual workday',
            icon: Icons.work_outline,
            isLast: false,
          ),
          _ScheduleItem(
            time: '12:00 PM',
            title: 'Lunch',
            subtitle: 'Take a proper break',
            icon: Icons.restaurant_outlined,
            isLast: false,
          ),
          _ScheduleItem(
            time: '6:00 PM',
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
  const _SideQuestCard();

  @override
  Widget build(BuildContext context) {
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
                  'Make time for something you enjoy.',
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
  const _WeeklyOverview();

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
          Row(
            children: [
              Expanded(
                child: _WeeklyStat(
                  value: '40h',
                  label: 'Work',
                ),
              ),
              Expanded(
                child: _WeeklyStat(
                  value: '5h',
                  label: 'Commute',
                ),
              ),
              Expanded(
                child: _WeeklyStat(
                  value: '—',
                  label: 'Personal',
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
                  flex: 40,
                  child: Container(
                    height: 8,
                    color: AppColors.clay,
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 8,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
                Expanded(
                  flex: 15,
                  child: Container(
                    height: 8,
                    color: AppColors.pistachio,
                  ),
                ),
                Expanded(
                  flex: 40,
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
  const _HomeNavigationBar();

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
    );
  }
}