import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../insights/insights_screen.dart';
import '../schedule/schedule_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

        final name = _readString(
          data['name'],
          fallback: 'Your name',
        );

        final email = _readString(
          data['email'],
          fallback: user.email ?? '',
        );

        final jobTitle = _readString(
          data['jobTitle'],
          fallback: 'Job title not set',
        );

        final company = _readString(
          data['company'],
          fallback: 'Company not set',
        );

        final commuteMinutes = _readInt(
          data['commuteMinutes'],
          fallback: 0,
        );

        return Scaffold(
          backgroundColor: AppColors.ivory,
          appBar: AppBar(
            backgroundColor: AppColors.ivory,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 20,
            title: Text(
              'Profile',
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
                _ProfileHeader(
                  name: name,
                  jobTitle: jobTitle,
                  company: company,
                ),
                const SizedBox(height: 28),
                Text(
                  'Work profile',
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 14),
                _ProfileInfoCard(
                  children: [
                    _ProfileInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Name',
                      value: name,
                    ),
                    const _ProfileDivider(),
                    _ProfileInfoRow(
                      icon: Icons.work_outline,
                      label: 'Job title',
                      value: jobTitle,
                    ),
                    const _ProfileDivider(),
                    _ProfileInfoRow(
                      icon: Icons.business_outlined,
                      label: 'Company',
                      value: company,
                    ),
                    const _ProfileDivider(),
                    _ProfileInfoRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Your routine',
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 14),
                _ProfileInfoCard(
                  children: [
                    _ProfileInfoRow(
                      icon: Icons.directions_car_outlined,
                      label: 'Daily commute',
                      value: commuteMinutes == 0
                          ? 'Not set'
                          : '$commuteMinutes minutes',
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottomNavigationBar: const _ProfileNavigationBar(),
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

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String jobTitle;
  final String company;

  const _ProfileHeader({
    required this.name,
    required this.jobTitle,
    required this.company,
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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.fraunces(
                fontSize: 25,
                fontWeight: FontWeight.w600,
                color: AppColors.eucalyptusDark,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fraunces(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  jobTitle,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  company,
                  overflow: TextOverflow.ellipsis,
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

class _ProfileInfoCard extends StatelessWidget {
  final List<Widget> children;

  const _ProfileInfoCard({
    required this.children,
  });

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
        children: children,
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
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
        ],
      ),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 67,
      endIndent: 16,
      color: AppColors.line,
    );
  }
}

class _ProfileNavigationBar extends StatelessWidget {
  const _ProfileNavigationBar();

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
        } else if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const InsightsScreen(),
            ),
          );
        } else if (index == 3) {
          return;
        }
      },
    );
  }
}