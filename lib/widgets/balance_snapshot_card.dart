import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/balance_window_calculator.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Shows the allocation of the user's wake-up-anchored 24-hour window.
class BalanceSnapshotCard extends StatefulWidget {
  const BalanceSnapshotCard({
    super.key,
    required this.userId,
    required this.onEditLife,
  });

  final String userId;
  final VoidCallback onEditLife;

  @override
  State<BalanceSnapshotCard> createState() => _BalanceSnapshotCardState();
}

class _BalanceSnapshotCardState extends State<BalanceSnapshotCard>
    with WidgetsBindingObserver {
  final FirestoreService _service = FirestoreService();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _scheduleStream;
  int? _scheduleForStartMillis;
  int? _timerEndMillis;
  Timer? _windowEndTimer;
  BalanceWindowTotals? _latestTotals;
  int? _latestStartMillis;
  int _streamVersion = 0;
  final Map<String, Stream<QuerySnapshot<Map<String, dynamic>>>>
  _historyScheduleStreams = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant BalanceSnapshotCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _scheduleStream = null;
      _scheduleForStartMillis = null;
      _timerEndMillis = null;
      _windowEndTimer?.cancel();
      _latestTotals = null;
      _historyScheduleStreams.clear();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _windowEndTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE7ECD9), Color(0xFFD1DABF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.eucalyptusDark.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.eucalyptusDark.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.balance_outlined,
                  color: AppColors.eucalyptusDark,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance snapshot',
                      style: GoogleFonts.fraunces(
                        fontSize: 19,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'YOUR 24-HOUR WINDOW',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: AppColors.eucalyptusDark,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Past balance windows',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.55),
                  minimumSize: const Size(34, 34),
                  maximumSize: const Size(34, 34),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _showHistory(context),
                icon: const Icon(Icons.history_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'How this is calculated',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.55),
                  minimumSize: const Size(34, 34),
                  maximumSize: const Size(34, 34),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => _showInfo(context),
                icon: const Icon(Icons.info_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            key: ValueKey(_streamVersion),
            stream: _service.currentBalanceWindow(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _RetryInline(
                  title: 'Balance snapshot could not be loaded.',
                  error: snapshot.error,
                  onRetry: _retry,
                  permissionHint:
                      'Deploy the balanceWindows owner rule from firestore.rules to project worklife-bb9e9.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final data = snapshot.data?.data();
              final startAt = _dateTime(data?['startAt']);
              final endAt = _dateTime(data?['endAt']);
              if (data == null || startAt == null || endAt == null) {
                _cancelWindowTimer();
                return const _NoWindow();
              }

              final startMillis = startAt.millisecondsSinceEpoch;
              if (_scheduleForStartMillis != startMillis ||
                  _scheduleStream == null) {
                _scheduleForStartMillis = startMillis;
                _scheduleStream = _service.scheduleForWindow(
                  userId: widget.userId,
                  startAt: startAt,
                  endAt: endAt,
                );
              }
              _armWindowTimer(endAt, startMillis);
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                key: ValueKey(startMillis),
                stream: _scheduleStream,
                builder: (context, scheduleSnapshot) {
                  if (scheduleSnapshot.hasError) {
                    return _RetryInline(
                      title: 'Scheduled activities could not be loaded.',
                      error: scheduleSnapshot.error,
                      onRetry: _retry,
                      permissionHint:
                          'Check the deployed owner rule for the schedule collection.',
                    );
                  }
                  if (!scheduleSnapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final totals = BalanceWindowCalculator.calculate(
                    window: data,
                    startAt: startAt,
                    endAt: endAt,
                    events: _eventMaps(scheduleSnapshot.data!.docs),
                  );
                  _latestTotals = totals;
                  _latestStartMillis = startMillis;
                  final isComplete =
                      data['status'] == 'complete' ||
                      !DateTime.now().isBefore(endAt);
                  _persistTotals(
                    totals: totals,
                    startMillis: startMillis,
                    isComplete: isComplete,
                  );
                  return _windowContent(
                    startAt: startAt,
                    endAt: endAt,
                    totals: totals,
                    isComplete: isComplete,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _streamVersion++;
      _scheduleForStartMillis = null;
      _scheduleStream = null;
    });
  }

  void _armWindowTimer(DateTime endAt, int startMillis) {
    final endMillis = endAt.millisecondsSinceEpoch;
    if (_timerEndMillis == endMillis) return;
    _windowEndTimer?.cancel();
    _timerEndMillis = endMillis;
    final delay = endAt.difference(DateTime.now());
    if (delay <= Duration.zero) return;
    _windowEndTimer = Timer(delay, () {
      final totals = _latestTotals;
      if (totals != null && _latestStartMillis == startMillis) {
        _persistTotals(
          totals: totals,
          startMillis: startMillis,
          isComplete: true,
        );
      }
      if (mounted) setState(() {});
    });
  }

  void _cancelWindowTimer() {
    _windowEndTimer?.cancel();
    _windowEndTimer = null;
    _timerEndMillis = null;
    _latestTotals = null;
    _latestStartMillis = null;
  }

  void _persistTotals({
    required BalanceWindowTotals totals,
    required int startMillis,
    required bool isComplete,
  }) {
    unawaited(() async {
      try {
        if (isComplete) {
          await _service.completeBalanceWindow(
            userId: widget.userId,
            expectedStartMillis: startMillis,
            categoryMinutes: totals.categoryMinutes,
            freeMinutes: totals.freeMinutes,
            overlapMinutes: totals.overlapMinutes,
          );
        }
        await _service.saveBalanceWindowAllocation(
          userId: widget.userId,
          expectedStartMillis: startMillis,
          categoryMinutes: totals.categoryMinutes,
          freeMinutes: totals.freeMinutes,
          overlapMinutes: totals.overlapMinutes,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Balance window totals could not be saved: $error\n$stackTrace',
        );
      }
    }());
  }

  Widget _windowContent({
    required DateTime startAt,
    required DateTime endAt,
    required BalanceWindowTotals totals,
    required bool isComplete,
  }) {
    const workTarget = 11 * 60;
    const sleepTarget = 8 * 60;
    const lifeTarget = 5 * 60;
    final heavy = <(String, int, Color)>[
      if (totals.workLoggedMinutes > workTarget)
        ('Work-heavy', totals.workLoggedMinutes, AppColors.clayDark),
      if (totals.sleepLoggedMinutes > sleepTarget)
        ('Sleep-heavy', totals.sleepLoggedMinutes, AppColors.eucalyptusDark),
      if (totals.lifeLoggedMinutes > lifeTarget)
        ('Life-heavy', totals.lifeLoggedMinutes, const Color(0xFF8A6545)),
    ];
    final slices = [
      _BalanceSlice('Work + commute', totals.workMinutes, AppColors.clayDark),
      _BalanceSlice('Sleep', totals.sleepMinutes, AppColors.eucalyptusDark),
      _BalanceSlice(
        'Personal life',
        totals.lifeMinutes,
        const Color(0xFF8A6545),
      ),
      _BalanceSlice(
        'Free time to allocate',
        totals.freeMinutes,
        const Color(0xFFB4B5A5),
      ),
    ];
    final startLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(startAt.toLocal()));
    final endLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(endAt.toLocal()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 98,
                    height: 98,
                    child: CustomPaint(
                      painter: _BalanceRingPainter(slices: slices),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _duration(totals.freeMinutes),
                        style: GoogleFonts.fraunces(
                          fontSize: 20,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'FREE',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heavy.isEmpty ? 'Within targets' : 'Needs attention',
                    style: GoogleFonts.fraunces(
                      fontSize: 17,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                      color: heavy.isEmpty
                          ? AppColors.eucalyptusDark
                          : AppColors.clayDark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${isComplete ? 'Complete' : 'In progress'}\n$startLabel – $endLabel',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.4,
                      color: AppColors.sub,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (heavy.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: heavy
                .map(
                  (item) => _StatusPill(
                    label: '${item.$1} · ${_duration(item.$2)}',
                    color: item.$3,
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 9,
              runSpacing: 9,
              children: slices
                  .map(
                    (slice) => SizedBox(
                      width: itemWidth,
                      child: _BalanceLegend(
                        color: slice.color,
                        label: slice.label,
                        value: _duration(slice.minutes),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        if (totals.overlapMinutes > 0) ...[
          const SizedBox(height: 10),
          _TimeWarning(
            message:
                '${_duration(totals.overlapMinutes)} of scheduled activities overlap. Each minute is counted once using Work + Commute, then Sleep, then Personal Life.',
          ),
        ],
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: totals.freeMinutes > 0 ? widget.onEditLife : null,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              totals.freeMinutes > 0
                  ? 'Allocate life time'
                  : 'No free time left',
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.eucalyptusDark,
              visualDensity: VisualDensity.compact,
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showInfo(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.ivory,
      title: const Text('About your balance'),
      content: const Text(
        'Your tracking window begins at the wake-up time you confirmed in Daily Check-In and ends 24 hours later. The ring uses scheduled Work + Commute (11-hour target), check-in Sleep (8-hour target), and scheduled Personal Life (5-hour target). Heavy labels use each category’s own scheduled time before overlaps are resolved. The ring counts each overlapping minute once, with Work + Commute taking priority over Sleep, then Personal Life. All remaining minutes stay as Free Time to Allocate.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Future<void> _showHistory(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Past balance windows',
                style: GoogleFonts.fraunces(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _service.balanceWindowHistory(widget.userId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _RetryInline(
                        title: 'Past balance windows could not be loaded.',
                        error: snapshot.error,
                        permissionHint:
                            'Deploy the balanceWindows owner rule from firestore.rules to project worklife-bb9e9.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs =
                        snapshot.data!.docs
                            .where((doc) => doc.id != 'current')
                            .toList()
                          ..sort((a, b) {
                            final aStart = _dateTime(a.data()['startAt']);
                            final bStart = _dateTime(b.data()['startAt']);
                            return (bStart?.compareTo(
                                  aStart ?? DateTime(1970),
                                ) ??
                                0);
                          });
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Completed windows will appear here.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.sub,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();
                        final start = _dateTime(data['startAt']);
                        final end = _dateTime(data['endAt']);
                        final dateLabel = start == null
                            ? 'Saved window'
                            : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(start.toLocal());
                        if (start == null || end == null) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              dateLabel,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Saved window details are unavailable.',
                            ),
                          );
                        }
                        final stream = _historyScheduleStreams.putIfAbsent(
                          doc.id,
                          () => _service.scheduleForWindow(
                            userId: widget.userId,
                            startAt: start,
                            endAt: end,
                          ),
                        );
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          key: ValueKey(doc.id),
                          stream: stream,
                          builder: (context, scheduleSnapshot) {
                            if (scheduleSnapshot.hasError) {
                              final errorDetails = _firestoreErrorMessage(
                                scheduleSnapshot.error,
                                permissionHint:
                                    'Check the deployed owner rule for the schedule collection.',
                              );
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  dateLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Saved totals shown · $errorDetails',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    height: 1.45,
                                    color: AppColors.sub,
                                  ),
                                ),
                              );
                            }
                            final totals = scheduleSnapshot.hasData
                                ? BalanceWindowCalculator.calculate(
                                    window: data,
                                    startAt: start,
                                    endAt: end,
                                    events: _eventMaps(
                                      scheduleSnapshot.data!.docs,
                                    ),
                                  )
                                : null;
                            if (totals != null) {
                              _persistArchivedTotals(doc.id, totals);
                            }
                            final categories = data['categoryMinutes'];
                            final detail = totals != null
                                ? 'Work ${_duration(totals.workMinutes)} · Sleep ${_duration(totals.sleepMinutes)} · Life ${_duration(totals.lifeMinutes)} · Free ${_duration(totals.freeMinutes)}'
                                : categories is Map
                                ? 'Work ${_duration(_integer(categories['workAndCommute']))} · Sleep ${_duration(_integer(categories['sleep']))} · Life ${_duration(_integer(categories['personalLife']))} · Free ${_duration(_integer(data['freeMinutes']))}'
                                : 'Loading saved activity totals…';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                dateLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${_timeLabel(context, start)}–${_timeLabel(context, end)} · $detail',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  height: 1.45,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: AppColors.eucalyptusDark,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  static DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.round());
    return null;
  }

  static List<Map<String, dynamic>> _eventMaps(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) => docs.map((doc) {
    final data = doc.data();
    return <String, dynamic>{
      ...data,
      'id': doc.id,
      'startAt': _dateTime(data['startAt']),
      'endAt': _dateTime(data['endAt']),
    };
  }).toList();

  void _persistArchivedTotals(String windowId, BalanceWindowTotals totals) {
    unawaited(() async {
      try {
        await _service.saveArchivedBalanceWindowAllocation(
          userId: widget.userId,
          windowId: windowId,
          categoryMinutes: totals.categoryMinutes,
          freeMinutes: totals.freeMinutes,
          overlapMinutes: totals.overlapMinutes,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'Past balance window totals could not be saved: $error\n$stackTrace',
        );
      }
    }());
  }

  static int _integer(dynamic value) => value is num ? value.round() : 0;

  static String _timeLabel(BuildContext context, DateTime? value) {
    if (value == null) return '--';
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()));
  }

  static String _duration(int minutes) {
    final safe = minutes.clamp(0, 1440).toInt();
    final hours = safe ~/ 60;
    final remainder = safe % 60;
    if (hours == 0) return '${remainder}m';
    if (remainder == 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }
}

class _BalanceSlice {
  const _BalanceSlice(this.label, this.minutes, this.color);

  final String label;
  final int minutes;
  final Color color;
}

class _BalanceRingPainter extends CustomPainter {
  const _BalanceRingPainter({required this.slices});

  final List<_BalanceSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.shortestSide / 2 - strokeWidth / 2,
    );
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.eucalyptus.withValues(alpha: 0.45);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, backgroundPaint);

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      if (slice.minutes <= 0) continue;
      final sweepAngle = slice.minutes / (24 * 60) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceRingPainter oldDelegate) => true;
}

class _BalanceLegend extends StatelessWidget {
  const _BalanceLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.48),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color == const Color(0xFFB4B5A5)
                  ? AppColors.eucalyptusDark
                  : color,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

class _TimeWarning extends StatelessWidget {
  const _TimeWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1E8),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.clay.withValues(alpha: 0.45)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 17,
          color: AppColors.clayDark,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoWindow extends StatelessWidget {
  const _NoWindow();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.wb_twilight_outlined, color: AppColors.eucalyptusDark),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Confirm your wake-up time in Daily Check-In to start your ring.',
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RetryInline extends StatelessWidget {
  const _RetryInline({
    required this.title,
    this.error,
    this.onRetry,
    this.permissionHint,
  });

  final String title;
  final Object? error;
  final VoidCallback? onRetry;
  final String? permissionHint;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.66),
      borderRadius: BorderRadius.circular(13),
    ),
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
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(
            _firestoreErrorMessage(error, permissionHint: permissionHint),
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.4,
              color: AppColors.sub,
            ),
          ),
        ],
        if (onRetry != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('Retry'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
      ],
    ),
  );
}

String _firestoreErrorMessage(Object? error, {String? permissionHint}) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return permissionHint ??
            'Firestore access was denied by the deployed rules.';
      case 'failed-precondition':
        return 'Firestore requires an index for this query.';
      case 'unauthenticated':
        return 'Your session expired. Sign in again to load balance data.';
      case 'unavailable':
        return 'Firestore is unavailable. Check your connection and retry.';
    }
    return error.message ?? 'Firestore error: ${error.code}.';
  }
  return error?.toString() ?? 'An unknown error occurred.';
}
