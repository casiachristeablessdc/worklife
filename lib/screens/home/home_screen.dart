import 'dart:math';

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
import '../../models/activity_model.dart';
import '../goals/goals_screen.dart';
import '../../widgets/balance_snapshot_card.dart';

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

        final workStartTime = _readString(
          data['workStartTime'],
          fallback: '9:00 AM',
        );

        final workEndTime = _readString(
          data['workEndTime'],
          fallback: '6:00 PM',
        );

        final workdays = _readStringList(data['workdays']);
        final jobTitle = _readString(data['jobTitle'], fallback: 'Work');
        final isUsualWorkday = workdays.any(
          (day) => day.toLowerCase().startsWith(_weekdayKey(DateTime.now())),
        );

        final commuteMinutes = _readInt(data['commuteMinutes'], fallback: 60);
        final sleepHours = data['sleepHours'] is num
            ? (data['sleepHours'] as num).toDouble().clamp(0, 12).toDouble()
            : null;
        final restHours = data['restHours'] is num
            ? (data['restHours'] as num).toDouble().clamp(0, 12).toDouble()
            : null; // This line is now retained

        return Scaffold(
          backgroundColor: AppColors.ivory,
          floatingActionButton: _HomeFab(
            onPressed: () {
              _showAddMenu(context, user.uid);
            },
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(
                    greeting: _greeting(),
                    name: name,
                    dateLabel: MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(DateTime.now()),
                  ),
                  const SizedBox(height: 20),

                  BalanceSnapshotCard(
                    userId: user.uid,
                    onEditLife: () => _showScheduleEventDialog(
                      context,
                      user.uid,
                      initialCategory: 'Life',
                    ),
                  ),

                  const SizedBox(height: 22),

                  _DailyCheckInSection(
                    userId: user.uid,
                    workdayByRoutine: isUsualWorkday,
                    workStartTime: workStartTime,
                    workEndTime: workEndTime,
                    workdays: workdays,
                    commuteMinutes: commuteMinutes,
                    jobTitle: jobTitle,
                    routineProfileReady: data['workdays'] is List,
                    sleepHours: sleepHours ?? 8,
                    restHours: restHours ?? 1,
                    onEditWork: () => _showWorkHoursDialog(
                      context,
                      user.uid,
                      workStartTime,
                      workEndTime,
                    ),
                    onEditCommute: () =>
                        _showCommuteDialog(context, user.uid, commuteMinutes),
                    onEditRest: () =>
                        _showRestDialog(context, user.uid, restHours),
                  ),

                  const SizedBox(height: 22),

                  _HomeScheduleSection(
                    userId: user.uid,
                    workStartTime: workStartTime,
                    workEndTime: workEndTime,
                    workdays: workdays,
                    commuteMinutes: commuteMinutes,
                    jobTitle: jobTitle,
                    routineProfileReady: data['workdays'] is List,
                  ),

                  const SizedBox(height: 22),

                  _TodayChecklistSection(userId: user.uid),

                  const SizedBox(height: 22),

                  _IdeaForTodayCard(
                    sideQuests: _readStringList(data['sideQuests']),
                    customSideQuests: _readStringList(data['customSideQuests']),
                    onPlan: (suggestion) => _showScheduleEventDialog(
                      context,
                      user.uid,
                      initialTitle: suggestion,
                      initialCategory: 'Life',
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _HomeNavigationBar(
            onScheduleTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              );
            },
            onProfileTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        );
      },
    );
  }

  static String _weekdayKey(DateTime date) =>
      const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][date.weekday - 1];

  static Future<void> _showAddMenu(BuildContext context, String userId) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.ivory,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Plan a time block'),
              subtitle: const Text('Write a note, then choose area and time.'),
              onTap: () => Navigator.pop(sheetContext, 'plan'),
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('Add to today’s checklist'),
              onTap: () => Navigator.pop(sheetContext, 'activity'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Add a daily focus'),
              onTap: () => Navigator.pop(sheetContext, 'focus'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'plan') {
      await _showScheduleEventDialog(context, userId);
    } else if (action == 'activity') {
      await _showActivityDialog(context, userId, initialCategory: 'Life');
    } else if (action == 'focus') {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const GoalsScreen()));
    }
  }

  static Future<void> _showScheduleEventDialog(
    BuildContext context,
    String userId, {
    String initialCategory = 'Life',
    String? initialTitle,
  }) async {
    final now = DateTime.now();
    final suggestedStart = (((now.hour * 60 + now.minute + 14) ~/ 15) * 15)
        .clamp(0, 1410);
    final draft = await showDialog<ScheduleEventDraft>(
      context: context,
      builder: (_) => ScheduleEventDialog(
        date: now,
        initialTitle: initialTitle,
        initialCategory: initialCategory,
        initialStartMinutes: suggestedStart,
        allowDateChange: false,
      ),
    );
    if (draft == null || !context.mounted) return;
    try {
      final service = FirestoreService();
      final existing = await service.scheduleForDate(userId, draft.date).first;
      if (!context.mounted) return;
      final overlaps = existing.docs.any((doc) {
        final data = doc.data();
        final start = (data['startMinutes'] as num?)?.round() ?? 0;
        final end = start + ((data['durationMinutes'] as num?)?.round() ?? 0);
        return draft.startMinutes < end &&
            draft.startMinutes + draft.durationMinutes > start;
      });
      if (overlaps) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That time overlaps another block.')),
        );
        return;
      }
      await service.createScheduleEvent(
        userId: userId,
        title: draft.title,
        category: draft.category,
        date: draft.date,
        startMinutes: draft.startMinutes,
        durationMinutes: draft.durationMinutes,
        notes: draft.notes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Time block added.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Home quick plan save failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this time block. Retry.'),
          ),
        );
      }
    }
  }

  static String _readString(dynamic value, {required String fallback}) {
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

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    return fallback;
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

  static Future<DateTime?> _showActivityDialog(
    BuildContext context,
    String userId, {
    DocumentSnapshot<Map<String, dynamic>>? existingActivity,
    String? initialTitle,
    String initialCategory = 'Life',
    DateTime? initialDate,
  }) async {
    final savedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => _ActivityDialog(
        userId: userId,
        existingActivity: existingActivity,
        initialTitle: initialTitle,
        initialCategory: initialCategory,
        initialDate: initialDate,
      ),
    );

    if (savedDate != null && context.mounted) {
      final dateLabel = MaterialLocalizations.of(
        context,
      ).formatMediumDate(savedDate);
      final isToday =
          savedDate.year == DateTime.now().year &&
          savedDate.month == DateTime.now().month &&
          savedDate.day == DateTime.now().day;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingActivity == null
                ? isToday
                      ? 'Activity added for today.'
                      : 'Activity added for $dateLabel. It won’t appear in today’s list.'
                : isToday
                ? 'Activity updated.'
                : 'Activity updated for $dateLabel.',
          ),
        ),
      );
    }
    return savedDate;
  }

  static DateTime _parseDateKey(String value) {
    final parts = value.split('-');

    if (parts.length != 3) {
      return DateTime.now();
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return DateTime.now();
    }

    return DateTime(year, month, day);
  }

  static Future<void> _deleteActivity(
    BuildContext context,
    String userId,
    String activityId,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(
            'Delete activity?',
            style: GoogleFonts.fraunces(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          content: Text(
            'This activity will be permanently removed.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.sub),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await FirestoreService().deleteActivity(
        userId: userId,
        activityId: activityId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Activity deleted.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Activity delete failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete activity.')),
        );
      }
    }
  }

  static Future<void> _showRestDialog(
    BuildContext context,
    String userId,
    double? currentHours,
  ) async {
    var selectedHours = currentHours ?? 1;
    final hours = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(
            'Set a daily rest target',
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${selectedHours.toStringAsFixed(selectedHours % 1 == 0 ? 0 : 1)} hours',
                style: GoogleFonts.fraunces(fontSize: 25, color: AppColors.ink),
              ),
              Slider(
                value: selectedHours,
                min: 0,
                max: 12,
                divisions: 24,
                activeColor: AppColors.clay,
                onChanged: (value) => setState(() => selectedHours = value),
              ),
              Text(
                'A personal target only; WorkLife does not measure rest automatically.',
                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.sub),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selectedHours),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (hours == null || !context.mounted) return;

    try {
      await FirestoreService().updateRestHours(
        userId: userId,
        restHours: hours,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rest target saved.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Rest target update failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save rest target.')),
        );
      }
    }
  }

  static Future<void> _showWorkHoursDialog(
    BuildContext context,
    String userId,
    String startValue,
    String endValue,
  ) async {
    final initialStart = _timeOfDayFromString(startValue);
    final initialEnd = _timeOfDayFromString(endValue);
    final result = await showDialog<(TimeOfDay, TimeOfDay)>(
      context: context,
      builder: (dialogContext) =>
          _WorkHoursDialog(initialStart: initialStart, initialEnd: initialEnd),
    );
    if (result == null || !context.mounted) return;

    try {
      await FirestoreService().updateWorkHours(
        userId: userId,
        workStartTime: _formatTimeOfDay(result.$1),
        workEndTime: _formatTimeOfDay(result.$2),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Work hours updated.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Work hours update failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update work hours.')),
        );
      }
    }
  }

  static Future<void> _showCommuteDialog(
    BuildContext context,
    String userId,
    int currentMinutes,
  ) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) =>
          _CommuteDialog(initialMinutes: currentMinutes.clamp(0, 180)),
    );
    if (minutes == null || !context.mounted) return;

    try {
      await FirestoreService().updateCommuteMinutes(
        userId: userId,
        commuteMinutes: minutes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('One-way commute updated.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Commute update failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update commute time.')),
        );
      }
    }
  }

  static TimeOfDay _timeOfDayFromString(String value) {
    final minutes = _parseTime(value);
    if (minutes == null) return const TimeOfDay(hour: 9, minute: 0);
    final totalMinutes = (minutes * 60).round();
    return TimeOfDay(hour: totalMinutes ~/ 60 % 24, minute: totalMinutes % 60);
  }

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static Future<void> _setGoalCompletion(
    BuildContext context,
    String userId,
    String goalId,
    bool completed,
  ) async {
    try {
      await FirestoreService().updateGoalCompletion(
        userId: userId,
        goalId: goalId,
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
}

class _ActivityDialog extends StatefulWidget {
  final String userId;
  final DocumentSnapshot<Map<String, dynamic>>? existingActivity;
  final String? initialTitle;
  final String initialCategory;
  final DateTime? initialDate;

  const _ActivityDialog({
    required this.userId,
    this.existingActivity,
    this.initialTitle,
    this.initialCategory = 'Life',
    this.initialDate,
  });

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  static const _categories = ['Work', 'Commute', 'Sleep', 'Rest', 'Life'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _durationController;
  late String _category;
  late DateTime _date;
  String? _scheduleEventId;
  bool _isSaving = false;
  String? _saveError;

  bool get _isEditing => widget.existingActivity != null;

  @override
  void initState() {
    super.initState();
    final data = widget.existingActivity?.data() ?? {};
    _titleController = TextEditingController(
      text: data['title']?.toString() ?? widget.initialTitle ?? '',
    );
    _notesController = TextEditingController(
      text: data['notes']?.toString() ?? '',
    );
    _durationController = TextEditingController(
      text: data['durationMinutes']?.toString() ?? '',
    );
    final savedCategory = data['category']?.toString();
    final storedCategory = _canonicalArea(
      savedCategory ?? widget.initialCategory,
    );
    _category = storedCategory;
    final storedDate = data['date'];
    _scheduleEventId = data['scheduleEventId']?.toString();
    _date = storedDate is String
        ? HomeScreen._parseDateKey(storedDate)
        : storedDate is Timestamp
        ? storedDate.toDate()
        : storedDate is DateTime
        ? storedDate
        : widget.initialDate ?? DateTime.now();
  }

  String _canonicalArea(String category) {
    switch (category.trim().toLowerCase()) {
      case 'work':
        return 'Work';
      case 'commute':
        return 'Commute';
      case 'sleep':
        return 'Sleep';
      case 'rest':
        return 'Rest';
      default:
        return 'Life';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final title = _titleController.text.trim();
      final durationText = _durationController.text.trim();
      final duration = durationText.isEmpty ? 0 : int.parse(durationText);
      final service = FirestoreService();
      final scheduledEvents = await service
          .scheduleForDate(widget.userId, _date)
          .first;
      if (!scheduledEvents.docs.any((event) => event.id == _scheduleEventId)) {
        if (mounted) {
          setState(() {
            _saveError = 'Choose an activity that is still on this schedule.';
            _isSaving = false;
          });
        }
        return;
      }

      if (_isEditing) {
        final activity = widget.existingActivity!;
        final activityData = activity.data() ?? {};
        await service.updateActivity(
          userId: widget.userId,
          activityId: activity.id,
          title: title,
          category: _category,
          date: _date,
          scheduleEventId: _scheduleEventId!,
          notes: _notesController.text.trim(),
          durationMinutes: duration,
          completed: activityData['completed'] == true,
        );
      } else {
        await service.createActivity(
          userId: widget.userId,
          title: title,
          category: _category,
          date: _date,
          scheduleEventId: _scheduleEventId!,
          notes: _notesController.text.trim(),
          durationMinutes: duration,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(_date);
      }
    } catch (error, stackTrace) {
      debugPrint('Activity save failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _saveError = error is FirebaseException
              ? _firebaseErrorMessage(error)
              : 'Could not save activity: $error';
          _isSaving = false;
        });
      }
    }
  }

  String _firebaseErrorMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Access was denied. Check your Firestore permissions.';
      case 'unavailable':
        return 'Firestore is unavailable. Check your connection and retry.';
      case 'failed-precondition':
        return 'Firestore needs additional configuration before saving.';
      default:
        return 'Could not save activity. Please try again.';
    }
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selectedDate != null && mounted) {
      setState(() {
        _date = selectedDate;
        _scheduleEventId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text(
          _isEditing ? 'Edit activity' : 'Add activity',
          style: GoogleFonts.fraunces(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter an activity name.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Activity',
                    hintText: 'What do you want to do?',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Life area'),
                  items: _categories
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _isSaving ? null : _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      MaterialLocalizations.of(context).formatMediumDate(_date),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService().scheduleForDate(
                    widget.userId,
                    _date,
                  ),
                  builder: (context, snapshot) {
                    final events = snapshot.data?.docs ?? [];
                    final safeEventId =
                        events.any((event) => event.id == _scheduleEventId)
                        ? _scheduleEventId
                        : null;
                    return DropdownButtonFormField<String>(
                      key: ValueKey('schedule-anchor-$_scheduleEventId'),
                      initialValue: safeEventId,
                      validator: (value) => value == null
                          ? 'Link this task to a scheduled activity.'
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Schedule anchor',
                        helperText: snapshot.hasError
                            ? 'Schedule unavailable'
                            : events.isEmpty
                            ? 'Add a time block to this day’s schedule first.'
                            : 'Choose what this task belongs to.',
                      ),
                      items: events.map((event) {
                        final data = event.data();
                        final start = data['startMinutes'] is num
                            ? (data['startMinutes'] as num).round()
                            : 0;
                        final title = data['title']?.toString() ?? 'Activity';
                        return DropdownMenuItem<String>(
                          value: event.id,
                          child: Text(
                            '${_formatScheduleTime(start)} · $title',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _isSaving || snapshot.hasError
                          ? null
                          : (value) => setState(() {
                              _scheduleEventId = value;
                              _saveError = null;
                            }),
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _durationController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final duration = int.tryParse(text);
                    if (duration == null || duration < 0) {
                      return 'Enter a valid non-negative duration.';
                    }
                    if (duration > 1440) {
                      return 'Time spent cannot exceed 24 hours for one day.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Time spent (minutes)',
                    hintText: 'e.g. 45',
                    helperText:
                        'Enter actual minutes. Insights counts it once complete.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _notesController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional',
                  ),
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Save changes' : 'Add activity'),
          ),
        ],
      ),
    );
  }
}

class _WorkHoursDialog extends StatefulWidget {
  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;

  const _WorkHoursDialog({
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<_WorkHoursDialog> createState() => _WorkHoursDialogState();
}

class _WorkHoursDialogState extends State<_WorkHoursDialog> {
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end = widget.initialEnd;

  Future<void> _pickTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (selected != null && mounted) {
      setState(() {
        if (start) {
          _start = selected;
        } else {
          _end = selected;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(
        'Usual work hours',
        style: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            trailing: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(_start),
            ),
            onTap: () => _pickTime(start: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End'),
            trailing: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(_end),
            ),
            onTap: () => _pickTime(start: false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_start, _end)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CommuteDialog extends StatefulWidget {
  final int initialMinutes;

  const _CommuteDialog({required this.initialMinutes});

  @override
  State<_CommuteDialog> createState() => _CommuteDialogState();
}

class _CommuteDialogState extends State<_CommuteDialog> {
  late double _minutes = widget.initialMinutes.toDouble();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(
        'One-way commute',
        style: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_minutes.round()} minutes',
            style: GoogleFonts.fraunces(fontSize: 24, color: AppColors.ink),
          ),
          Slider(
            value: _minutes,
            min: 0,
            max: 180,
            divisions: 36,
            activeColor: AppColors.clay,
            onChanged: (value) => setState(() => _minutes = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_minutes.round()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String dateLabel;

  const _HomeHeader({
    required this.greeting,
    required this.name,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$greeting, '),
                    TextSpan(
                      text: name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: GoogleFonts.fraunces(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                dateLabel,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.sub,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnergyCheckInSection extends StatefulWidget {
  final String userId;

  const _EnergyCheckInSection({required this.userId});

  @override
  State<_EnergyCheckInSection> createState() => _EnergyCheckInSectionState();
}

class _EnergyCheckInSectionState extends State<_EnergyCheckInSection> {
  bool _isSaving = false;
  int? _savingScore;
  int _selectedScore = 5;
  int _retryVersion = 0;

  Future<void> _saveEnergy(int score) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _savingScore = score;
    });

    try {
      await FirestoreService().createOrUpdateDailyCheckIn(
        userId: widget.userId,
        date: DateTime.now(),
        energyScore: score,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Energy check-in saved.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Energy check-in save failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save energy check-in.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingScore = null;
        });
      }
    }
  }

  Future<void> _editEnergy(int currentScore) async {
    final score = await _showEnergyDialog(context, currentScore);
    if (score != null && mounted) {
      await _saveEnergy(score);
    }
  }

  Future<void> _deleteEnergy() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text(
          'Delete today’s check-in?',
          style: GoogleFonts.fraunces(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        content: const Text('Your saved energy score will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      await FirestoreService().deleteDailyCheckIn(
        userId: widget.userId,
        date: DateTime.now(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Energy check-in deleted.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Energy check-in delete failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete energy check-in.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey(_retryVersion),
      stream: FirestoreService().dailyCheckIn(widget.userId, today),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _HomeLoadError(
            message: 'Energy check-in could not be loaded.',
            onRetry: () => setState(() => _retryVersion++),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data();

        if (data == null) {
          return _EnergyPrompt(
            isSaving: _isSaving,
            savingScore: _savingScore,
            selectedScore: _selectedScore,
            onScoreChanged: (score) => setState(() => _selectedScore = score),
            onSave: () => _saveEnergy(_selectedScore),
          );
        }

        final rawScore = data['energyScore'];
        final score = rawScore is num ? rawScore.round() : 0;

        return _EnergyLoggedCard(
          score: score,
          onEdit: () => _editEnergy(score),
          onDelete: _deleteEnergy,
        );
      },
    );
  }

  Future<int?> _showEnergyDialog(
    BuildContext context,
    int existingScore,
  ) async {
    var selectedScore = existingScore;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.ivory,
              title: Text(
                'Update your energy',
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$selectedScore / 10',
                    style: GoogleFonts.fraunces(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: AppColors.clayDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: selectedScore.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: AppColors.clay,
                    onChanged: (value) {
                      setState(() {
                        selectedScore = value.round();
                      });
                    },
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text('Low'), Text('High')],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedScore),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DailyCheckInSection extends StatefulWidget {
  const _DailyCheckInSection({
    required this.userId,
    required this.workdayByRoutine,
    required this.workStartTime,
    required this.workEndTime,
    required this.workdays,
    required this.commuteMinutes,
    required this.jobTitle,
    required this.routineProfileReady,
    required this.sleepHours,
    required this.restHours,
    required this.onEditWork,
    required this.onEditCommute,
    required this.onEditRest,
  });

  final String userId;
  final bool workdayByRoutine;
  final String workStartTime;
  final String workEndTime;
  final List<String> workdays;
  final int commuteMinutes;
  final String jobTitle;
  final bool routineProfileReady;
  final double sleepHours;
  final double restHours;
  final VoidCallback onEditWork;
  final VoidCallback onEditCommute;
  final VoidCallback onEditRest;

  @override
  State<_DailyCheckInSection> createState() => _DailyCheckInSectionState();
}

class _DailyCheckInSectionState extends State<_DailyCheckInSection>
    with WidgetsBindingObserver {
  static const _moods = [
    ('great', '😄', 'Great'),
    ('good', '🙂', 'Good'),
    ('okay', '😐', 'Okay'),
    ('off', '😕', 'Off'),
    ('low', '😞', 'Low'),
  ];

  Color _moodColor(String mood) => switch (mood) {
    'great' => const Color(0xFF98A875),
    'good' => AppColors.eucalyptus,
    'okay' => const Color(0xFFF4D58D),
    'off' => const Color(0xFFE99A70),
    _ => const Color(0xFFE16A60),
  };

  bool _loaded = false;
  bool _isSaving = false;
  bool _isUpdatingWorkStatus = false;
  DateTime _currentDate = DateUtils.dateOnly(DateTime.now());
  String? _mood;
  double _energy = 5;
  int _sleepStartMinutes = 22 * 60;
  int _sleepEndMinutes = 6 * 60;
  int? _lastSavedSleepStartMinutes;
  int? _lastSavedSleepEndMinutes;
  DateTime? _pendingWakeAt;
  bool _pendingWakeIsReanchor = false;
  bool _workingToday = false;
  final Map<String, bool> _meals = {
    'breakfast': false,
    'lunch': false,
    'dinner': false,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _DailyCheckInSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.workdayByRoutine != widget.workdayByRoutine ||
        oldWidget.routineProfileReady != widget.routineProfileReady ||
        oldWidget.sleepHours != widget.sleepHours) {
      _loaded = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.isSameDay(today, _currentDate)) return;
    setState(() {
      _currentDate = today;
      _loaded = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || _isUpdatingWorkStatus) return;
    if (_sleepStartMinutes == _sleepEndMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose different sleep and wake times.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final now = _currentDate;
    final service = FirestoreService();
    try {
      final currentWindow = await service
          .currentBalanceWindowDocument(widget.userId)
          .get();
      final currentWindowData = currentWindow.data() ?? <String, dynamic>{};
      final currentEndValue = currentWindowData['endAt'];
      final currentEnd = currentEndValue is Timestamp
          ? currentEndValue.toDate()
          : null;
      final hasActiveWindow =
          currentWindowData['status'] == 'active' &&
          currentEnd != null &&
          DateTime.now().isBefore(currentEnd);
      if (!hasActiveWindow && _pendingWakeAt == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Confirm your actual wake-up time to start a new 24-hour window.',
              ),
            ),
          );
        }
        return;
      }
      if (hasActiveWindow && _pendingWakeAt != null && _pendingWakeIsReanchor) {
        await service.reanchorBalanceWindow(
          userId: widget.userId,
          wakeAt: _pendingWakeAt!,
        );
      } else if (!hasActiveWindow) {
        await service.startBalanceWindow(
          userId: widget.userId,
          wakeAt: _pendingWakeAt!,
        );
      }
      await service.saveDailyCheckIn(
        userId: widget.userId,
        date: now,
        energyScore: _energy.round(),
        mealStatus: Map<String, bool>.from(_meals),
        sleepStartMinutes: _sleepStartMinutes,
        sleepEndMinutes: _sleepEndMinutes,
        mood: _mood,
      );
      await service.saveCurrentBalanceWindowSleep(
        userId: widget.userId,
        checkInDate: now,
        sleepStartMinutes: _sleepStartMinutes,
        sleepEndMinutes: _sleepEndMinutes,
      );
      await service.setWorkStatus(
        userId: widget.userId,
        date: now,
        working: _workingToday,
      );
      if (_workingToday) {
        await service.ensureRoutineScheduleForDate(
          userId: widget.userId,
          date: now,
          workStartTime: widget.workStartTime,
          workEndTime: widget.workEndTime,
          workdays: widget.workdays,
          commuteMinutes: widget.commuteMinutes,
          jobTitle: widget.jobTitle,
        );
      }
      if (mounted) {
        setState(() {
          _lastSavedSleepStartMinutes = _sleepStartMinutes;
          _lastSavedSleepEndMinutes = _sleepEndMinutes;
          _pendingWakeAt = null;
          _pendingWakeIsReanchor = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Daily check-in saved.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Daily check-in save failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save today’s check-in.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickWakeUpTime({
    DateTime? initial,
    bool reanchor = false,
  }) async {
    final now = DateTime.now();
    final initialDate = initial ?? now;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialDate),
      firstDate: DateUtils.dateOnly(now.subtract(const Duration(days: 2))),
      lastDate: DateUtils.dateOnly(now),
      helpText: 'Which day did you wake up?',
    );
    if (selectedDate == null || !mounted) return;
    final initialTime = initial == null
        ? const TimeOfDay(hour: 7, minute: 0)
        : TimeOfDay.fromDateTime(initial);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'What time did you wake up?',
    );
    if (selectedTime == null || !mounted) return;
    final wakeAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (wakeAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wake-up time cannot be in the future.')),
      );
      return;
    }
    if (!wakeAt.add(const Duration(hours: 24)).isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a wake-up time within the last 24 hours.'),
        ),
      );
      return;
    }
    setState(() {
      _pendingWakeAt = wakeAt;
      _pendingWakeIsReanchor = reanchor;
      _sleepEndMinutes = wakeAt.hour * 60 + wakeAt.minute;
    });
  }

  String _formatWakeAt(DateTime value) {
    final date = MaterialLocalizations.of(context).formatMediumDate(value);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date at $time';
  }

  Widget _trackingWindowCheckIn() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().currentBalanceWindow(widget.userId),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final startValue = data['startAt'];
        final endValue = data['endAt'];
        final start = startValue is Timestamp ? startValue.toDate() : null;
        final end = endValue is Timestamp ? endValue.toDate() : null;
        final active =
            data['status'] == 'active' &&
            end != null &&
            DateTime.now().isBefore(end);
        final selected = _pendingWakeAt;
        final description = selected != null
            ? 'Wake-up: ${_formatWakeAt(selected)}'
            : active && start != null
            ? 'Window: ${_formatWakeAt(start)} – ${_formatWakeAt(end)}'
            : data['status'] == 'complete'
            ? 'Previous window saved · confirm wake-up'
            : 'Confirm your wake-up time';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.wb_twilight_outlined,
                size: 17,
                color: AppColors.eucalyptusDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    height: 1.35,
                    color: AppColors.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () => _pickWakeUpTime(
                        initial: selected ?? (active ? start : null),
                        reanchor: active,
                      ),
                child: Text(
                  selected != null
                      ? 'Change'
                      : active
                      ? 'Edit'
                      : 'Confirm',
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickSleepTime({required bool isStart}) async {
    final minutes = isStart ? _sleepStartMinutes : _sleepEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: isStart ? 'When do you go to sleep?' : 'When do you wake up?',
    );
    if (picked == null || !mounted) return;
    final selectedMinutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (isStart) {
        _sleepStartMinutes = selectedMinutes;
      } else {
        _sleepEndMinutes = selectedMinutes;
      }
    });
  }

  String _formatSleepTime(int minutes) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

  Future<void> _changeWorkStatus(bool working) async {
    if (_isSaving || _isUpdatingWorkStatus) return;
    setState(() {
      _workingToday = working;
      _isUpdatingWorkStatus = true;
    });
    final service = FirestoreService();
    try {
      await service.setWorkStatus(
        userId: widget.userId,
        date: _currentDate,
        working: working,
      );
      if (working) {
        await service.ensureRoutineScheduleForDate(
          userId: widget.userId,
          date: _currentDate,
          workStartTime: widget.workStartTime,
          workEndTime: widget.workEndTime,
          workdays: widget.workdays,
          commuteMinutes: widget.commuteMinutes,
          jobTitle: widget.jobTitle,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Work status update failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update today’s work schedule. Try saving the check-in.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingWorkStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().dailyCheckIn(widget.userId, _currentDate),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _HomeLoadError(
            message: 'Daily check-in could not be loaded.',
            onRetry: () => setState(() => _loaded = false),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        if (!_loaded) {
          _mood = data['mood']?.toString();
          final savedEnergy = data['energyScore'];
          _energy = savedEnergy is num
              ? savedEnergy.toDouble().clamp(1, 10).toDouble()
              : 5;
          final status = data['workStatus']?.toString();
          _workingToday = status == 'working'
              ? true
              : status == 'leave'
              ? false
              : widget.workdayByRoutine;
          final sleepStartValue = data['sleepStartMinutes'];
          final sleepEndValue = data['sleepEndMinutes'];
          final defaultSleepStart = 22 * 60;
          final defaultSleepDuration = (widget.sleepHours * 60)
              .round()
              .clamp(1, 12 * 60)
              .toInt();
          _sleepStartMinutes = sleepStartValue is num
              ? sleepStartValue.round().clamp(0, 1439).toInt()
              : defaultSleepStart;
          _sleepEndMinutes = sleepEndValue is num
              ? sleepEndValue.round().clamp(0, 1439).toInt()
              : (defaultSleepStart + defaultSleepDuration) % (24 * 60);
          _lastSavedSleepStartMinutes = _sleepStartMinutes;
          _lastSavedSleepEndMinutes = _sleepEndMinutes;
          final meals = data['mealStatus'];
          if (meals is Map) {
            for (final key in _meals.keys) {
              _meals[key] = meals[key] == true;
            }
          }
          _loaded = true;
        } else {
          final savedStart = data['sleepStartMinutes'];
          final savedEnd = data['sleepEndMinutes'];
          final localSleepIsUnedited =
              _sleepStartMinutes == _lastSavedSleepStartMinutes &&
              _sleepEndMinutes == _lastSavedSleepEndMinutes;
          if (localSleepIsUnedited && savedStart is num && savedEnd is num) {
            final nextStart = savedStart.round().clamp(0, 1439).toInt();
            final nextEnd = savedEnd.round().clamp(0, 1439).toInt();
            if (nextStart != _sleepStartMinutes ||
                nextEnd != _sleepEndMinutes) {
              _sleepStartMinutes = nextStart;
              _sleepEndMinutes = nextEnd;
              _lastSavedSleepStartMinutes = nextStart;
              _lastSavedSleepEndMinutes = nextEnd;
            }
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.peach,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_outlined,
                      color: AppColors.clayDark,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Daily check-in',
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MOOD',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.clayDark,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.peach.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Row(
                        children: _moods.map((mood) {
                          final selected = _mood == mood.$1;
                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: selected,
                              label: mood.$3,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(32),
                                onTap: _isSaving
                                    ? null
                                    : () => setState(() => _mood = mood.$1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        width: 47,
                                        height: 47,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _moodColor(mood.$1),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.eucalyptusDark
                                                : Colors.white.withValues(
                                                    alpha: 0.9,
                                                  ),
                                            width: selected ? 2.5 : 1.5,
                                          ),
                                          boxShadow: selected
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .eucalyptusDark
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    blurRadius: 5,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          mood.$2,
                                          style: const TextStyle(fontSize: 25),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        mood.$3,
                                        maxLines: 1,
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: selected
                                              ? AppColors.ink
                                              : AppColors.clayDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: AppColors.line),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Energy',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${_energy.round()} / 10',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.clayDark,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _energy,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      activeColor: AppColors.clay,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _energy = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIME PLAN',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.clayDark,
                      ),
                    ),
                    _trackingWindowCheckIn(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        'I’m working today',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      subtitle: Text(
                        _workingToday
                            ? 'Your usual work blocks are in today’s schedule.'
                            : 'Today’s work blocks are removed.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          height: 1.25,
                          color: AppColors.sub,
                        ),
                      ),
                      value: _workingToday,
                      activeTrackColor: AppColors.eucalyptusDark,
                      onChanged: _isSaving || _isUpdatingWorkStatus
                          ? null
                          : _changeWorkStatus,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'WORK & COMMUTE',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.clayDark,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : widget.onEditWork,
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 9,
                              ),
                              minimumSize: const Size(0, 58),
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.work_outline, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Work',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${widget.workStartTime}–${widget.workEndTime}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.sub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : widget.onEditCommute,
                            style: OutlinedButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 9,
                              ),
                              minimumSize: const Size(0, 58),
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.directions_transit_outlined,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Commute',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${widget.commuteMinutes} min each way',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.sub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'REST & SLEEP',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.clayDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : widget.onEditRest,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 68),
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.self_improvement_outlined,
                                  size: 16,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Rest',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatTargetHours(widget.restHours),
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => _pickSleepTime(isStart: true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 68),
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.nightlight_outlined, size: 16),
                                const SizedBox(height: 3),
                                Text(
                                  'Sleep',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatSleepTime(_sleepStartMinutes),
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => _pickSleepTime(isStart: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 68),
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wb_sunny_outlined, size: 16),
                                const SizedBox(height: 3),
                                Text(
                                  'Wake',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatSleepTime(_sleepEndMinutes),
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEALS',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.clayDark,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        for (final meal in const [
                          ('breakfast', 'Breakfast'),
                          ('lunch', 'Lunch'),
                          ('dinner', 'Dinner'),
                        ])
                          FilterChip(
                            label: Text(meal.$2),
                            selected: _meals[meal.$1] == true,
                            labelStyle: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                            visualDensity: VisualDensity.compact,
                            onSelected: _isSaving
                                ? null
                                : (value) =>
                                      setState(() => _meals[meal.$1] = value),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving || _isUpdatingWorkStatus ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check, size: 17),
                  label: Text(_isSaving ? 'Saving' : 'Save check-in'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTargetHours(double hours) {
    final value = hours % 1 == 0
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(1);
    return '${value}h';
  }
}

class _EnergyPrompt extends StatelessWidget {
  final bool isSaving;
  final int? savingScore;
  final int selectedScore;
  final ValueChanged<int> onScoreChanged;
  final VoidCallback onSave;

  const _EnergyPrompt({
    required this.isSaving,
    required this.savingScore,
    required this.selectedScore,
    required this.onScoreChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.bolt_outlined,
                  color: AppColors.clayDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY CHECK-IN · ENERGY',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppColors.clayDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How are you feeling today?',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$selectedScore / 10',
            style: GoogleFonts.fraunces(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.clayDark,
            ),
          ),
          Slider(
            value: selectedScore.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppColors.clay,
            onChanged: isSaving
                ? null
                : (value) => onScoreChanged(value.round()),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Low'), Text('High')],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 17),
            label: Text(isSaving ? 'Saving' : 'Save check-in'),
          ),
        ],
      ),
    );
  }
}

class _EnergyLoggedCard extends StatelessWidget {
  final int score;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  const _EnergyLoggedCard({
    required this.score,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.eucalyptus,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$score',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.eucalyptusDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY’S ENERGY',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _energyMessage(score),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: AppColors.eucalyptusDark),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Update')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  String _energyMessage(int score) {
    if (score <= 3) {
      return 'Running a little low today.';
    }

    if (score <= 6) {
      return 'You’re somewhere in the middle.';
    }

    if (score <= 8) {
      return 'You’re feeling pretty good today.';
    }

    return 'You’re feeling energized today.';
  }
}

class _HomeScheduleSection extends StatefulWidget {
  const _HomeScheduleSection({
    required this.userId,
    required this.workStartTime,
    required this.workEndTime,
    required this.workdays,
    required this.commuteMinutes,
    required this.jobTitle,
    required this.routineProfileReady,
  });

  final String userId;
  final String workStartTime;
  final String workEndTime;
  final List<String> workdays;
  final int commuteMinutes;
  final String jobTitle;
  final bool routineProfileReady;

  @override
  State<_HomeScheduleSection> createState() => _HomeScheduleSectionState();
}

class _HomeScheduleSectionState extends State<_HomeScheduleSection>
    with WidgetsBindingObserver {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _scheduleStream;
  bool _isSaving = false;
  DateTime _currentDate = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleStream = _createScheduleStream();
    if (widget.routineProfileReady) _ensureRoutineSchedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = DateUtils.dateOnly(DateTime.now());
    if (DateUtils.isSameDay(today, _currentDate)) return;
    setState(() {
      _currentDate = today;
      _scheduleStream = _createScheduleStream();
    });
    _ensureRoutineSchedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HomeScheduleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.workStartTime != widget.workStartTime ||
        oldWidget.workEndTime != widget.workEndTime ||
        oldWidget.commuteMinutes != widget.commuteMinutes ||
        oldWidget.jobTitle != widget.jobTitle ||
        oldWidget.routineProfileReady != widget.routineProfileReady ||
        oldWidget.workdays.join('|') != widget.workdays.join('|')) {
      if (widget.routineProfileReady) _ensureRoutineSchedule();
    }
  }

  Future<void> _ensureRoutineSchedule() async {
    if (!widget.routineProfileReady) return;
    try {
      await FirestoreService().ensureRoutineScheduleForDate(
        userId: widget.userId,
        date: _currentDate,
        workStartTime: widget.workStartTime,
        workEndTime: widget.workEndTime,
        workdays: widget.workdays,
        commuteMinutes: widget.commuteMinutes,
        jobTitle: widget.jobTitle,
      );
    } catch (error, stackTrace) {
      debugPrint('Routine schedule setup failed: $error\n$stackTrace');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _createScheduleStream() {
    return FirestoreService().scheduleForDate(widget.userId, _currentDate);
  }

  void _retrySchedule() {
    setState(() => _scheduleStream = _createScheduleStream());
    _ensureRoutineSchedule();
  }

  int _suggestedStartMinutes() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    return (((currentMinutes + 14) ~/ 15) * 15).clamp(0, 1410).toInt();
  }

  Future<void> _editEvent({
    QueryDocumentSnapshot<Map<String, dynamic>>? event,
    String? initialTitle,
  }) async {
    if (_isSaving) return;

    final draft = await showDialog<ScheduleEventDraft>(
      context: context,
      builder: (_) => ScheduleEventDialog(
        date: _currentDate,
        existing: event,
        initialTitle: initialTitle,
        initialCategory: 'Life',
        initialStartMinutes: _suggestedStartMinutes(),
        allowDateChange: false,
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final service = FirestoreService();
      final currentEvents = await service
          .scheduleForDate(widget.userId, draft.date)
          .first;
      if (!mounted) return;

      QueryDocumentSnapshot<Map<String, dynamic>>? conflict;
      for (final current in currentEvents.docs) {
        if (current.id == event?.id) continue;
        final data = current.data();
        final start = data['startMinutes'] is num
            ? (data['startMinutes'] as num).round()
            : 0;
        final end =
            start +
            (data['durationMinutes'] is num
                ? (data['durationMinutes'] as num).round()
                : 0);
        final newEnd = draft.startMinutes + draft.durationMinutes;
        if (draft.startMinutes < end && newEnd > start) {
          conflict = current;
          break;
        }
      }

      if (conflict != null) {
        final conflictingTitle =
            conflict.data()['title']?.toString() ?? 'Another block';
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.ivory,
            title: Text(
              'That time is already planned',
              style: GoogleFonts.fraunces(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            content: Text(
              '“$conflictingTitle” overlaps this block. Choose another time or duration.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.sub),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Adjust time'),
              ),
            ],
          ),
        );
        return;
      }

      if (event == null) {
        await service.createScheduleEvent(
          userId: widget.userId,
          title: draft.title,
          category: draft.category,
          date: draft.date,
          startMinutes: draft.startMinutes,
          durationMinutes: draft.durationMinutes,
          notes: draft.notes,
        );
      } else {
        await service.updateScheduleEvent(
          userId: widget.userId,
          eventId: event.id,
          title: draft.title,
          category: draft.category,
          date: draft.date,
          startMinutes: draft.startMinutes,
          durationMinutes: draft.durationMinutes,
          notes: draft.notes,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event == null ? 'Time block added.' : 'Time block updated.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Home schedule save failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this time block. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> event,
  ) async {
    if (_isSaving) return;
    final title = event.data()['title']?.toString() ?? 'Time block';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text(
          'Delete this time block?',
          style: GoogleFonts.fraunces(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        content: Text('“$title” will be removed from today’s plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await FirestoreService().deleteScheduleEvent(
        userId: widget.userId,
        eventId: event.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Time block deleted.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Home schedule delete failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete this time block. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _scheduleStream,
      builder: (context, snapshot) {
        final sortedEvents = [...?snapshot.data?.docs]
          ..sort((a, b) {
            final aStart = a.data()['startMinutes'] is num
                ? (a.data()['startMinutes'] as num).round()
                : 0;
            final bStart = b.data()['startMinutes'] is num
                ? (b.data()['startMinutes'] as num).round()
                : 0;
            return aStart.compareTo(bStart);
          });
        final canEdit = snapshot.hasData && !snapshot.hasError && !_isSaving;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Today’s schedule',
              actionLabel: 'See all',
              onAction: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              ),
            ),
            const SizedBox(height: 8),
            if (snapshot.hasError)
              _ScheduleRetryCard(onRetry: _retrySchedule)
            else if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (sortedEvents.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 23,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.eucalyptus,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.eucalyptusDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No time blocks planned',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your day is open.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < sortedEvents.length;
                      index++
                    ) ...[
                      _HomeScheduleRow(
                        event: sortedEvents[index],
                        enabled: canEdit,
                        onEdit: () => _editEvent(event: sortedEvents[index]),
                        onDelete: () => _deleteEvent(sortedEvents[index]),
                      ),
                      if (index < sortedEvents.length - 1)
                        const Divider(
                          height: 1,
                          indent: 15,
                          endIndent: 15,
                          color: AppColors.line,
                        ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeScheduleRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> event;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HomeScheduleRow({
    required this.event,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = event.data();
    final rawStart = data['startMinutes'];
    final start = rawStart is num ? rawStart.round().clamp(0, 1439).toInt() : 0;
    final rawDuration = data['durationMinutes'];
    final duration = rawDuration is num ? rawDuration.round() : 0;
    final category = _canonicalAreaName(data['category']?.toString() ?? 'Life');
    final title = data['title']?.toString() ?? 'Untitled block';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatPlanTime(start),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.eucalyptusDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$duration min',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: AppColors.sub,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: _planCategoryColor(category),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: enabled ? onEdit : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit time block',
            onPressed: enabled ? onEdit : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.edit_outlined, size: 17),
            color: AppColors.eucalyptusDark,
          ),
          IconButton(
            tooltip: 'Delete time block',
            onPressed: enabled ? onDelete : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline, size: 17),
            color: AppColors.clayDark,
          ),
        ],
      ),
    );
  }

  static String _formatPlanTime(int totalMinutes) {
    final hour24 = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  static Color _planCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return AppColors.clayDark;
      case 'commute':
        return AppColors.clay.withValues(alpha: 0.7);
      case 'sleep':
        return AppColors.pistachio;
      case 'rest':
      case 'life':
        return AppColors.eucalyptusDark;
      default:
        return AppColors.eucalyptusDark;
    }
  }
}

String _canonicalAreaName(String category) =>
    switch (category.trim().toLowerCase()) {
      'work' => 'Work',
      'commute' => 'Commute',
      'sleep' => 'Sleep',
      'rest' => 'Rest',
      'meals' => 'Meals',
      _ => 'Life',
    };

String _formatScheduleTime(int totalMinutes) {
  final hour24 = totalMinutes ~/ 60;
  final minute = totalMinutes % 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:${minute.toString().padLeft(2, '0')} $period';
}

class _ScheduleRetryCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _ScheduleRetryCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.clayDark),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Today’s plan could not be loaded. Your saved records are unchanged.',
              style: TextStyle(color: AppColors.sub),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String userId;
  final DocumentSnapshot<Map<String, dynamic>> activity;
  final String? linkedScheduleTitle;

  const _ActivityTile({
    required this.userId,
    required this.activity,
    required this.linkedScheduleTitle,
  });

  @override
  Widget build(BuildContext context) {
    final data = activity.data() ?? {};
    final model = ActivityModel.fromMap(activity.id, data);

    return InkWell(
      onTap: () {
        HomeScreen._showActivityDialog(
          context,
          userId,
          existingActivity: activity,
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Row(
          children: [
            Checkbox(
              value: model.completed,
              activeColor: AppColors.eucalyptusDark,
              onChanged: (value) async {
                try {
                  await FirestoreService().updateActivityCompletion(
                    userId: userId,
                    activityId: activity.id,
                    completed: value ?? false,
                  );
                } catch (error, stackTrace) {
                  debugPrint(
                    'Activity completion update failed: '
                    '$error\n$stackTrace',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not update activity status.'),
                      ),
                    );
                  }
                }
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: model.completed ? AppColors.sub : AppColors.ink,
                      decoration: model.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.eucalyptus.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _canonicalAreaName(model.category),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.eucalyptusDark,
                          ),
                        ),
                      ),
                      if (model.durationMinutes > 0) ...[
                        Text(
                          ' · ',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: AppColors.sub,
                          ),
                        ),
                        Text(
                          '${model.durationMinutes} min',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  _ScheduleAnchorLabel(
                    scheduleEventId: data['scheduleEventId']?.toString(),
                    linkedScheduleTitle: linkedScheduleTitle,
                  ),
                  if (model.notes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      model.notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz,
                size: 19,
                color: AppColors.sub,
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  HomeScreen._showActivityDialog(
                    context,
                    userId,
                    existingActivity: activity,
                  );
                } else if (value == 'delete') {
                  await HomeScreen._deleteActivity(
                    context,
                    userId,
                    activity.id,
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayChecklistSection extends StatefulWidget {
  const _TodayChecklistSection({required this.userId});

  final String userId;

  @override
  State<_TodayChecklistSection> createState() => _TodayChecklistSectionState();
}

class _TodayChecklistSectionState extends State<_TodayChecklistSection> {
  int _retryVersion = 0;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final service = FirestoreService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Today’s checklist',
          actionLabel: 'Manage',
          onAction: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey('schedule-links-$_retryVersion'),
          stream: service.scheduleForDate(widget.userId, today),
          builder: (context, scheduleSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              key: ValueKey('goals-$_retryVersion'),
              stream: service.activeGoals(widget.userId),
              builder: (context, goalsSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  key: ValueKey('activities-$_retryVersion'),
                  stream: service.activitiesForDate(widget.userId, today),
                  builder: (context, activitySnapshot) {
                    if (scheduleSnapshot.hasError ||
                        goalsSnapshot.hasError ||
                        activitySnapshot.hasError) {
                      return _ChecklistError(
                        onRetry: () => setState(() => _retryVersion++),
                      );
                    }
                    if (!scheduleSnapshot.hasData ||
                        !goalsSnapshot.hasData ||
                        !activitySnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final scheduleTitles = {
                      for (final event in scheduleSnapshot.data!.docs)
                        event.id:
                            event.data()['title']?.toString() ?? 'Activity',
                    };
                    final goals = goalsSnapshot.data!.docs
                        .where(
                          (goal) => goal.data()['date']?.toString() == todayKey,
                        )
                        .toList();
                    final activities = activitySnapshot.data!.docs;
                    final total = goals.length + activities.length;
                    final done =
                        goals
                            .where((goal) => goal.data()['completed'] == true)
                            .length +
                        activities
                            .where(
                              (activity) =>
                                  activity.data()['completed'] == true,
                            )
                            .length;

                    if (total == 0) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          'Nothing on your checklist yet.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.sub,
                          ),
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 7),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$done of $total done',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.eucalyptusDark,
                                ),
                              ),
                            ),
                          ),
                          for (final goal in goals)
                            _GoalChecklistRow(
                              userId: widget.userId,
                              goal: goal,
                              linkedScheduleTitle:
                                  scheduleTitles[goal
                                      .data()['scheduleEventId']
                                      ?.toString()],
                            ),
                          for (final activity in activities)
                            _ActivityTile(
                              userId: widget.userId,
                              activity: activity,
                              linkedScheduleTitle:
                                  scheduleTitles[activity
                                      .data()['scheduleEventId']
                                      ?.toString()],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _GoalChecklistRow extends StatelessWidget {
  const _GoalChecklistRow({
    required this.userId,
    required this.goal,
    required this.linkedScheduleTitle,
  });

  final String userId;
  final QueryDocumentSnapshot<Map<String, dynamic>> goal;
  final String? linkedScheduleTitle;

  @override
  Widget build(BuildContext context) {
    final data = goal.data();
    final completed = data['completed'] == true;
    final scheduleEventId = data['scheduleEventId']?.toString();
    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      value: completed,
      activeColor: AppColors.eucalyptusDark,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        data['title']?.toString() ?? 'Daily focus',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: completed ? AppColors.sub : AppColors.ink,
          decoration: completed ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AreaLabel(category: data['category']?.toString() ?? 'Life'),
          Row(
            children: [
              Expanded(
                child: _ScheduleAnchorLabel(
                  scheduleEventId: scheduleEventId,
                  linkedScheduleTitle: linkedScheduleTitle,
                ),
              ),
              if (scheduleEventId == null ||
                  scheduleEventId.isEmpty ||
                  linkedScheduleTitle == null)
                TextButton(
                  onPressed: () => _linkToSchedule(context, data),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Link'),
                ),
            ],
          ),
        ],
      ),
      onChanged: (value) {
        if (value != null) {
          HomeScreen._setGoalCompletion(context, userId, goal.id, value);
        }
      },
    );
  }

  Future<void> _linkToSchedule(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final date = HomeScreen._parseDateKey(data['date']?.toString() ?? '');
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: const Text('Link this focus'),
        content: SizedBox(
          width: 340,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreService().scheduleForDate(userId, date),
            builder: (context, snapshot) {
              final events = snapshot.data?.docs ?? [];
              if (snapshot.hasError) {
                return const Text('Could not load this day’s schedule.');
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (events.isEmpty) {
                return const Text(
                  'Add a time block to this day’s schedule first.',
                );
              }
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final event in events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        event.data()['title']?.toString() ?? 'Activity',
                      ),
                      onTap: () => Navigator.of(dialogContext).pop(event.id),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;
    try {
      await FirestoreService().linkGoalToScheduleEvent(
        userId: userId,
        goalId: goal.id,
        scheduleEventId: selected,
      );
    } catch (error, stackTrace) {
      debugPrint('Goal schedule link failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not link this focus.')),
        );
      }
    }
  }
}

class _AreaLabel extends StatelessWidget {
  const _AreaLabel({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final area = switch (category.trim().toLowerCase()) {
      'work' => 'Work',
      'commute' => 'Commute',
      'sleep' => 'Sleep',
      'rest' => 'Rest',
      'meals' => 'Meals',
      _ => 'Life',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.eucalyptus.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          area,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.eucalyptusDark,
          ),
        ),
      ),
    );
  }
}

class _ScheduleAnchorLabel extends StatelessWidget {
  const _ScheduleAnchorLabel({
    required this.scheduleEventId,
    required this.linkedScheduleTitle,
  });

  final String? scheduleEventId;
  final String? linkedScheduleTitle;

  @override
  Widget build(BuildContext context) {
    Text label(String text, {bool missing = false}) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 10.5,
        color: missing ? AppColors.clayDark : AppColors.sub,
      ),
    );

    if (scheduleEventId == null || scheduleEventId!.isEmpty) {
      return label('Needs a schedule link · tap to edit', missing: true);
    }
    if (linkedScheduleTitle == null) {
      return label('Schedule link missing · tap to edit', missing: true);
    }
    return label('Linked to $linkedScheduleTitle');
  }
}

class _ChecklistError extends StatelessWidget {
  const _ChecklistError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Today’s checklist could not be loaded.',
            style: TextStyle(color: AppColors.sub),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: GoogleFonts.fraunces(
            fontSize: 18,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.clayDark,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(actionLabel),
      ),
    ],
  );
}

class _HomeFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _HomeFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.clay,
      foregroundColor: Colors.white,
      elevation: 3,
      tooltip: 'Add to your day',
      child: const Icon(Icons.add),
    );
  }
}

class _HomeLoadError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _HomeLoadError({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.clayDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _IdeaForTodayCard extends StatefulWidget {
  final List<String> sideQuests;
  final List<String> customSideQuests;
  final ValueChanged<String> onPlan;

  const _IdeaForTodayCard({
    required this.sideQuests,
    required this.customSideQuests,
    required this.onPlan,
  });

  @override
  State<_IdeaForTodayCard> createState() => _IdeaForTodayCardState();
}

class _IdeaForTodayCardState extends State<_IdeaForTodayCard> {
  bool _dismissed = false;
  late final _SideQuestSuggestion _idea;

  static const _suggestions = <_SideQuestSuggestion>[
    _SideQuestSuggestion(
      title: 'Make a tiny art piece',
      description: 'Sketch, collage, or paint for ten playful minutes.',
      emoji: '🎨',
      icon: Icons.brush_outlined,
      background: Color(0xFFE9E4F2),
      accent: Color(0xFF75688F),
    ),
    _SideQuestSuggestion(
      title: 'Make a three-song playlist',
      description: 'Pick songs for the mood you want to carry home.',
      emoji: '🎵',
      icon: Icons.music_note_rounded,
      background: Color(0xFFDDEAF0),
      accent: Color(0xFF527C8A),
    ),
    _SideQuestSuggestion(
      title: 'Learn one dance move',
      description: 'Put on a favorite track and move around for a song.',
      emoji: '💃',
      icon: Icons.motion_photos_on_outlined,
      background: Color(0xFFF3E0E4),
      accent: Color(0xFFAC667A),
    ),
    _SideQuestSuggestion(
      title: 'Play outside for a bit',
      description: 'Shoot hoops, kick a ball, or try a new park route.',
      emoji: '🏀',
      icon: Icons.sports_basketball_outlined,
      background: Color(0xFFF5E7D2),
      accent: Color(0xFFAE7445),
    ),
    _SideQuestSuggestion(
      title: 'Plan a tiny celebration',
      description: 'Invite someone for a snack, game, or living-room party.',
      emoji: '🎉',
      icon: Icons.celebration_outlined,
      background: Color(0xFFE5EBD9),
      accent: Color(0xFF667E52),
    ),
    _SideQuestSuggestion(
      title: 'Try a new recipe twist',
      description: 'Make a snack with one ingredient you have not tried.',
      emoji: '🥐',
      icon: Icons.restaurant_outlined,
      background: Color(0xFFF3E6D7),
      accent: Color(0xFF9C704E),
    ),
    _SideQuestSuggestion(
      title: 'Make something by hand',
      description: 'Fold paper, mend a button, or build a small craft.',
      emoji: '🧵',
      icon: Icons.handyman_outlined,
      background: Color(0xFFE7E4D4),
      accent: Color(0xFF7F7950),
    ),
    _SideQuestSuggestion(
      title: 'Take a photo walk',
      description: 'Find three lovely details on a short walk nearby.',
      emoji: '📷',
      icon: Icons.photo_camera_outlined,
      background: Color(0xFFE1E9E1),
      accent: Color(0xFF5D806B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final ideas = [..._suggestions];
    for (var index = 0; index < widget.sideQuests.length; index++) {
      final title = widget.sideQuests[index];
      ideas.add(
        _suggestions[index % _suggestions.length].copyWith(title: title),
      );
    }
    for (var index = 0; index < widget.customSideQuests.length; index++) {
      final title = widget.customSideQuests[index];
      ideas.add(
        _suggestions[(index + 3) % _suggestions.length].copyWith(title: title),
      );
    }
    _idea = ideas[Random().nextInt(ideas.length)];
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _idea.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _idea.accent.withValues(alpha: 0.14)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -4,
            top: 2,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.48),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(_idea.emoji, style: const TextStyle(fontSize: 39)),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 62,
            child: Icon(
              _idea.icon,
              size: 24,
              color: _idea.accent.withValues(alpha: 0.8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 84),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIDE QUEST',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: _idea.accent,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _idea.title,
                  style: GoogleFonts.fraunces(
                    fontSize: 20,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _idea.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.ink.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 9),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: _idea.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 34),
                    alignment: Alignment.centerLeft,
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => widget.onPlan(_idea.title),
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add to today’s schedule'),
                ),
              ],
            ),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: IconButton(
              tooltip: 'Dismiss idea',
              onPressed: () => setState(() => _dismissed = true),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              color: _idea.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideQuestSuggestion {
  const _SideQuestSuggestion({
    required this.title,
    required this.description,
    required this.emoji,
    required this.icon,
    required this.background,
    required this.accent,
  });

  final String title;
  final String description;
  final String emoji;
  final IconData icon;
  final Color background;
  final Color accent;

  _SideQuestSuggestion copyWith({String? title}) => _SideQuestSuggestion(
    title: title ?? this.title,
    description: description,
    emoji: emoji,
    icon: icon,
    background: background,
    accent: accent,
  );
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
        if (index == 1) {
          onScheduleTap();
        } else if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          );
        } else if (index == 3) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const InsightsScreen()),
          );
        } else if (index == 4) {
          onProfileTap();
        }
      },
    );
  }
}
