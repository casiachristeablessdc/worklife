import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Summarizes the selected day's scheduled blocks against a 24-hour day.
///
/// This reports planned time only. It deliberately leaves unscheduled time
/// visible instead of assuming that every minute needs to be filled.
class DayAllocationCard extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> events;
  final int usualWorkMinutes;
  final int usualCommuteMinutes;
  final int sleepTargetMinutes;
  final int restTargetMinutes;

  const DayAllocationCard({
    super.key,
    required this.events,
    this.usualWorkMinutes = 0,
    this.usualCommuteMinutes = 0,
    this.sleepTargetMinutes = 0,
    this.restTargetMinutes = 0,
  });

  @override
  Widget build(BuildContext context) {
    final slots = events.map(_DaySlot.fromDocument).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final categoryMinutes = <String, int>{};
    var totalMinutes = 0;
    var scheduledSleepMinutes = 0;
    var scheduledWorkMinutes = 0;
    var scheduledCommuteMinutes = 0;
    var mealMinutes = 0;
    var lifeMinutes = 0;
    var invalidBlocks = 0;
    var furthestEnd = 0;
    var hasOverlap = false;
    var occupiedMinutes = 0;

    for (final slot in slots) {
      if (slot.duration <= 0 || slot.start < 0 || slot.start >= 1440) {
        invalidBlocks++;
        continue;
      }

      final end = slot.start + slot.duration;
      if (end > 1440) invalidBlocks++;
      final boundedEnd = end.clamp(0, 1440).toInt();
      if (slot.start < furthestEnd) hasOverlap = true;
      if (boundedEnd > furthestEnd) {
        occupiedMinutes +=
            boundedEnd - (slot.start > furthestEnd ? slot.start : furthestEnd);
        furthestEnd = boundedEnd;
      }

      totalMinutes += slot.duration;
      final key = _canonicalCategory(slot.category);
      categoryMinutes.update(
        key,
        (value) => value + slot.duration,
        ifAbsent: () => slot.duration,
      );

      if (key == 'Sleep') scheduledSleepMinutes += slot.duration;
      if (key == 'Work') scheduledWorkMinutes += slot.duration;
      if (key == 'Commute') scheduledCommuteMinutes += slot.duration;
      if (key == 'Meals') mealMinutes += slot.duration;
      if ({
        'Side quest',
        'Rest',
        'Family',
        'Health',
        'Personal',
      }.contains(key)) {
        lifeMinutes += slot.duration;
      }
    }

    final freeMinutes = (1440 - occupiedMinutes).clamp(0, 1440).toInt();
    final sleepMinutes = scheduledSleepMinutes > 0
        ? scheduledSleepMinutes
        : sleepTargetMinutes;
    final workMinutes =
        scheduledWorkMinutes +
        scheduledCommuteMinutes +
        (events.isEmpty ? usualWorkMinutes + usualCommuteMinutes : 0);
    final awakeMinutes = (1440 - sleepMinutes).clamp(1, 1440).toInt();
    final workShare = workMinutes / awakeMinutes;
    final workHeavy = workMinutes >= 8 * 60 || workShare >= 0.5;
    final hasScheduleProblems = hasOverlap || invalidBlocks > 0;
    final advice = _advice(
      workHeavy: workHeavy,
      workShare: workShare,
      workMinutes: workMinutes,
      sleepMinutes: sleepMinutes,
      mealMinutes: mealMinutes,
      lifeMinutes: lifeMinutes,
      freeMinutes: freeMinutes,
      hasScheduleProblems: hasScheduleProblems,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.eucalyptus,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.timelapse_outlined,
                  size: 19,
                  color: AppColors.eucalyptusDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time balance',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatMinutes(totalMinutes)} planned · ${_formatMinutes(freeMinutes)} open',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '24h',
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: occupiedMinutes / 1440,
              minHeight: 8,
              backgroundColor: AppColors.page,
              color: hasScheduleProblems ? AppColors.clayDark : AppColors.clay,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ...categoryMinutes.entries.map(
                (entry) => _CategoryTimeChip(
                  category: entry.key,
                  minutes: entry.value,
                ),
              ),
              if (scheduledWorkMinutes == 0 && usualWorkMinutes > 0)
                _CategoryTimeChip(
                  category: 'Usual work',
                  minutes: usualWorkMinutes,
                ),
              if (scheduledCommuteMinutes == 0 && usualCommuteMinutes > 0)
                _CategoryTimeChip(
                  category: 'Commute target',
                  minutes: usualCommuteMinutes,
                ),
              if (scheduledSleepMinutes == 0 && sleepTargetMinutes > 0)
                _CategoryTimeChip(
                  category: 'Sleep target',
                  minutes: sleepTargetMinutes,
                ),
              if (!categoryMinutes.containsKey('Rest') && restTargetMinutes > 0)
                _CategoryTimeChip(
                  category: 'Rest target',
                  minutes: restTargetMinutes,
                ),
              if (categoryMinutes.isEmpty &&
                  usualWorkMinutes == 0 &&
                  usualCommuteMinutes == 0 &&
                  sleepTargetMinutes == 0 &&
                  restTargetMinutes == 0)
                _InfoText(
                  'Add time blocks for work, sleep, meals, rest, family, or a side quest.',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: hasScheduleProblems
                  ? const Color(0xFFFFF1E9)
                  : workHeavy
                  ? AppColors.peach
                  : const Color(0xFFF2F5E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasScheduleProblems
                      ? Icons.warning_amber_rounded
                      : workHeavy
                      ? Icons.lightbulb_outline_rounded
                      : Icons.auto_awesome_outlined,
                  size: 17,
                  color: hasScheduleProblems
                      ? AppColors.clayDark
                      : AppColors.eucalyptusDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    advice,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      height: 1.4,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'The bar counts timed schedule blocks. Profile work, sleep, and rest targets are shown separately until you place them in the day.',
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub),
          ),
        ],
      ),
    );
  }

  static String _advice({
    required bool workHeavy,
    required double workShare,
    required int workMinutes,
    required int sleepMinutes,
    required int mealMinutes,
    required int lifeMinutes,
    required int freeMinutes,
    required bool hasScheduleProblems,
  }) {
    if (hasScheduleProblems) {
      return 'Some saved blocks overlap or run past midnight. Edit those blocks so the daily plan fits cleanly within 24 hours.';
    }
    if (workHeavy) {
      final percent = (workShare * 100).round().clamp(0, 100).toInt();
      final shareOf = sleepMinutes == 0
          ? 'of the 24-hour day'
          : 'of planned awake time';
      if (lifeMinutes == 0) {
        return 'Work and commute take about $percent% $shareOf. Try protecting 30 minutes for an outdoor walk, a side quest, or family time.';
      }
      if (mealMinutes == 0) {
        return 'Work takes a large share of planned awake time. Add a real meal break away from work if you can.';
      }
      return 'Work takes a large share of planned awake time. Keep a little room for a walk, family time, or recovery around your meal break.';
    }
    if (sleepMinutes == 0) {
      return 'Sleep is not on today’s plan yet. Add a sleep block if useful; you do not need to fill every open hour.';
    }
    if (mealMinutes == 0 && workMinutes > 0) {
      return 'There is no meal block yet. A short lunch break can make a workday plan more realistic.';
    }
    if (lifeMinutes == 0 && workMinutes > 0) {
      return 'Your plan has work but no time marked for life outside work. Consider a small side quest, movement, or family block.';
    }
    if (freeMinutes >= 60) {
      return 'You have ${_formatMinutes(freeMinutes)} open. Keep some of it flexible, or use a small part for something that restores you.';
    }
    return 'Your main life areas have time on the plan. Leave a little breathing room where you can.';
  }

  static String _canonicalCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'work':
        return 'Work';
      case 'sleep':
        return 'Sleep';
      case 'meal':
      case 'meals':
      case 'eat':
      case 'eating':
        return 'Meals';
      case 'rest':
      case 'recovery':
        return 'Rest';
      case 'family':
      case 'family time':
      case 'family day':
        return 'Family';
      case 'commute':
      case 'travel':
        return 'Commute';
      case 'leisure':
      case 'side quest':
        return 'Side quest';
      case 'health':
      case 'exercise':
        return 'Health';
      case 'learning':
        return 'Learning';
      case 'personal':
      case 'personal day':
        return 'Personal';
      default:
        return category.trim().isEmpty ? 'Other' : category.trim();
    }
  }

  static String _formatMinutes(int minutes) {
    final bounded = minutes.clamp(0, 100000).toInt();
    final hours = bounded ~/ 60;
    final remainder = bounded % 60;
    if (hours == 0) return '${remainder}m';
    if (remainder == 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }
}

class _DaySlot {
  final int start;
  final int duration;
  final String category;

  const _DaySlot({
    required this.start,
    required this.duration,
    required this.category,
  });

  factory _DaySlot.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return _DaySlot(
      start: data['startMinutes'] is num
          ? (data['startMinutes'] as num).round()
          : -1,
      duration: data['durationMinutes'] is num
          ? (data['durationMinutes'] as num).round()
          : 0,
      category: data['category']?.toString() ?? 'Other',
    );
  }
}

class _CategoryTimeChip extends StatelessWidget {
  final String category;
  final int minutes;

  const _CategoryTimeChip({required this.category, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _color(category).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$category · ${DayAllocationCard._formatMinutes(minutes)}',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _color(category),
        ),
      ),
    );
  }

  Color _color(String category) {
    switch (category.toLowerCase()) {
      case 'work':
      case 'usual work':
        return AppColors.clayDark;
      case 'sleep':
      case 'sleep target':
      case 'rest':
      case 'rest target':
        return AppColors.eucalyptusDark;
      case 'family':
        return const Color(0xFF54758A);
      case 'side quest':
      case 'leisure':
        return const Color(0xFF8A6545);
      case 'meals':
        return const Color(0xFF8A6545);
      case 'commute target':
      case 'commute':
        return const Color(0xFF54758A);
      default:
        return AppColors.sub;
    }
  }
}

class _InfoText extends StatelessWidget {
  final String text;

  const _InfoText(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: GoogleFonts.inter(fontSize: 10, color: AppColors.sub));
}
