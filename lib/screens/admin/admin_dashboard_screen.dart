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
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        elevation: 0,
        title: Text(
          'WorkLife admin',
          style: GoogleFonts.fraunces(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        actions: [
          if (_index == 0)
            IconButton(
              tooltip: 'Refresh counts',
              onPressed: _loading ? null : _loadCounts,
              icon: const Icon(Icons.refresh_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
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
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      children: [
        Text(
          'Database overview',
          style: GoogleFonts.fraunces(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A live count of Firestore user profiles and WorkLife records.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.sub),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 12),
        _CountCard(
          label: 'User profiles',
          value: counts['totalUsers'],
          icon: Icons.people_alt_outlined,
        ),
        const SizedBox(height: 12),
        _CountCard(
          label: 'Available records',
          value: counts['totalRecords'],
          icon: Icons.storage_outlined,
        ),
        const SizedBox(height: 24),
        Text(
          'Counts include activities, check-ins, goals, and schedule items. User profiles are Firestore documents and may not equal Firebase Authentication accounts.',
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.5,
            color: AppColors.sub,
          ),
        ),
      ],
    ),
  );
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final dynamic value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.pistachio,
          foregroundColor: AppColors.eucalyptusDark,
          child: Icon(icon),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        Text(
          value?.toString() ?? '—',
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    ),
  );
}
