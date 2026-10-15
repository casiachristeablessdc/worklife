import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';
import '../landing/landing_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AdminService();
  Map<String, dynamic> _counts = const {};
  String? _error;
  bool _loading = true;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.loadDashboard();
      if (!mounted) return;
      setState(() {
        _counts = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = adminServiceErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LandingScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to log out: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminOverview(
        counts: _counts,
        loading: _loading,
        error: _error,
        refresh: _loadCounts,
      ),
      const AdminUsersScreen(),
    ];
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (value == 2) {
            _logout();
          } else {
            setState(() => _index = value);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(icon: Icon(Icons.logout), label: 'Logout'),
        ],
      ),
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({
    required this.counts,
    required this.loading,
    required this.error,
    required this.refresh,
  });
  final Map<String, dynamic> counts;
  final bool loading;
  final String? error;
  final Future<void> Function() refresh;

  @override
  Widget build(BuildContext context) {
    final rawRecords = counts['recordsByCollection'];
    final records = rawRecords is Map ? rawRecords : const <String, dynamic>{};
    const categories = [
      ('activities', 'Activities', Icons.auto_awesome_outlined),
      ('checkIns', 'Check-ins', Icons.bolt_outlined),
      ('goals', 'Goals', Icons.flag_outlined),
      ('schedule', 'Schedule', Icons.calendar_month_outlined),
    ];
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(15, 18, 15, 30),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ADMINISTRATION',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.clayDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back',
                      style: GoogleFonts.fraunces(
                        fontSize: 29,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.pistachio,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.eucalyptusDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Admin\naccess',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.eucalyptusDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Here’s a quick look at your WorkLife community and workspace.',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: 19),
          if (error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.peach,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(error!),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: loading ? null : refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 6),
          _CountCard(
            label: 'Total users',
            value: counts['totalUsers'],
            detail: 'Firestore profiles',
            icon: Icons.groups_2_outlined,
          ),
          const SizedBox(height: 9),
          _CountCard(
            label: 'Stored records',
            value: counts['totalRecords'],
            detail: 'Across the four WorkLife record types',
            icon: Icons.storage_outlined,
            iconColor: AppColors.clayDark,
            iconBackground: AppColors.peach,
          ),
          const SizedBox(height: 22),
          Text(
            'Records by type',
            style: GoogleFonts.fraunces(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final (key, label, icon) in categories)
                  SizedBox(
                    width: (constraints.maxWidth - 9) / 2,
                    child: _RecordCountCard(
                      label: label,
                      value: records[key] ?? 0,
                      icon: icon,
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

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    this.iconColor = AppColors.eucalyptusDark,
    this.iconBackground = AppColors.pistachio,
  });
  final String label;
  final dynamic value;
  final String detail;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.sub),
              ),
              Text(
                value?.toString() ?? '—',
                style: GoogleFonts.fraunces(
                  fontSize: 28,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Text(
                detail,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RecordCountCard extends StatelessWidget {
  const _RecordCountCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final dynamic value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.eucalyptusDark),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: GoogleFonts.fraunces(
            fontSize: 24,
            height: 1.05,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.sub),
        ),
      ],
    ),
  );
}
