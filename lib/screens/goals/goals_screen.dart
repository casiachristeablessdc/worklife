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
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService().activeGoals(user.uid),
          builder: (context, snapshot) {
            final goals = [...?snapshot.data?.docs]
              ..sort((a, b) {
                final dateOrder = (a.data()['date']?.toString() ?? '')
                    .compareTo(b.data()['date']?.toString() ?? '');
                if (dateOrder != 0) return dateOrder;
                return (a.data()['createdAt'] as Timestamp?)?.compareTo(
                      (b.data()['createdAt'] as Timestamp?) ?? Timestamp(0, 0),
                    ) ??
                    0;
              });
            final today = DateUtils.dateOnly(DateTime.now());
            final weekStart = today.subtract(
              Duration(days: today.weekday - DateTime.monday),
            );
            final weekEnd = weekStart.add(const Duration(days: 6));
            final weeklyGoals = goals.where((goal) {
              final date = DateTime.tryParse(
                goal.data()['date']?.toString() ?? '',
              );
              return date != null &&
                  !date.isBefore(weekStart) &&
                  !date.isAfter(weekEnd);
            }).toList();
            final completedThisWeek = weeklyGoals
                .where((goal) => goal.data()['completed'] == true)
                .length;
            final hasError = snapshot.hasError;
            final isLoading = !snapshot.hasData && !hasError;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR INTENTIONS',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              color: AppColors.clayDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Goals',
                            style: GoogleFonts.fraunces(
                              fontSize: 25,
                              height: 1.15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Set small promises for the things that\nmatter to you.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              height: 1.4,
                              color: AppColors.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: FilledButton.icon(
                        onPressed: () => _showGoalDialog(context, user.uid),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          backgroundColor: AppColors.clay,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: AppColors.clay.withValues(alpha: 0.25),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New goal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _WeeklyProgressCard(
                  total: weeklyGoals.length,
                  completed: completedThisWeek,
                ),
                const SizedBox(height: 14),
                if (hasError)
                  const _GoalsError()
                else if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (goals.isEmpty)
                  _GoalsEmptyCard(
                    onAdd: () => _showGoalDialog(context, user.uid),
                  )
                else ...[
                  for (final goal in goals) ...[
                    _GoalCard(
                      goal: goal,
                      userId: user.uid,
                      onEdit: () =>
                          _showGoalDialog(context, user.uid, existing: goal),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 2),
                const _GoalReminderCard(),
              ],
            );
          },
        ),
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
    String userId, {
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _GoalFormDialog(userId: userId, existing: existing),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Goal saved.' : 'Goal updated.'),
        ),
      );
    }
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.total, required this.completed});

  final int total;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final encouragement = total == 0
        ? 'Choose one small promise to begin.'
        : completed == total
        ? 'You kept every promise you made this week.'
        : completed == 0
        ? 'Every week starts with one small step.'
        : 'You’re making steady progress. Keep going.';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.eucalyptus,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly progress',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.eucalyptusDark,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$completed of $total',
            style: GoogleFonts.fraunces(
              fontSize: 25,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          Text(
            'goal steps complete',
            style: GoogleFonts.inter(
              fontSize: 9,
              color: AppColors.eucalyptusDark,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.7),
              valueColor: const AlwaysStoppedAnimation(
                AppColors.eucalyptusDark,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            encouragement,
            style: GoogleFonts.inter(
              fontSize: 9,
              height: 1.3,
              color: AppColors.eucalyptusDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.userId,
    required this.onEdit,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> goal;
  final String userId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final data = goal.data();
    final title = data['title']?.toString() ?? 'Daily focus';
    final category = data['category']?.toString() ?? 'Personal day';
    final completed = data['completed'] == true;
    final scheduleEventId = data['scheduleEventId']?.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _goalCategorySurface(category),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _goalCategoryIcon(category),
              size: 19,
              color: _goalCategoryColor(category),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.toUpperCase()} · ${_goalDateLabel(context, data['date'])}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fraunces(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: completed ? 1 : 0,
                          minHeight: 3,
                          backgroundColor: AppColors.peach,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.eucalyptusDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      completed ? '1/1' : '0/1',
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _GoalActionButton(
                  completed: completed,
                  onPressed: () =>
                      _setGoalCompletion(context, completed: !completed),
                ),
                if (scheduleEventId != null && scheduleEventId.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _GoalScheduleAnchorLabel(
                    userId: userId,
                    date: _parseGoalDate(data['date']) ?? DateTime.now(),
                    scheduleEventId: scheduleEventId,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 2),
          Column(
            children: [
              IconButton(
                tooltip: 'Edit goal',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: AppColors.sub,
              ),
              PopupMenuButton<String>(
                tooltip: 'Goal options',
                padding: EdgeInsets.zero,
                iconSize: 17,
                onSelected: (value) {
                  if (value == 'delete') _deleteGoal(context);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Remove goal')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setGoalCompletion(
    BuildContext context, {
    required bool completed,
  }) async {
    try {
      await FirestoreService().updateGoalCompletion(
        userId: userId,
        goalId: goal.id,
        completed: completed,
      );
    } catch (error, stackTrace) {
      debugPrint('Daily focus update failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update daily focus.')),
        );
      }
    }
  }

  Future<void> _deleteGoal(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: const Text('Remove this goal?'),
        content: const Text('This only removes this goal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await FirestoreService().deleteGoal(userId: userId, goalId: goal.id);
    } catch (error, stackTrace) {
      debugPrint('Goal delete failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove this goal.')),
        );
      }
    }
  }
}

class _GoalActionButton extends StatelessWidget {
  const _GoalActionButton({required this.completed, required this.onPressed});

  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 27),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      backgroundColor: completed
          ? AppColors.pistachio
          : AppColors.eucalyptusDark,
      foregroundColor: completed ? AppColors.eucalyptusDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600),
    ),
    icon: Icon(completed ? Icons.check : Icons.arrow_forward, size: 12),
    label: Text(completed ? 'Complete' : 'Check-in'),
  );
}

class _GoalScheduleAnchorLabel extends StatelessWidget {
  const _GoalScheduleAnchorLabel({
    required this.userId,
    required this.date,
    required this.scheduleEventId,
  });

  final String userId;
  final DateTime date;
  final String scheduleEventId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService().scheduleForDate(userId, date),
        builder: (context, snapshot) {
          final events = snapshot.data?.docs ?? [];
          final linked = events.where((event) => event.id == scheduleEventId);
          if (linked.isEmpty) return const SizedBox.shrink();
          final title = linked.first.data()['title']?.toString() ?? 'Activity';
          return Text(
            'Linked to $title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 8, color: AppColors.sub),
          );
        },
      );
}

class _GoalsEmptyCard extends StatelessWidget {
  const _GoalsEmptyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      children: [
        const Icon(Icons.flag_outlined, color: AppColors.clayDark, size: 25),
        const SizedBox(height: 8),
        Text(
          'Start with one clear promise.',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Create a goal'),
        ),
      ],
    ),
  );
}

class _GoalReminderCard extends StatelessWidget {
  const _GoalReminderCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.peach,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb_outline,
          size: 18,
          color: AppColors.clayDark,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A GENTLE REMINDER',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.clayDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Goals should support your life, not become another source of pressure. Adjusting the plan still counts as progress.',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  height: 1.35,
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

class _GoalFormDialog extends StatefulWidget {
  final String userId;
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;

  const _GoalFormDialog({required this.userId, this.existing});

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
  DateTime _goalDate = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;
  String? _error;
  String? _scheduleEventId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    final data = existing.data();
    _controller.text = data['title']?.toString() ?? '';
    final category = data['category']?.toString();
    if (_dayTypes.contains(category)) _dayType = category!;
    _goalDate = _parseGoalDate(data['date']) ?? _goalDate;
    _scheduleEventId = data['scheduleEventId']?.toString();
  }

  DateTime get _targetDate => widget.existing == null
      ? DateUtils.dateOnly(
          DateTime.now().add(Duration(days: _tomorrow ? 1 : 0)),
        )
      : DateUtils.dateOnly(_goalDate);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickGoalDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(1900),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _goalDate = DateUtils.dateOnly(picked);
      _scheduleEventId = null;
      _error = null;
    });
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
    final date = _targetDate;
    final title = _controller.text.trim().isEmpty
        ? widget.existing?.data()['title']?.toString() ?? 'Focus for $_dayType'
        : _controller.text.trim();
    try {
      final scheduledEvents = await FirestoreService()
          .scheduleForDate(widget.userId, date)
          .first;
      if (!scheduledEvents.docs.any((event) => event.id == _scheduleEventId)) {
        if (mounted) {
          setState(() {
            _error = 'Choose an activity that is still on this schedule.';
            _scheduleEventId = null;
            _saving = false;
          });
        }
        return;
      }
      final service = FirestoreService();
      final existing = widget.existing;
      if (existing == null) {
        await service.createGoal(
          userId: widget.userId,
          title: title,
          date: date,
          scheduleEventId: _scheduleEventId!,
          category: _dayType,
        );
      } else {
        final data = existing.data();
        await service.updateGoal(
          userId: widget.userId,
          goalId: existing.id,
          title: title,
          date: date,
          scheduleEventId: _scheduleEventId!,
          category: _dayType,
          completed: data['completed'] == true,
          active: data['active'] != false,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Goal save failed: $error\n$stackTrace');
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
          widget.existing == null ? 'Create a goal' : 'Edit goal',
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
                  labelText: 'Goal name (optional)',
                  hintText: 'e.g. Finish the report by lunch',
                  helperText: 'Leave blank to use “Focus for $_dayType”.',
                ),
              ),
              const SizedBox(height: 12),
              if (widget.existing == null)
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
                )
              else
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickGoalDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(_targetDate),
                  ),
                ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService().scheduleForDate(
                  widget.userId,
                  _targetDate,
                ),
                builder: (context, snapshot) {
                  final events = snapshot.data?.docs ?? [];
                  final safeEventId =
                      events.any((event) => event.id == _scheduleEventId)
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
                      final time =
                          '$hour12:${minute.toString().padLeft(2, '0')} '
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
                : Text(widget.existing == null ? 'Save goal' : 'Save changes'),
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

DateTime? _parseGoalDate(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

String _goalDateLabel(BuildContext context, dynamic value) {
  final date = _parseGoalDate(value);
  if (date == null) return 'DATE UNSPECIFIED';
  final today = DateUtils.dateOnly(DateTime.now());
  final goalDate = DateUtils.dateOnly(date);
  if (DateUtils.isSameDay(goalDate, today)) return 'TODAY';
  if (DateUtils.isSameDay(goalDate, today.add(const Duration(days: 1)))) {
    return 'TOMORROW';
  }
  return MaterialLocalizations.of(
    context,
  ).formatMediumDate(goalDate).toUpperCase();
}

IconData _goalCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'workday':
      return Icons.work_outline;
    case 'family day':
      return Icons.groups_2_outlined;
    case 'wellness day':
      return Icons.spa_outlined;
    default:
      return Icons.favorite_border;
  }
}

Color _goalCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'workday':
      return AppColors.eucalyptusDark;
    case 'family day':
      return AppColors.clayDark;
    case 'wellness day':
      return const Color(0xFF657345);
    default:
      return const Color(0xFF9E625F);
  }
}

Color _goalCategorySurface(String category) {
  switch (category.toLowerCase()) {
    case 'workday':
      return AppColors.pistachio;
    case 'family day':
      return AppColors.peach;
    case 'wellness day':
      return const Color(0xFFE6EACD);
    default:
      return const Color(0xFFF4E3DF);
  }
}
