import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../goals/goals_screen.dart';
import '../insights/insights_screen.dart';
import '../profile/profile_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  int _scheduleRetryVersion = 0;
  final Set<String> _seededRoutineDays = {};

  DateTime get _selectedDay =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

  void _seedRoutineForDay(String userId, Map<String, dynamic> profile) {
    final rawWorkdays = profile['workdays'];
    if (rawWorkdays is! List) return;
    final key = '${userId}_${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}';
    if (!_seededRoutineDays.add(key)) return;
    _seedRoutine(
      userId,
      _selectedDay,
      _readString(profile['workStartTime'], fallback: '9:00 AM'),
      _readString(profile['workEndTime'], fallback: '6:00 PM'),
      _readStringList(rawWorkdays),
      _readInt(profile['commuteMinutes'], fallback: 0),
      _readString(profile['jobTitle'], fallback: 'Work'),
    );
  }

  Future<void> _seedRoutine(
    String userId,
    DateTime date,
    String start,
    String end,
    List<String> workdays,
    int commuteMinutes,
    String jobTitle,
  ) async {
    try {
      await FirestoreService().ensureRoutineScheduleForDate(
        userId: userId,
        date: date,
        workStartTime: start,
        workEndTime: end,
        workdays: workdays,
        commuteMinutes: commuteMinutes,
        jobTitle: jobTitle,
      );
    } catch (error, stackTrace) {
      debugPrint('Routine schedule setup failed: $error\n$stackTrace');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _createEvent(String userId) async {
    await _editEvent(userId, _selectedDay);
  }

  int _suggestedStartMinutes(DateTime date) {
    if (!_isSameDate(date, DateTime.now())) return 9 * 60;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    return (((currentMinutes + 14) ~/ 15) * 15).clamp(0, 1410).toInt();
  }

  void _retrySchedule() {
    setState(() => _scheduleRetryVersion++);
  }

  Future<void> _editEvent(
    String userId,
    DateTime date, [
    QueryDocumentSnapshot<Map<String, dynamic>>? event,
  ]) async {
    if (_isSaving) return;
    final draft = await showDialog<ScheduleEventDraft>(
      context: context,
      builder: (_) => ScheduleEventDialog(
        date: date,
        existing: event,
        initialCategory: 'Life',
        initialStartMinutes: _suggestedStartMinutes(date),
        allowDateChange: event != null,
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final service = FirestoreService();
      final currentEvents = await service
          .scheduleForDate(userId, draft.date)
          .first;
      if (!mounted) return;
      final overlaps = currentEvents.docs.any((current) {
        if (current.id == event?.id) return false;
        final data = current.data();
        final start = _readInt(data['startMinutes'], fallback: 0);
        final end = start + _readInt(data['durationMinutes'], fallback: 0);
        return draft.startMinutes < end &&
            draft.startMinutes + draft.durationMinutes > start;
      });
      if (overlaps) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That time overlaps another block.')),
        );
        return;
      }

      if (event == null) {
        await service.createScheduleEvent(
          userId: userId,
          title: draft.title,
          category: draft.category,
          date: draft.date,
          startMinutes: draft.startMinutes,
          durationMinutes: draft.durationMinutes,
          notes: draft.notes,
        );
      } else {
        await service.updateScheduleEvent(
          userId: userId,
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
        setState(() => _selectedDate = draft.date);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event == null ? 'Time block added.' : 'Time block updated.',
            ),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Schedule event save failed: $error\n$stackTrace');
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
    String userId,
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
        content: Text('“$title” will be removed from this day’s plan.'),
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
        userId: userId,
        eventId: event.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time block deleted.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Schedule event delete failed: $error\n$stackTrace');
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
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().userDocument(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        if (snapshot.hasData) _seedRoutineForDay(user.uid, data);

        return Scaffold(
          backgroundColor: AppColors.ivory,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR WEEK',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.3,
                                color: AppColors.clayDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Schedule',
                              style: GoogleFonts.fraunces(
                                fontSize: 25,
                                height: 1.15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'A little room for what matters—at\nwork and beyond.',
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
                          onPressed: _isSaving
                              ? null
                              : () => _createEvent(user.uid),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            backgroundColor: AppColors.clay,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor:
                                AppColors.clay.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.add, size: 16),
                          label: const Text('Add activity'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ScheduleCalendarHeader(
                    selectedDate: _selectedDay,
                    onPickDate: _pickDate,
                    onDateSelected: (date) =>
                        setState(() => _selectedDate = date),
                    onPrevious: () => setState(() {
                      _selectedDate = _selectedDay.subtract(
                        const Duration(days: 7),
                      );
                    }),
                    onNext: () => setState(() {
                      _selectedDate = _selectedDay.add(const Duration(days: 7));
                    }),
                  ),
                  const SizedBox(height: 12),
                  _ScheduleDayView(
                    key: ValueKey(
                      'schedule-${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}-$_scheduleRetryVersion',
                    ),
                    userId: user.uid,
                    date: _selectedDay,
                    onToday: () => setState(
                      () => _selectedDate = DateTime.now(),
                    ),
                    isSaving: _isSaving,
                    onEventTap: (event) =>
                        _editEvent(user.uid, _selectedDay, event),
                    onEventDelete: (event) => _deleteEvent(user.uid, event),
                    onRetry: _retrySchedule,
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: const _ScheduleNavigationBar(),
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
}

class _ScheduleCalendarHeader extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPickDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ScheduleCalendarHeader({
    required this.selectedDate,
    required this.onPickDate,
    required this.onDateSelected,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));
    final range = weekStart.month == weekEnd.month
        ? '${_monthName(weekStart.month)} ${weekStart.day}–${weekEnd.day}, ${weekEnd.year}'
        : '${_monthName(weekStart.month)} ${weekStart.day} – ${_monthName(weekEnd.month)} ${weekEnd.day}, ${weekEnd.year}';
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _WeekArrowButton(
                tooltip: 'Previous week',
                icon: Icons.chevron_left,
                onPressed: onPrevious,
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onPickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Text(
                      range,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              _WeekArrowButton(
                tooltip: 'Next week',
                icon: Icons.chevron_right,
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 2),
          _SlidingWeekDays(
            weekStart: weekStart,
            selectedDate: selectedDate,
            today: today,
            onDateSelected: onDateSelected,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        ],
      ),
    );
  }

}

class _SlidingWeekDays extends StatefulWidget {
  const _SlidingWeekDays({
    required this.weekStart,
    required this.selectedDate,
    required this.today,
    required this.onDateSelected,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<_SlidingWeekDays> createState() => _SlidingWeekDaysState();
}

class _SlidingWeekDaysState extends State<_SlidingWeekDays> {
  double _dragDistance = 0;
  double _slideDirection = 1;

  @override
  void didUpdateWidget(covariant _SlidingWeekDays oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDate(oldWidget.weekStart, widget.weekStart)) {
      _slideDirection = widget.weekStart.isAfter(oldWidget.weekStart) ? 1 : -1;
    }
  }

  void _finishSwipe(DragEndDetails details) {
    final distance = _dragDistance;
    _dragDistance = 0;
    final velocity = details.primaryVelocity ?? 0;
    if (distance <= -24) {
      widget.onNext();
    } else if (distance >= 24) {
      widget.onPrevious();
    } else if (velocity < -250) {
      widget.onNext();
    } else if (velocity > 250) {
      widget.onPrevious();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _dragDistance = 0,
        onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
        onHorizontalDragEnd: _finishSwipe,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: Offset(_slideDirection * 0.14, 0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Row(
            key: ValueKey(
              '${widget.weekStart.year}-${widget.weekStart.month}-${widget.weekStart.day}',
            ),
            children: List.generate(7, (index) {
              final date = widget.weekStart.add(Duration(days: index));
              final selected = _isSameDate(date, widget.selectedDate);
              final isToday = _isSameDate(date, widget.today);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Material(
                    color: selected
                        ? AppColors.eucalyptusDark
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.onDateSelected(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _shortWeekday(date.weekday),
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppColors.sub,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${date.day}',
                            style: GoogleFonts.fraunces(
                              fontSize: 14,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? (selected
                                        ? AppColors.peach
                                        : AppColors.clay)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _WeekArrowButton extends StatelessWidget {
  const _WeekArrowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    icon: Icon(icon, size: 17, color: AppColors.ink),
  );
}

class _ScheduleDayView extends StatefulWidget {
  final String userId;
  final DateTime date;
  final VoidCallback onToday;
  final bool isSaving;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onEventTap;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>>
  onEventDelete;
  final VoidCallback onRetry;

  const _ScheduleDayView({
    super.key,
    required this.userId,
    required this.date,
    required this.onToday,
    required this.isSaving,
    required this.onEventTap,
    required this.onEventDelete,
    required this.onRetry,
  });

  @override
  State<_ScheduleDayView> createState() => _ScheduleDayViewState();
}

class _ScheduleDayViewState extends State<_ScheduleDayView> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _scheduleStream;

  @override
  void initState() {
    super.initState();
    _scheduleStream = FirestoreService().scheduleForDate(
      widget.userId,
      widget.date,
    );
  }

  @override
  void didUpdateWidget(covariant _ScheduleDayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId ||
        !DateUtils.isSameDay(widget.date, oldWidget.date)) {
      _scheduleStream = FirestoreService().scheduleForDate(
        widget.userId,
        widget.date,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _scheduleStream,
      builder: (context, snapshot) {
        final events = [...?snapshot.data?.docs]
          ..sort((a, b) {
            final aStart = _readInt(a.data()['startMinutes'], fallback: 0);
            final bStart = _readInt(b.data()['startMinutes'], fallback: 0);
            return aStart.compareTo(bStart);
          });
        final canEdit =
            snapshot.hasData && !snapshot.hasError && !widget.isSaving;
        final isToday = DateUtils.isSameDay(widget.date, DateTime.now());
        final title = isToday
            ? 'Today’s schedule'
            : '${_shortWeekday(widget.date.weekday)}, '
                  '${_monthName(widget.date.month)} ${widget.date.day}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  onPressed: widget.onToday,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.clayDark,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Today'),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 15),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (snapshot.hasError)
              _ScheduleRetryCard(onRetry: widget.onRetry)
            else if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (events.isEmpty)
              const _ScheduleEmptyCard()
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < events.length; index++) ...[
                      _ScheduleListRow(
                        event: events[index],
                        enabled: canEdit,
                        onEdit: () => widget.onEventTap(events[index]),
                        onDelete: () => widget.onEventDelete(events[index]),
                      ),
                      if (index < events.length - 1)
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

class _ScheduleListRow extends StatelessWidget {
  const _ScheduleListRow({
    required this.event,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> event;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final data = event.data();
    final start =
        _readInt(data['startMinutes'], fallback: 0).clamp(0, 1439).toInt();
    final duration = _readInt(data['durationMinutes'], fallback: 0);
    final category = _displayArea(data['category']?.toString() ?? 'Life');
    final title = data['title']?.toString() ?? 'Untitled block';
    final compact = MediaQuery.sizeOf(context).width < 360;
    final timeWidth = compact ? 54.0 : 68.0;
    final actionSize = compact ? 30.0 : 34.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: 9,
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatEventTime(start),
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
              color: _scheduleCategoryColor(category),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: compact ? 7 : 10),
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
          if (compact)
            PopupMenuButton<String>(
              tooltip: 'Time block options',
              enabled: enabled,
              padding: EdgeInsets.zero,
              iconSize: 18,
              onSelected: (action) {
                if (action == 'edit') onEdit();
                if (action == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit time block')),
                PopupMenuItem(value: 'delete', child: Text('Delete time block')),
              ],
              child: SizedBox(
                width: actionSize,
                height: actionSize,
                child: const Icon(Icons.more_horiz, size: 18),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Edit time block',
              onPressed: enabled ? onEdit : null,
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tightFor(
                width: actionSize,
                height: actionSize,
              ),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.edit_outlined, size: 17),
              color: AppColors.eucalyptusDark,
            ),
            IconButton(
              tooltip: 'Delete time block',
              onPressed: enabled ? onDelete : null,
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints.tightFor(
                width: actionSize,
                height: actionSize,
              ),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.delete_outline, size: 17),
              color: AppColors.clayDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleEmptyCard extends StatelessWidget {
  const _ScheduleEmptyCard();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 23),
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
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.sub),
        ),
      ],
    ),
  );
}

class _ScheduleRetryCard extends StatelessWidget {
  const _ScheduleRetryCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: AppColors.sub, size: 19),
        const SizedBox(width: 10),
        const Expanded(child: Text('Could not load this day’s schedule.')),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

Color _scheduleCategoryColor(String category) {
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

class _ScheduleWeekView extends StatelessWidget {
  final String userId;
  final DateTime weekStart;
  final void Function(DateTime, QueryDocumentSnapshot<Map<String, dynamic>>)
  onEventTap;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>>
  onEventLongPress;
  final ValueChanged<DateTime> onAdd;

  const _ScheduleWeekView({
    required this.userId,
    required this.weekStart,
    required this.onEventTap,
    required this.onEventLongPress,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 7; index++)
          _ScheduleWeekDay(
            userId: userId,
            date: weekStart.add(Duration(days: index)),
            onAdd: onAdd,
            onEventTap: onEventTap,
            onEventLongPress: onEventLongPress,
          ),
      ],
    );
  }
}

class _ScheduleWeekDay extends StatelessWidget {
  final String userId;
  final DateTime date;
  final ValueChanged<DateTime> onAdd;
  final void Function(DateTime, QueryDocumentSnapshot<Map<String, dynamic>>)
  onEventTap;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>>
  onEventLongPress;

  const _ScheduleWeekDay({
    required this.userId,
    required this.date,
    required this.onAdd,
    required this.onEventTap,
    required this.onEventLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().scheduleForDate(userId, date),
      builder: (context, snapshot) {
        final events = snapshot.data?.docs ?? [];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isToday ? AppColors.eucalyptus : AppColors.line,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_weekdayName(date.weekday)} ${MaterialLocalizations.of(context).formatMediumDate(date)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? AppColors.eucalyptusDark
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    snapshot.hasError
                        ? 'Unavailable'
                        : '${events.length} events',
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: AppColors.sub,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add event on this day',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onAdd(date),
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              if (snapshot.hasError)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Events could not be loaded.'),
                )
              else if (!snapshot.hasData)
                const LinearProgressIndicator(minHeight: 2)
              else if (events.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Nothing scheduled',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.sub,
                      ),
                    ),
                  ),
                )
              else
                for (final event in events)
                  _TimelineEventTile(
                    event: event,
                    compact: true,
                    onTap: () => onEventTap(date, event),
                    onLongPress: () => onEventLongPress(event),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineEventTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> event;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TimelineEventTile({
    required this.event,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = event.data();
    final rawStart = _formatEventTime(_readInt(data['startMinutes']));
    final timeParts = rawStart.split(' ');
    final duration = _readInt(data['durationMinutes']);
    final title = data['title']?.toString() ?? 'Untitled event';
    final category = _displayArea(data['category']?.toString() ?? 'Life');
    final notes = data['notes']?.toString().trim() ?? '';
    final color = _eventColor(category);
    final eventSurface = _eventSurfaceColor(category);
    final detail = notes.isEmpty ? '$duration min' : '$notes · $duration min';

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 39,
              child: Padding(
                padding: const EdgeInsets.only(top: 7, right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeParts.first,
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      timeParts.length > 1 ? timeParts[1] : '',
                      style: GoogleFonts.inter(
                        fontSize: 7,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: eventSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 2.5,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              9,
                              compact ? 7 : 8,
                              4,
                              compact ? 7 : 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category.toUpperCase(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 6.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.65,
                                          color: AppColors.sub,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        detail,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 7.5,
                                          color: AppColors.sub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: IconButton(
                                    tooltip: 'Event options',
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 28,
                                    ),
                                    onPressed: onLongPress,
                                    icon: const Icon(
                                      Icons.more_horiz,
                                      size: 17,
                                      color: AppColors.sub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _readInt(dynamic value, {int fallback = 0}) =>
    value is num ? value.round() : fallback;

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _shortWeekday(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

String _weekdayName(int weekday) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][weekday - 1];

String _formatEventTime(int totalMinutes) {
  final clamped = totalMinutes.clamp(0, 1439);
  final hour24 = clamped ~/ 60;
  final minute = clamped % 60;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:${minute.toString().padLeft(2, '0')} ${hour24 < 12 ? 'AM' : 'PM'}';
}

Color _eventColor(String category) {
  switch (category.toLowerCase()) {
    case 'work':
      return AppColors.clay;
    case 'commute':
      return const Color(0xFFB97C55);
    case 'sleep':
      return AppColors.eucalyptusDark;
    case 'focus':
      return const Color(0xFFC9786D);
    case 'rest':
      return const Color(0xFF788660);
    case 'life':
    case 'meals':
    case 'personal':
      return AppColors.eucalyptusDark;
    default:
      return AppColors.eucalyptusDark;
  }
}

Color _eventSurfaceColor(String category) {
  switch (category.toLowerCase()) {
    case 'work':
      return const Color(0xFFFBF2E5);
    case 'commute':
      return const Color(0xFFF5E9DE);
    case 'sleep':
      return const Color(0xFFEEF0E2);
    case 'focus':
      return const Color(0xFFF7E9E5);
    case 'rest':
      return const Color(0xFFEEF0E2);
    case 'meals':
    case 'life':
    case 'personal':
    default:
      return const Color(0xFFF0F1E4);
  }
}

String _displayArea(String category) {
  final normalized = category.trim();
  return switch (normalized.toLowerCase()) {
    'work' => 'Work',
    'commute' => 'Commute',
    'sleep' => 'Sleep',
    'rest' => 'Rest',
    'meals' => 'Meals',
    'life' => 'Life',
    _ => 'Life',
  };
}

class _ScheduleEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _ScheduleEmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 28,
            color: AppColors.clayDark,
          ),
          const SizedBox(height: 10),
          Text(
            'Nothing scheduled',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add an event to give this day some shape.',
            style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.sub),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Add event'),
          ),
        ],
      ),
    );
  }
}

class _ScheduleLoadError extends StatelessWidget {
  const _ScheduleLoadError();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.line),
    ),
    child: Text(
      'Schedule events could not be loaded. Check your connection and retry.',
      style: GoogleFonts.inter(fontSize: 11, color: AppColors.sub),
    ),
  );
}

class ScheduleEventDraft {
  final String title;
  final String category;
  final DateTime date;
  final int startMinutes;
  final int durationMinutes;
  final String notes;

  const ScheduleEventDraft({
    required this.title,
    required this.category,
    required this.date,
    required this.startMinutes,
    required this.durationMinutes,
    required this.notes,
  });
}

class ScheduleEventDialog extends StatefulWidget {
  final DateTime date;
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;
  final String? initialTitle;
  final String initialCategory;
  final int? initialStartMinutes;
  final bool allowDateChange;

  const ScheduleEventDialog({
    super.key,
    required this.date,
    this.existing,
    this.initialTitle,
    this.initialCategory = 'Life',
    this.initialStartMinutes,
    this.allowDateChange = true,
  });

  @override
  State<ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends State<ScheduleEventDialog> {
  static const _categories = ['Work', 'Commute', 'Sleep', 'Rest', 'Meals', 'Life'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late DateTime _date;
  late int _startMinutes;
  late int _endMinutes;
  late String _category;
  bool _invalidTimeRange = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data() ?? {};
    _title = TextEditingController(
      text: data['title']?.toString() ?? widget.initialTitle?.trim() ?? '',
    );
    _notes = TextEditingController(text: data['notes']?.toString() ?? '');
    _date = widget.date;
    final savedStart = data['startMinutes'];
    _startMinutes = savedStart is num
        ? savedStart.round().clamp(0, 1439).toInt()
        : (widget.initialStartMinutes ?? 9 * 60).clamp(0, 1439).toInt();
    final savedDuration = data['durationMinutes'];
    final duration = savedDuration is num
        ? savedDuration.round().clamp(1, 1440).toInt()
        : 30;
    _endMinutes = (_startMinutes + duration).clamp(1, 1440).toInt();
    final storedCategory =
        data['category']?.toString() ?? widget.initialCategory;
    _category = switch (storedCategory.trim().toLowerCase()) {
      'work' => 'Work',
      'commute' => 'Commute',
      'sleep' => 'Sleep',
      'rest' => 'Rest',
      'meals' => 'Meals',
      _ => 'Life',
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _startMinutes ~/ 60,
        minute: _startMinutes % 60,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _startMinutes = picked.hour * 60 + picked.minute;
        if (_endMinutes <= _startMinutes) {
          _endMinutes = (_startMinutes + 60).clamp(1, 1440).toInt();
        }
        _invalidTimeRange = false;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _endMinutes == 1440 ? 0 : _endMinutes ~/ 60,
        minute: _endMinutes == 1440 ? 0 : _endMinutes % 60,
      ),
      helpText: 'Select end time',
    );
    if (picked != null && mounted) {
      final selectedMinutes = picked.hour * 60 + picked.minute;
      setState(() {
        _endMinutes = selectedMinutes == 0 && _startMinutes > 0
            ? 1440
            : selectedMinutes;
        _invalidTimeRange = _endMinutes <= _startMinutes;
      });
    }
  }

  String _formatStartTime() {
    final hour24 = _startMinutes ~/ 60;
    final minute = _startMinutes % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} ${hour24 < 12 ? 'AM' : 'PM'}';
  }

  String _formatEndTime() {
    if (_endMinutes == 1440) return '12:00 AM';
    final hour24 = _endMinutes ~/ 60;
    final minute = _endMinutes % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} ${hour24 < 12 ? 'AM' : 'PM'}';
  }

  String _suggestedTitle(String category) {
    switch (category) {
      case 'Work':
        return 'Work';
      case 'Sleep':
        return 'Sleep';
      case 'Rest':
        return 'Rest and recharge';
      case 'Commute':
        return 'Commute';
      case 'Life':
        return 'Time for life';
      case 'Meals':
        return 'Meal';
      default:
        return 'Time block';
    }
  }

  void _changeCategory(String category) {
    final oldSuggestion = _suggestedTitle(_category);
    if (_title.text.trim().isEmpty || _title.text.trim() == oldSuggestion) {
      _title.text = _suggestedTitle(category);
    }
    setState(() => _category = category);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_endMinutes <= _startMinutes) {
      setState(() => _invalidTimeRange = true);
      return;
    }
    Navigator.of(context).pop(
      ScheduleEventDraft(
        title: _title.text.trim(),
        category: _category,
        date: _date,
        startMinutes: _startMinutes,
        durationMinutes: _endMinutes - _startMinutes,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.ivory,
      title: Text(
        widget.existing == null ? 'Add schedule event' : 'Edit event',
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
            children: [
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an event title.'
                    : null,
                decoration: InputDecoration(
                  labelText: 'Plan block',
                  hintText: 'e.g. ${_suggestedTitle(_category)}',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Life area',
                  helperText: 'Choose what this time is for.',
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _changeCategory(value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.allowDateChange) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatShortDate(_date),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined, size: 16),
                      label: Text(_formatStartTime()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.flag_outlined, size: 16),
                      label: Text(_formatEndTime()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Set a start and end time. Blocks stay within this day.',
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
                ),
              ),
              if (_invalidTimeRange) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'End time must be after start time.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.clayDark,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Add event' : 'Save changes'),
        ),
      ],
    );
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
          Icon(icon, size: 17, color: AppColors.eucalyptusDark),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.sub),
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

  const _WeekDaysCard({required this.workdays});

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
    final dayPrefix = day.toLowerCase().substring(0, 3);
    return workdays.any((workday) {
      final normalized = workday.trim().toLowerCase();
      return normalized == day.toLowerCase() ||
          (normalized.length >= 3 && normalized.substring(0, 3) == dayPrefix);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
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
                  isWorkday ? Icons.check_rounded : Icons.remove_rounded,
                  size: 16,
                  color: isWorkday ? Colors.white : AppColors.sub,
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
  final String userId;
  final DateTime date;
  final VoidCallback onAdd;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onEventTap;

  const _DailyFlowCard({
    required this.userId,
    required this.date,
    required this.onAdd,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().scheduleForDate(userId, date),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _ScheduleLoadError();
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final events = snapshot.data!.docs;
        if (events.isEmpty) return _ScheduleEmptyState(onAdd: onAdd);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              for (var index = 0; index < events.length; index++)
                _TimelineEventTile(
                  event: events[index],
                  onTap: () => onEventTap(events[index]),
                  onLongPress: () => onEventTap(events[index]),
                ),
            ],
          ),
        );
      },
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
        if (index == 0) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else if (index == 2) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GoalsScreen()),
          );
        } else if (index == 3) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const InsightsScreen()),
          );
        } else if (index == 4) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      },
    );
  }
}
