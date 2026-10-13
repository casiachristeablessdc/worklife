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
  bool _weekView = false;
  bool _isSaving = false;

  DateTime get _selectedDay =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

  DateTime get _weekStart =>
      _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));

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

  Future<void> _editEvent(
    String userId,
    DateTime date, [
    QueryDocumentSnapshot<Map<String, dynamic>>? event,
  ]) async {
    if (_isSaving) return;
    final draft = await showDialog<_ScheduleEventDraft>(
      context: context,
      builder: (_) =>
          _ScheduleEventDialog(userId: userId, date: date, existing: event),
    );
    if (draft == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final service = FirestoreService();
      final currentEvents = await service
          .scheduleForDate(userId, draft.date)
          .first;
      if (!mounted) return;
      final conflict = currentEvents.docs.any((current) {
        if (current.id == event?.id) return false;
        final data = current.data();
        final existingStart = _readInt(data['startMinutes'], fallback: 0);
        final existingEnd =
            existingStart + _readInt(data['durationMinutes'], fallback: 0);
        final newEnd = draft.startMinutes + draft.durationMinutes;
        return draft.startMinutes < existingEnd && newEnd > existingStart;
      });

      if (conflict) {
        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.ivory,
            title: Text(
              'This overlaps another event',
              style: GoogleFonts.fraunces(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            content: const Text(
              'Save it anyway, or go back and choose another time?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Choose another time'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Save anyway'),
              ),
            ],
          ),
        );
        if (continueAnyway != true || !mounted) return;
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
          activityId: draft.activityId,
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
          activityId: draft.activityId,
        );
      }
      if (mounted) {
        setState(() => _selectedDate = draft.date);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event == null ? 'Event added.' : 'Event updated.'),
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Schedule event save failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this schedule event.')),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: Text(
          'Delete this event?',
          style: GoogleFonts.fraunces(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        content: Text('“${event.data()['title'] ?? 'Event'}” will be removed.'),
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
    if (confirm != true || !mounted) return;
    try {
      await FirestoreService().deleteScheduleEvent(
        userId: userId,
        eventId: event.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event deleted.')));
      }
    } catch (error, stackTrace) {
      debugPrint('Schedule event delete failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this event.')),
        );
      }
    }
  }

  Future<void> _showEventActions(
    String userId,
    QueryDocumentSnapshot<Map<String, dynamic>> event,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.ivory,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit or reschedule'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      await _editEvent(userId, _selectedDay, event);
    } else if (action == 'delete') {
      await _deleteEvent(userId, event);
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
            actions: [
              IconButton(
                tooltip: 'Choose date',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScheduleCalendarHeader(
                  selectedDate: _selectedDay,
                  weekView: _weekView,
                  onModeChanged: (weekView) =>
                      setState(() => _weekView = weekView),
                  onDateSelected: (date) =>
                      setState(() => _selectedDate = date),
                  onPrevious: () => setState(() {
                    _selectedDate = _selectedDay.add(
                      Duration(days: _weekView ? -7 : -1),
                    );
                  }),
                  onNext: () => setState(() {
                    _selectedDate = _selectedDay.add(
                      Duration(days: _weekView ? 7 : 1),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                if (_weekView)
                  _ScheduleWeekView(
                    userId: user.uid,
                    weekStart: _weekStart,
                    onEventTap: (date, event) =>
                        _editEvent(user.uid, date, event),
                    onEventLongPress: (event) =>
                        _showEventActions(user.uid, event),
                    onAdd: (date) => _editEvent(user.uid, date),
                  )
                else
                  _ScheduleDayView(
                    userId: user.uid,
                    date: _selectedDay,
                    onEventTap: (event) =>
                        _editEvent(user.uid, _selectedDay, event),
                    onEventLongPress: (event) =>
                        _showEventActions(user.uid, event),
                    onAdd: () => _createEvent(user.uid),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Your usual work rhythm',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.sub),
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
                  'The circles mark your usual workdays.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 14),
                _WeekDaysCard(workdays: workdays),
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
                  'Events scheduled for ${MaterialLocalizations.of(context).formatMediumDate(_selectedDay)}.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.sub,
                  ),
                ),
                const SizedBox(height: 14),
                _DailyFlowCard(
                  userId: user.uid,
                  date: _selectedDay,
                  onAdd: () => _editEvent(user.uid, _selectedDay),
                  onEventTap: (event) =>
                      _editEvent(user.uid, _selectedDay, event),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _isSaving ? null : () => _createEvent(user.uid),
            backgroundColor: AppColors.clay,
            foregroundColor: Colors.white,
            tooltip: 'Add schedule event',
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add),
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
  final bool weekView;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ScheduleCalendarHeader({
    required this.selectedDate,
    required this.weekView,
    required this.onModeChanged,
    required this.onDateSelected,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekStart = selectedDate.subtract(
      Duration(days: selectedDate.weekday - 1),
    );
    final today = DateTime.now();
    final isToday =
        selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous ${weekView ? 'week' : 'day'}',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                weekView
                    ? '${MaterialLocalizations.of(context).formatMediumDate(weekStart)} – ${MaterialLocalizations.of(context).formatMediumDate(weekStart.add(const Duration(days: 6)))}'
                    : MaterialLocalizations.of(
                        context,
                      ).formatFullDate(selectedDate),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next ${weekView ? 'week' : 'day'}',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Day')),
              ButtonSegment(value: true, label: Text('Week')),
            ],
            selected: {weekView},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: Row(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final selected =
                  date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
              final todayDate =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: selected ? AppColors.eucalyptus : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onDateSelected(date),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdayLetter(date.weekday),
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: selected
                                  ? AppColors.eucalyptusDark
                                  : AppColors.sub,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${date.day}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          if (todayDate)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.clayDark,
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
        if (isToday)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 3),
            child: Text(
              'Today',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: AppColors.eucalyptusDark,
              ),
            ),
          ),
      ],
    );
  }

  static String _weekdayLetter(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _ScheduleDayView extends StatelessWidget {
  final String userId;
  final DateTime date;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>> onEventTap;
  final ValueChanged<QueryDocumentSnapshot<Map<String, dynamic>>>
  onEventLongPress;
  final VoidCallback onAdd;

  const _ScheduleDayView({
    required this.userId,
    required this.date,
    required this.onEventTap,
    required this.onEventLongPress,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().scheduleForDate(userId, date),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ScheduleLoadError();
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final events = snapshot.data!.docs;
        if (events.isEmpty) {
          return _ScheduleEmptyState(onAdd: onAdd);
        }
        return Column(
          children: [
            for (var index = 0; index < events.length; index++)
              _TimelineEventTile(
                event: events[index],
                isLast: index == events.length - 1,
                onTap: () => onEventTap(events[index]),
                onLongPress: () => onEventLongPress(events[index]),
              ),
          ],
        );
      },
    );
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
                    isLast: true,
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
  final bool isLast;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TimelineEventTile({
    required this.event,
    required this.isLast,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = event.data();
    final start = _formatEventTime(_readInt(data['startMinutes']));
    final duration = _readInt(data['durationMinutes']);
    final title = data['title']?.toString() ?? 'Untitled event';
    final category = data['category']?.toString() ?? 'Other';
    final notes = data['notes']?.toString().trim() ?? '';
    final color = _eventColor(category);

    return GestureDetector(
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, compact ? 5 : 8, 4, compact ? 5 : 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 56 : 66,
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    start,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sub,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 2,
                height: compact ? 39 : 52,
                child: ColoredBox(color: isLast ? Colors.transparent : color),
              ),
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_eventIcon(category), size: 16, color: color),
              ),
              const SizedBox(width: 10),
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
                      '$category · $duration min${notes.isEmpty ? '' : ' · $notes'}',
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.sub),
            ],
          ),
        ),
      ),
    );
  }
}

int _readInt(dynamic value) => value is num ? value.round() : 0;

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
      return AppColors.clayDark;
    case 'health':
      return AppColors.eucalyptusDark;
    case 'family day':
    case 'personal':
    case 'personal day':
      return const Color(0xFF54758A);
    case 'leisure':
      return const Color(0xFF8A6545);
    case 'learning':
      return const Color(0xFF6C7040);
    default:
      return AppColors.sub;
  }
}

IconData _eventIcon(String category) {
  switch (category.toLowerCase()) {
    case 'work':
      return Icons.work_outline;
    case 'health':
      return Icons.favorite_border;
    case 'family day':
      return Icons.family_restroom_outlined;
    case 'personal':
    case 'personal day':
      return Icons.person_outline;
    case 'leisure':
      return Icons.spa_outlined;
    case 'learning':
      return Icons.menu_book_outlined;
    default:
      return Icons.event_outlined;
  }
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

class _ScheduleEventDraft {
  final String title;
  final String category;
  final DateTime date;
  final int startMinutes;
  final int durationMinutes;
  final String notes;
  final String? activityId;

  const _ScheduleEventDraft({
    required this.title,
    required this.category,
    required this.date,
    required this.startMinutes,
    required this.durationMinutes,
    required this.notes,
    this.activityId,
  });
}

class _ScheduleEventDialog extends StatefulWidget {
  final String userId;
  final DateTime date;
  final QueryDocumentSnapshot<Map<String, dynamic>>? existing;

  const _ScheduleEventDialog({
    required this.userId,
    required this.date,
    this.existing,
  });

  @override
  State<_ScheduleEventDialog> createState() => _ScheduleEventDialogState();
}

class _ScheduleEventDialogState extends State<_ScheduleEventDialog> {
  static const _categories = [
    'Work',
    'Personal',
    'Health',
    'Leisure',
    'Learning',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _notes;
  late DateTime _date;
  late int _startMinutes;
  late String _category;
  String? _activityId;

  @override
  void initState() {
    super.initState();
    final data = widget.existing?.data() ?? {};
    _title = TextEditingController(text: data['title']?.toString() ?? '');
    _duration = TextEditingController(
      text: (data['durationMinutes'] ?? 30).toString(),
    );
    _notes = TextEditingController(text: data['notes']?.toString() ?? '');
    _date = widget.date;
    _startMinutes = _readInt(data['startMinutes']).clamp(0, 1439);
    _category = _categories.contains(data['category'])
        ? data['category'] as String
        : 'Personal';
    _activityId = data['activityId']?.toString();
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
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
      setState(() => _startMinutes = picked.hour * 60 + picked.minute);
    }
  }

  String _formatStartTime() {
    final hour24 = _startMinutes ~/ 60;
    final minute = _startMinutes % 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} ${hour24 < 12 ? 'AM' : 'PM'}';
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _ScheduleEventDraft(
        title: _title.text.trim(),
        category: _category,
        date: _date,
        startMinutes: _startMinutes,
        durationMinutes: int.parse(_duration.text.trim()),
        notes: _notes.text.trim(),
        activityId: _activityId,
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
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(_date),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_outlined, size: 16),
                      label: Text(_formatStartTime()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _duration,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final duration = int.tryParse(value?.trim() ?? '');
                  return duration == null || duration <= 0
                      ? 'Enter a duration greater than zero.'
                      : null;
                },
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  suffixText: 'minutes',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirestoreService().activitiesForDate(
                  widget.userId,
                  _date,
                ),
                builder: (context, snapshot) {
                  final activities = snapshot.data?.docs ?? [];
                  final safeActivityId =
                      activities.any((activity) => activity.id == _activityId)
                      ? _activityId
                      : null;
                  return DropdownButtonFormField<String?>(
                    initialValue: safeActivityId,
                    decoration: InputDecoration(
                      labelText: 'Linked activity',
                      helperText: snapshot.hasError
                          ? 'Activities unavailable'
                          : !snapshot.hasData
                          ? 'Loading activities…'
                          : 'Optional',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No linked activity'),
                      ),
                      ...activities.map(
                        (activity) => DropdownMenuItem<String?>(
                          value: activity.id,
                          child: Text(
                            activity.data()['title']?.toString() ?? 'Activity',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: snapshot.hasError
                        ? null
                        : (value) => setState(() => _activityId = value),
                  );
                },
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
                  isLast: index == events.length - 1,
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
