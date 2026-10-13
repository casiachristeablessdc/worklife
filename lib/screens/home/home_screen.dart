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

  static Future<void> _showEnergyCheckInDialog(
    BuildContext context,
    String userId, {
    int? currentScore,
  }) async {
    var selectedScore = currentScore ?? 5;
    final score = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(
            currentScore == null ? 'Daily energy check-in' : 'Update energy',
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
                  fontSize: 32,
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
                onChanged: (value) =>
                    setState(() => selectedScore = value.round()),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('Low'), Text('High')],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selectedScore),
              child: const Text('Save check-in'),
            ),
          ],
        ),
      ),
    );
    if (score == null || !context.mounted) return;

    try {
      await FirestoreService().createOrUpdateDailyCheckIn(
        userId: userId,
        date: DateTime.now(),
        energyScore: score,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Daily check-in saved.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Daily energy check-in failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save daily check-in.')),
        );
      }
    }
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

        final jobTitle = _readString(data['jobTitle'], fallback: 'Employee');

        final company = _readString(data['company'], fallback: '');

        final workStartTime = _readString(
          data['workStartTime'],
          fallback: '9:00 AM',
        );

        final workEndTime = _readString(
          data['workEndTime'],
          fallback: '6:00 PM',
        );

        final workdays = _readStringList(data['workdays']);

        final commuteMinutes = _readInt(data['commuteMinutes'], fallback: 60);
        final sleepHours = data['sleepHours'] is num
            ? (data['sleepHours'] as num).toDouble().clamp(0, 12).toDouble()
            : null;
        final restHours = data['restHours'] is num
            ? (data['restHours'] as num).toDouble().clamp(0, 12).toDouble()
            : null; // This line is now retained

        final workHours = _calculateWorkHours(workStartTime, workEndTime);

        final weeklyWorkHours = workHours * workdays.length;
        final weeklyCommuteHours = (commuteMinutes * 2 * workdays.length) / 60;

        return Scaffold(
          backgroundColor: AppColors.ivory,
          floatingActionButton: _HomeFab(
            onPressed: () {
              _showActivityDialog(context, user.uid);
            },
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeHeader(
                    greeting: _greeting(),
                    name: name,
                    jobTitle: jobTitle,
                    company: company,
                    dateLabel: MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(DateTime.now()),
                    onProfileTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  _DailySnapshot(userId: user.uid),

                  const SizedBox(height: 24),

                  _EnergyCheckInSection(userId: user.uid),

                  const SizedBox(height: 28),

                  _TimeOverview(
                    workHours: workHours,
                    commuteMinutes: commuteMinutes,
                    sleepHours: sleepHours,
                    onWorkTap: () => _showWorkHoursDialog(
                      context,
                      user.uid,
                      workStartTime,
                      workEndTime,
                    ),
                    onCommuteTap: () =>
                        _showCommuteDialog(context, user.uid, commuteMinutes),
                    onSleepTap: () =>
                        _showSleepDialog(context, user.uid, sleepHours),
                  ),

                  const SizedBox(height: 28),

                  _HomeScheduleSection(
                    userId: user.uid,
                    workHours: workHours,
                    commuteMinutes: commuteMinutes,
                    sleepHours: sleepHours,
                    restHours: restHours,
                    onRestTap: () =>
                        _showRestDialog(context, user.uid, restHours),
                  ),

                  const SizedBox(height: 28),

                  const _SectionTitle(
                    title: 'Side quest',
                    subtitle: 'Something worth making time for.',
                  ),
                  const SizedBox(height: 14),

                  _SideQuestCard(
                    sideQuests: _readStringList(data['sideQuests']),
                    customSideQuests: _readStringList(data['customSideQuests']),
                    onPlan: (suggestion) => _showActivityDialog(
                      context,
                      user.uid,
                      initialTitle: suggestion,
                      initialCategory: 'Leisure',
                    ),
                  ),

                  const SizedBox(height: 28),

                  const _SectionTitle(
                    title: 'This week',
                    subtitle:
                        'Planned work, recovery targets, and personal time.',
                  ),
                  const SizedBox(height: 14),

                  _WeeklyOverview(
                    userId: user.uid,
                    workHours: weeklyWorkHours,
                    commuteHours: weeklyCommuteHours,
                    workdayCount: workdays.length,
                    sleepHours: sleepHours,
                    restHours: restHours,
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

  static double _calculateWorkHours(String startTime, String endTime) {
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

  static Future<DateTime?> _showActivityDialog(
    BuildContext context,
    String userId, {
    DocumentSnapshot<Map<String, dynamic>>? existingActivity,
    String? initialTitle,
    String initialCategory = 'Personal',
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

  static Future<void> _showSleepDialog(
    BuildContext context,
    String userId,
    double? currentHours,
  ) async {
    var selectedHours = currentHours ?? 8;
    final hours = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.ivory,
          title: Text(
            'Set your sleep target',
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
      await FirestoreService().updateSleepHours(
        userId: userId,
        sleepHours: hours,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sleep target saved.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Sleep target update failed: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save sleep target.')),
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
    this.initialCategory = 'Personal',
    this.initialDate,
  });

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  static const _categories = [
    'Work',
    'Health',
    'Personal',
    'Leisure',
    'Learning',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _durationController;
  late String _category;
  late DateTime _date;
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
    final storedCategory =
        data['category']?.toString() ?? widget.initialCategory;
    _category = _categories.contains(storedCategory)
        ? storedCategory
        : 'Personal';
    final storedDate = data['date'];
    _date = storedDate is String
        ? HomeScreen._parseDateKey(storedDate)
        : storedDate is Timestamp
        ? storedDate.toDate()
        : storedDate is DateTime
        ? storedDate
        : widget.initialDate ?? DateTime.now();
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

      if (_isEditing) {
        final activity = widget.existingActivity!;
        final activityData = activity.data() ?? {};
        await service.updateActivity(
          userId: widget.userId,
          activityId: activity.id,
          title: title,
          category: _category,
          date: _date,
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
      setState(() => _date = selectedDate);
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
                  decoration: const InputDecoration(labelText: 'Category'),
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
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    hintText: 'Minutes',
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
  final String jobTitle;
  final String company;
  final String dateLabel;
  final VoidCallback onProfileTap;

  const _HomeHeader({
    required this.greeting,
    required this.name,
    required this.jobTitle,
    required this.company,
    required this.dateLabel,
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
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
              ),
              const SizedBox(height: 3),
              Text(
                dateLabel,
                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.sub),
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

class _DailySnapshot extends StatelessWidget {
  final String userId;

  const _DailySnapshot({required this.userId});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().dailyCheckIn(userId, today),
      builder: (context, checkInSnapshot) {
        final checkInData = checkInSnapshot.data?.data();

        final energy = checkInData?['energyScore'];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService().activeGoals(userId),
          builder: (context, goalSnapshot) {
            final goals = goalSnapshot.data?.docs ?? [];

            final todayKey = _dateKey(today);

            final todayGoals = goals.where((goal) {
              return goal.data()['date']?.toString() == todayKey;
            }).toList();

            final completedGoals = todayGoals.where((goal) {
              return goal.data()['completed'] == true;
            }).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SnapshotCard(
                        icon: Icons.bolt_outlined,
                        label: 'Energy',
                        value: checkInSnapshot.hasError
                            ? '—'
                            : !checkInSnapshot.hasData
                            ? '…'
                            : energy is num
                            ? '${energy.round()}/10'
                            : '—',
                        subtitle: checkInSnapshot.hasError
                            ? 'Could not load'
                            : !checkInSnapshot.hasData
                            ? 'Loading'
                            : energy is num
                            ? 'Logged · tap to update'
                            : 'Not logged · tap to check in',
                        onTap:
                            checkInSnapshot.hasError || !checkInSnapshot.hasData
                            ? null
                            : () => HomeScreen._showEnergyCheckInDialog(
                                context,
                                userId,
                                currentScore: energy is num
                                    ? energy.round()
                                    : null,
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SnapshotCard(
                        icon: Icons.flag_outlined,
                        label: "Today's focus",
                        value: goalSnapshot.hasError
                            ? '—'
                            : !goalSnapshot.hasData
                            ? '…'
                            : todayGoals.isEmpty
                            ? '0'
                            : '$completedGoals/${todayGoals.length}',
                        subtitle: goalSnapshot.hasError
                            ? 'Could not load'
                            : !goalSnapshot.hasData
                            ? 'Loading'
                            : todayGoals.isEmpty
                            ? 'Tap to set a focus'
                            : completedGoals == todayGoals.length
                            ? 'All complete'
                            : 'Tap to add a focus',
                        onTap: goalSnapshot.hasError
                            ? null
                            : () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const GoalsScreen(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                if (goalSnapshot.hasError)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: _HomeLoadError(
                      message: 'Today’s focus could not be loaded.',
                    ),
                  )
                else if (goalSnapshot.hasData && todayGoals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < todayGoals.length;
                            index++
                          )
                            CheckboxListTile(
                              dense: true,
                              value:
                                  todayGoals[index].data()['completed'] == true,
                              activeColor: AppColors.eucalyptusDark,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                todayGoals[index].data()['title']?.toString() ??
                                    'Daily focus',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.ink,
                                  decoration:
                                      todayGoals[index].data()['completed'] ==
                                          true
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                todayGoals[index]
                                        .data()['category']
                                        ?.toString() ??
                                    'Personal day',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.sub,
                                ),
                              ),
                              onChanged: (completed) {
                                if (completed != null) {
                                  HomeScreen._setGoalCompletion(
                                    context,
                                    userId,
                                    todayGoals[index].id,
                                    completed,
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  static String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

class _SnapshotCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  const _SnapshotCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: AppColors.clayDark),
              const SizedBox(height: 11),
              Text(
                value,
                style: GoogleFonts.fraunces(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.sub),
              ),
            ],
          ),
        ),
      ),
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
      stream: FirestoreService().dailyCheckIn(widget.userId, today),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _HomeLoadError(
            message: 'Energy check-in could not be loaded.',
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

class _HomeScheduleSection extends StatelessWidget {
  final String userId;
  final double workHours;
  final int commuteMinutes;
  final double? sleepHours;
  final double? restHours;
  final VoidCallback onRestTap;

  const _HomeScheduleSection({
    required this.userId,
    required this.workHours,
    required this.commuteMinutes,
    required this.sleepHours,
    required this.restHours,
    required this.onRestTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().scheduleForDate(userId, DateTime.now()),
      builder: (context, snapshot) {
        final events = snapshot.data?.docs ?? [];

        final sortedEvents = [...events]
          ..sort((a, b) {
            final aMinutes = _readInt(a.data()['startMinutes']);

            final bMinutes = _readInt(b.data()['startMinutes']);

            return aMinutes.compareTo(bMinutes);
          });

        final previewEvents = sortedEvents.take(3).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirestoreService().activitiesForDate(userId, DateTime.now()),
          builder: (context, activitySnapshot) {
            final activities = activitySnapshot.data?.docs ?? [];
            final completedActivities = activities
                .where((activity) => activity.data()['completed'] == true)
                .length;
            final leisureMinutes = activities
                .where(
                  (activity) =>
                      activity.data()['category']?.toString().toLowerCase() ==
                      'leisure',
                )
                .fold<int>(
                  0,
                  (total, activity) =>
                      total + _readInt(activity.data()['durationMinutes']),
                );
            final personalWellnessMinutes = activities
                .where(
                  (activity) => const {'personal', 'health'}.contains(
                    activity.data()['category']?.toString().toLowerCase(),
                  ),
                )
                .fold<int>(
                  0,
                  (total, activity) =>
                      total + _readInt(activity.data()['durationMinutes']),
                );
            final sleep = sleepHours ?? 0;
            final rest = restHours ?? 0;
            final commuteHours = commuteMinutes * 2 / 60;
            final flexibleHours = sleepHours == null || restHours == null
                ? null
                : (24 - workHours - commuteHours - sleep - rest)
                      .clamp(0, 24)
                      .toDouble();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: _SectionTitle(
                        title: 'Today at a glance',
                        subtitle: 'Your time plan, schedule, and activities.',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const ScheduleScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'See all',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.eucalyptusDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (activitySnapshot.hasError)
                  const _HomeLoadError(
                    message: 'Today’s activity overview could not be loaded.',
                  )
                else if (activitySnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !activitySnapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.eucalyptus,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DayOverviewStat(
                            label: 'Scheduled',
                            value: snapshot.hasError
                                ? '—'
                                : snapshot.hasData
                                ? '${events.length}'
                                : '…',
                          ),
                        ),
                        Expanded(
                          child: _DayOverviewStat(
                            label: 'Activities',
                            value: '${activities.length}',
                          ),
                        ),
                        Expanded(
                          child: _DayOverviewStat(
                            label: 'Completed',
                            value: '$completedActivities/${activities.length}',
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                if (snapshot.hasError)
                  const _HomeLoadError(
                    message: 'Your schedule could not be loaded.',
                  )
                else if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (previewEvents.isEmpty)
                  _EmptyScheduleCard(
                    onAdd: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const ScheduleScreen(),
                        ),
                      );
                    },
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
                        for (var i = 0; i < previewEvents.length; i++)
                          _ScheduleEventPreview(
                            data: previewEvents[i].data(),
                            isLast: i == previewEvents.length - 1,
                          ),
                      ],
                    ),
                  ),
                if (!activitySnapshot.hasError && activitySnapshot.hasData) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAY PLAN',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sub,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          children: [
                            _DayPlanValue(
                              label: 'Work',
                              value: _formatHours(workHours),
                            ),
                            _DayPlanValue(
                              label: 'Commute',
                              value: _formatHours(commuteHours),
                            ),
                            _DayPlanValue(
                              label: 'Sleep target',
                              value: sleepHours == null
                                  ? 'Not set'
                                  : _formatHours(sleep),
                            ),
                            _DayPlanValue(
                              label: 'Rest target',
                              value: restHours == null
                                  ? 'Not set'
                                  : _formatHours(rest),
                            ),
                            _DayPlanValue(
                              label: 'Side quest',
                              value: _formatMinutes(leisureMinutes),
                            ),
                            _DayPlanValue(
                              label: 'Personal + wellness',
                              value: _formatMinutes(personalWellnessMinutes),
                            ),
                            _DayPlanValue(
                              label: 'Flexible, unallocated',
                              value: flexibleHours == null
                                  ? 'Set sleep + rest targets'
                                  : _formatHours(flexibleHours),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onRestTap,
                            icon: const Icon(
                              Icons.self_improvement_outlined,
                              size: 16,
                            ),
                            label: Text(
                              restHours == null
                                  ? 'Set rest target'
                                  : 'Update rest target',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.eucalyptusDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              minimumSize: const Size(44, 40),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Flexible time remains after your work, commute, sleep, and rest targets. None of these targets measures actual rest.',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _HomeActivitiesSection(userId: userId),
              ],
            );
          },
        );
      },
    );
  }

  static int _readInt(dynamic value) {
    if (value is num) {
      return value.round();
    }

    return 0;
  }

  static String _formatHours(double hours) {
    return '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)}h';
  }

  static String _formatMinutes(int minutes) {
    if (minutes <= 0) return 'None planned';
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainder = minutes % 60;
      return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
    }
    return '${minutes}m';
  }
}

class _DayPlanValue extends StatelessWidget {
  final String label;
  final String value;

  const _DayPlanValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 9, color: AppColors.sub),
          ),
        ],
      ),
    );
  }
}

class _DayOverviewStat extends StatelessWidget {
  final String label;
  final String value;

  const _DayOverviewStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.sub),
        ),
      ],
    );
  }
}

class _ScheduleEventPreview extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isLast;

  const _ScheduleEventPreview({required this.data, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final startMinutes = data['startMinutes'] is num
        ? (data['startMinutes'] as num).round()
        : 0;

    final title = data['title']?.toString() ?? 'Untitled event';
    final category = data['category']?.toString() ?? 'Other';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _formatMinutes(startMinutes),
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
              color: _categoryBackground(category),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _categoryIcon(category),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
                ),
              ],
            ),
          ),
          if (!isLast) const SizedBox.shrink(),
        ],
      ),
    );
  }

  static String _formatMinutes(int totalMinutes) {
    final hour24 = (totalMinutes ~/ 60).clamp(0, 23);
    final minute = totalMinutes % 60;

    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  static IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work_outline;
      case 'health':
        return Icons.favorite_border;
      case 'personal':
        return Icons.person_outline;
      case 'leisure':
        return Icons.spa_outlined;
      case 'learning':
        return Icons.menu_book_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  static Color _categoryBackground(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return AppColors.peach;
      case 'health':
        return AppColors.eucalyptus;
      default:
        return AppColors.peach;
    }
  }
}

class _EmptyScheduleCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyScheduleCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 26,
            color: AppColors.clayDark,
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing scheduled yet',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add something to your schedule to see it here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.sub),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onAdd, child: const Text('Open schedule')),
        ],
      ),
    );
  }
}

class _HomeActivitiesSection extends StatefulWidget {
  final String userId;

  const _HomeActivitiesSection({required this.userId});

  @override
  State<_HomeActivitiesSection> createState() => _HomeActivitiesSectionState();
}

class _HomeActivitiesSectionState extends State<_HomeActivitiesSection> {
  DateTime _selectedDate = DateTime.now();

  bool get _isShowingToday {
    final today = DateTime.now();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selectedDate != null && mounted) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().activitiesForDate(
        widget.userId,
        _selectedDate,
      ),
      builder: (context, snapshot) {
        final activities = snapshot.data?.docs ?? [];
        final completedCount = activities
            .where((item) => item.data()['completed'] == true)
            .length;
        final remainingCount = activities.length - completedCount;
        final progress = activities.isEmpty
            ? 0.0
            : completedCount / activities.length;

        final sortedActivities = [...activities]
          ..sort((a, b) {
            final aCompleted = a.data()['completed'] == true;
            final bCompleted = b.data()['completed'] == true;

            if (aCompleted == bCompleted) {
              return 0;
            }

            return aCompleted ? 1 : -1;
          });

        const categoryOrder = [
          'Work',
          'Personal',
          'Health',
          'Leisure',
          'Learning',
          'Other',
        ];
        final activityGroups =
            <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
        for (final activity in sortedActivities) {
          final rawCategory =
              activity.data()['category']?.toString() ?? 'Other';
          final category = categoryOrder.firstWhere(
            (item) => item.toLowerCase() == rawCategory.toLowerCase(),
            orElse: () => 'Other',
          );
          activityGroups.putIfAbsent(category, () => []).add(activity);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _SectionTitle(
                    title: _isShowingToday
                        ? 'Planned activities'
                        : 'Activities',
                    subtitle: _isShowingToday
                        ? 'Grouped by category · check items off as you go.'
                        : MaterialLocalizations.of(
                            context,
                          ).formatMediumDate(_selectedDate),
                  ),
                ),
                IconButton(
                  tooltip: 'Choose activity date',
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  color: AppColors.eucalyptusDark,
                ),
                if (snapshot.hasData && !snapshot.hasError)
                  Text(
                    '$completedCount/${activities.length}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.eucalyptusDark,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.hasError)
              const _HomeLoadError(
                message: 'Today’s activities could not be loaded.',
              )
            else if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${activities.length} planned · $remainingCount remaining',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: AppColors.sub,
                      ),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.eucalyptusDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppColors.line,
                  color: AppColors.eucalyptusDark,
                ),
              ),
              const SizedBox(height: 12),
              if (sortedActivities.isEmpty)
                _EmptyActivitiesCard(
                  onAdd: () async {
                    final savedDate = await HomeScreen._showActivityDialog(
                      context,
                      widget.userId,
                      initialDate: _selectedDate,
                    );
                    if (savedDate != null && mounted) {
                      setState(() => _selectedDate = savedDate);
                    }
                  },
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
                      for (final category in categoryOrder)
                        if (activityGroups[category]?.isNotEmpty == true) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                category,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.eucalyptusDark,
                                ),
                              ),
                            ),
                          ),
                          for (
                            var index = 0;
                            index < activityGroups[category]!.length;
                            index++
                          )
                            _ActivityTile(
                              userId: widget.userId,
                              activity: activityGroups[category]![index],
                              isLast:
                                  category == categoryOrder.last &&
                                  index == activityGroups[category]!.length - 1,
                            ),
                        ],
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String userId;
  final DocumentSnapshot<Map<String, dynamic>> activity;
  final bool isLast;

  const _ActivityTile({
    required this.userId,
    required this.activity,
    required this.isLast,
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
                      fontSize: 12,
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
                      Text(
                        model.category,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          color: AppColors.sub,
                        ),
                      ),
                      if (model.durationMinutes > 0) ...[
                        Text(
                          ' · ',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            color: AppColors.sub,
                          ),
                        ),
                        Text(
                          '${model.durationMinutes} min',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            color: AppColors.sub,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (model.notes.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      model.notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
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

class _EmptyActivitiesCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyActivitiesCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.eucalyptus,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.checklist_outlined,
              color: AppColors.eucalyptusDark,
              size: 23,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your day starts here',
            style: GoogleFonts.fraunces(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Add your first activity and check things off as you go.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10.5,
              height: 1.45,
              color: AppColors.sub,
            ),
          ),
          const SizedBox(height: 13),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Add first activity'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.clay,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
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
      tooltip: 'Add activity',
      child: const Icon(Icons.add),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

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
          style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.sub),
        ),
      ],
    );
  }
}

class _HomeLoadError extends StatelessWidget {
  final String message;

  const _HomeLoadError({required this.message});

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
        ],
      ),
    );
  }
}

class _TimeOverview extends StatelessWidget {
  final double workHours;
  final int commuteMinutes;
  final double? sleepHours;
  final VoidCallback onWorkTap;
  final VoidCallback onCommuteTap;
  final VoidCallback onSleepTap;

  const _TimeOverview({
    required this.workHours,
    required this.commuteMinutes,
    required this.sleepHours,
    required this.onWorkTap,
    required this.onCommuteTap,
    required this.onSleepTap,
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
            onTap: onWorkTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeTile(
            icon: Icons.directions_car_outlined,
            label: 'Commute · round trip',
            value: _formatCommute(commuteMinutes * 2),
            onTap: onCommuteTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimeTile(
            icon: Icons.bed_outlined,
            label: 'Sleep',
            value: sleepHours == null ? 'Set' : _formatHours(sleepHours!),
            onTap: onSleepTap,
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
  final VoidCallback? onTap;

  const _TimeTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.clayDark),
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
                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.sub),
              ),
              if (onTap != null)
                Text(
                  'Tap to update',
                  style: GoogleFonts.inter(fontSize: 8.5, color: AppColors.sub),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideQuestCard extends StatelessWidget {
  final List<String> sideQuests;
  final List<String> customSideQuests;
  final ValueChanged<String> onPlan;

  const _SideQuestCard({
    required this.sideQuests,
    required this.customSideQuests,
    required this.onPlan,
  });

  @override
  Widget build(BuildContext context) {
    final allSideQuests = [...sideQuests, ...customSideQuests];

    final sideQuest = allSideQuests.isNotEmpty
        ? allSideQuests.first
        : 'Take a short walk away from your desk.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.peach,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'A SMALL IDEA FOR TODAY',
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Just a suggestion. Add it to your activities only if you choose.',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => onPlan(sideQuest),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Plan this'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.clayDark,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 40),
                    ),
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

class _WeeklyOverview extends StatelessWidget {
  final String userId;
  final double workHours;
  final double commuteHours;
  final int workdayCount;
  final double? sleepHours;
  final double? restHours;

  const _WeeklyOverview({
    required this.userId,
    required this.workHours,
    required this.commuteHours,
    required this.workdayCount,
    required this.sleepHours,
    required this.restHours,
  });

  String _formatHours(double hours) {
    if (hours == hours.roundToDouble()) {
      return '${hours.toInt()}h';
    }

    return '${hours.toStringAsFixed(1)}h';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().activitiesForWeek(userId, monday),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _HomeLoadError(
            message: 'This week’s activity plan could not be loaded.',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        int minutesFor(Set<String> categories) => docs
            .where(
              (doc) => categories.contains(
                doc.data()['category']?.toString().toLowerCase(),
              ),
            )
            .fold<int>(
              0,
              (total, doc) =>
                  total + _readMinutes(doc.data()['durationMinutes']),
            );

        final sideQuestHours = minutesFor({'leisure'}) / 60;
        final personalHours = minutesFor({'personal', 'health'}) / 60;
        final sleepWeekHours = sleepHours == null ? null : sleepHours! * 7;
        final restWeekHours = restHours == null ? null : restHours! * 7;
        final plannedAwakeHours = sleepWeekHours == null
            ? null
            : 168 - sleepWeekHours;
        final workAndCommuteHours = workHours + commuteHours;
        final workShare = plannedAwakeHours == null || plannedAwakeHours <= 0
            ? null
            : workAndCommuteHours / plannedAwakeHours;
        final flexibleHours = sleepWeekHours == null || restWeekHours == null
            ? null
            : (168 -
                      workAndCommuteHours -
                      sleepWeekHours -
                      restWeekHours -
                      sideQuestHours -
                      personalHours)
                  .clamp(0, 168)
                  .toDouble();
        final workHeavy = workShare != null && workShare >= 0.5;

        final suggestion = sleepHours == null || restHours == null
            ? 'Set both sleep and rest targets to calculate time left after your recovery targets.'
            : workHeavy
            ? 'Work and commuting take about ${(workShare * 100).round()}% of planned awake time. Protect a specific personal block and consider reducing or batching commute days where possible.'
            : sideQuestHours + personalHours == 0
            ? 'Your routine leaves room outside work, but no personal or wellness activities are planned yet. Add one small activity you would look forward to.'
            : 'Your planned week leaves about ${_formatHours(flexibleHours!)} unallocated beyond work, commuting, sleep, rest, and logged personal activities. Keep some of that time unscheduled for recovery.';

        final totalLifeHours = sideQuestHours + personalHours;
        final chartParts = [
          workHours,
          commuteHours,
          sleepWeekHours ?? 0,
          restWeekHours ?? 0,
          totalLifeHours,
          flexibleHours ?? 0,
        ];
        final chartFlexes = chartParts
            .map((hours) => (hours * 10).round().clamp(1, 1680).toInt())
            .toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      value: sleepWeekHours == null
                          ? '—'
                          : _formatHours(sleepWeekHours),
                      label: 'Sleep target',
                    ),
                  ),
                  Expanded(
                    child: _WeeklyStat(
                      value: restWeekHours == null
                          ? '—'
                          : _formatHours(restWeekHours),
                      label: 'Rest target',
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
                      flex: chartFlexes[0],
                      child: Container(height: 8, color: AppColors.clay),
                    ),
                    Expanded(
                      flex: chartFlexes[1],
                      child: Container(
                        height: 8,
                        color: AppColors.eucalyptusDark,
                      ),
                    ),
                    Expanded(
                      flex: chartFlexes[2],
                      child: Container(height: 8, color: AppColors.pistachio),
                    ),
                    Expanded(
                      flex: chartFlexes[3],
                      child: Container(height: 8, color: AppColors.eucalyptus),
                    ),
                    Expanded(
                      flex: chartFlexes[4],
                      child: Container(height: 8, color: AppColors.peach),
                    ),
                    Expanded(
                      flex: chartFlexes[5],
                      child: Container(height: 8, color: AppColors.line),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  _LegendItem(color: AppColors.clay, label: 'Work'),
                  _LegendItem(
                    color: AppColors.eucalyptusDark,
                    label: 'Commute',
                  ),
                  _LegendItem(
                    color: AppColors.pistachio,
                    label: 'Sleep target',
                  ),
                  _LegendItem(
                    color: AppColors.eucalyptus,
                    label: 'Rest target',
                  ),
                  _LegendItem(color: AppColors.peach, label: 'Logged life'),
                  _LegendItem(color: AppColors.line, label: 'Unallocated'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                workShare == null
                    ? 'PLANNED WEEK · $workdayCount workdays'
                    : workHeavy
                    ? 'WORK-HEAVY PLAN · ${(workShare * 100).round()}% OF AWAKE TIME'
                    : 'PLANNED TIME HAS ROOM OUTSIDE WORK',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: workHeavy
                      ? AppColors.clayDark
                      : AppColors.eucalyptusDark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Logged this week: ${_formatHours(sideQuestHours)} side quest and ${_formatHours(personalHours)} personal/wellness activities.',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  height: 1.4,
                  color: AppColors.sub,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                suggestion,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  height: 1.4,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Work and commute use your usual profile schedule; sleep and rest use your targets. Logged activity durations are user-entered. This is a plan estimate, not a clinical balance score.',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  height: 1.35,
                  color: AppColors.sub,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static int _readMinutes(dynamic value) => value is num ? value.round() : 0;
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9, color: AppColors.sub),
        ),
      ],
    );
  }
}

class _WeeklyStat extends StatelessWidget {
  final String value;
  final String label;

  const _WeeklyStat({required this.value, required this.label});

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
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
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
