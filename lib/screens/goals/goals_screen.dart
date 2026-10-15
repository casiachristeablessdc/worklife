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
import '../schedule/schedule_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        backgroundColor: AppColors.ivory,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Goals',
          style: GoogleFonts.fraunces(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Add a daily focus',
            onPressed: () => _showGoalDialog(context, user.uid),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().activeGoals(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: _GoalsError(),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = [...snapshot.data!.docs]
            ..sort((a, b) {
              final dateOrder = (a.data()['date']?.toString() ?? '').compareTo(
                b.data()['date']?.toString() ?? '',
              );
              if (dateOrder != 0) return dateOrder;
              return (a.data()['createdAt'] as Timestamp?)?.compareTo(
                    (b.data()['createdAt'] as Timestamp?) ?? Timestamp(0, 0),
                  ) ??
                  0;
            });

          final todayKey = _dateKey(DateTime.now());
          final todayGoals = goals
              .where((goal) => goal.data()['date']?.toString() == todayKey)
              .toList();
          final completedToday = todayGoals
              .where((goal) => goal.data()['completed'] == true)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.eucalyptus,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: AppColors.eucalyptusDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Today’s focus',
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            todayGoals.isEmpty
                                ? 'Choose what matters most today.'
                                : '$completedToday of ${todayGoals.length} complete',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Add a daily focus',
                      onPressed: () => _showGoalDialog(context, user.uid),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _GoalSection(title: 'Today', goals: todayGoals, userId: user.uid),
              const SizedBox(height: 20),
              _GoalSection(
                title: 'Coming up',
                goals: goals
                    .where(
                      (goal) =>
                          (goal.data()['date']?.toString() ?? '').compareTo(
                            todayKey,
                          ) >
                          0,
                    )
                    .toList(),
                userId: user.uid,
              ),
              if (goals.isEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        color: AppColors.clayDark,
                        size: 26,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start with one clear priority.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _showGoalDialog(context, user.uid),
                        icon: const Icon(Icons.add, size: 17),
                        label: const Text('Set a focus'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: _GoalsNavigationBar(
        onHomeTap: () => _replace(context, const HomeScreen()),
        onScheduleTap: () => _replace(context, const ScheduleScreen()),
        onInsightsTap: () => _replace(context, const InsightsScreen()),
        onProfileTap: () => _replace(context, const ProfileScreen()),
      ),
    );
  }

  static void _replace(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => screen));
  }

  static Future<void> _showGoalDialog(
    BuildContext context,
    String userId,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _GoalFormDialog(userId: userId),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Daily focus saved.')));
    }
  }
}

class _GoalSection extends StatelessWidget {
  final String title;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> goals;
  final String userId;

  const _GoalSection({
    required this.title,
    required this.goals,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.fraunces(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              for (final goal in goals)
                CheckboxListTile(
                  value: goal.data()['completed'] == true,
                  activeColor: AppColors.eucalyptusDark,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    goal.data()['title']?.toString() ?? 'Daily focus',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      decoration: goal.data()['completed'] == true
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    '${goal.data()['category']?.toString() ?? 'Personal day'} · ${_formatGoalDate(context, goal.data()['date'])}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.sub,
                    ),
                  ),
                  secondary: PopupMenuButton<String>(
                    tooltip: 'Goal options',
                    onSelected: (value) async {
                      if (value != 'delete') return;
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: AppColors.ivory,
                          title: const Text('Remove this focus?'),
                          content: const Text('This only removes this goal.'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      try {
                        await FirestoreService().deleteGoal(
                          userId: userId,
                          goalId: goal.id,
                        );
                      } catch (error, stackTrace) {
                        debugPrint('Goal delete failed: $error\n$stackTrace');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not remove this focus.'),
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                  onChanged: (value) async {
                    if (value == null) return;
                    try {
                      await FirestoreService().updateGoalCompletion(
                        userId: userId,
                        goalId: goal.id,
                        completed: value,
                      );
                    } catch (error, stackTrace) {
                      debugPrint('Goal update failed: $error\n$stackTrace');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not update this focus.'),
                          ),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalFormDialog extends StatefulWidget {
  final String userId;

  const _GoalFormDialog({required this.userId});

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  static const _dayTypes = [
    'Workday',
    'Family day',
    'Personal day',
    'Wellness day',
  ];

  final _controller = TextEditingController();
  String _dayType = 'Personal day';
  bool _tomorrow = false;
  bool _saving = false;
  String? _error;
  String? _scheduleEventId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_scheduleEventId == null) {
      setState(() => _error = 'Link this focus to a scheduled activity first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final date = DateTime.now().add(Duration(days: _tomorrow ? 1 : 0));
    final title = _controller.text.trim().isEmpty
        ? 'Focus for $_dayType'
        : _controller.text.trim();
    try {
      final scheduledEvents = await FirestoreService()
          .scheduleForDate(widget.userId, date)
          .first;
      if (!scheduledEvents.docs.any(
        (event) => event.id == _scheduleEventId,
      )) {
        if (mounted) {
          setState(() {
            _error = 'Choose an activity that is still on this schedule.';
            _scheduleEventId = null;
            _saving = false;
          });
        }
        return;
      }
      await FirestoreService().createGoal(
        userId: widget.userId,
        title: title,
        date: DateTime(date.year, date.month, date.day),
        scheduleEventId: _scheduleEventId!,
        category: _dayType,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Goal creation failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Could not save this goal. Check your connection and retry.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text(
          'Choose the kind of day',
          style: GoogleFonts.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in _dayTypes)
                    ChoiceChip(
                      label: Text(type),
                      selected: _dayType == type,
                      onSelected: _saving
                          ? null
                          : (selected) {
                              if (selected) setState(() => _dayType = type);
                            },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Specific priority (optional)',
                  hintText: 'e.g. Finish the report by lunch',
                  helperText: 'Leave blank to use “Focus for $_dayType”.',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Today')),
                  ButtonSegment(value: true, label: Text('Tomorrow')),
                ],
                selected: {_tomorrow},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                        _tomorrow = selection.first;
                        _scheduleEventId = null;
                        _error = null;
                      }),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService().scheduleForDate(
                  widget.userId,
                  DateTime.now().add(Duration(days: _tomorrow ? 1 : 0)),
                ),
                builder: (context, snapshot) {
                  final events = snapshot.data?.docs ?? [];
                  final safeEventId = events.any(
                    (event) => event.id == _scheduleEventId,
                  )
                      ? _scheduleEventId
                      : null;
                  return DropdownButtonFormField<String>(
                    key: ValueKey('goal-schedule-anchor-$_scheduleEventId'),
                    initialValue: safeEventId,
                    validator: (value) => value == null
                        ? 'Choose a scheduled activity for this focus.'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Schedule anchor',
                      helperText: snapshot.hasError
                          ? 'Schedule unavailable'
                          : events.isEmpty
                          ? 'Add a time block to this day first.'
                          : 'Choose what this focus belongs to.',
                    ),
                    items: events.map((event) {
                      final data = event.data();
                      final start = data['startMinutes'] is num
                          ? (data['startMinutes'] as num).round()
                          : 0;
                      final hour24 = (start ~/ 60) % 24;
                      final minute = start % 60;
                      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
                      final time = '$hour12:${minute.toString().padLeft(2, '0')} '
                          '${hour24 < 12 ? 'AM' : 'PM'}';
                      return DropdownMenuItem<String>(
                        value: event.id,
                        child: Text(
                          '$time · ${data['title']?.toString() ?? 'Activity'}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _saving || snapshot.hasError
                        ? null
                        : (value) => setState(() {
                            _scheduleEventId = value;
                            _error = null;
                          }),
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save focus'),
          ),
        ],
      ),
    );
  }
}

class _GoalsNavigationBar extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onScheduleTap;
  final VoidCallback onInsightsTap;
  final VoidCallback onProfileTap;

  const _GoalsNavigationBar({
    required this.onHomeTap,
    required this.onScheduleTap,
    required this.onInsightsTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: AppColors.ivory,
      selectedIndex: 2,
      indicatorColor: AppColors.eucalyptus,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          label: 'Schedule',
        ),
        NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Goals'),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined),
          label: 'Insights',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            onHomeTap();
          case 1:
            onScheduleTap();
          case 3:
            onInsightsTap();
          case 4:
            onProfileTap();
        }
      },
    );
  }
}

class _GoalsError extends StatelessWidget {
  const _GoalsError();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.line),
    ),
    child: Text(
      'Goals could not be loaded. Check your connection and try again.',
      style: GoogleFonts.inter(fontSize: 12, color: AppColors.sub),
    ),
  );
}

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatGoalDate(BuildContext context, dynamic value) {
  if (value is String) {
    final date = DateTime.tryParse(value);
    if (date != null) {
      return MaterialLocalizations.of(context).formatMediumDate(date);
    }
    return value;
  }
  return '';
}
