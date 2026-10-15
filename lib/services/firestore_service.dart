import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> usersCollection() {
    return _firestore.collection('users');
  }

  DocumentReference<Map<String, dynamic>> userDocument(String userId) {
    return usersCollection().doc(userId);
  }

  // ---------------------------------------------------------------------------
  // USER PROFILE
  // ---------------------------------------------------------------------------

  Future<void> createUserProfile({
    required String userId,
    required String name,
    required String email,
  }) {
    return userDocument(userId).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBasicProfile({
    required String userId,
    required String name,
    required String jobTitle,
    required String company,
  }) {
    return userDocument(userId).set({
      'name': name.trim(),
      'jobTitle': jobTitle.trim(),
      'company': company.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String jobTitle,
    required String company,
    required String workStartTime,
    required String workEndTime,
    required List<String> workdays,
    required int commuteMinutes,
    required List<String> hobbies,
    required List<String> personalLife,
    required List<String> sideQuests,
    required List<String> customHobbies,
    required List<String> customSideQuests,
    required bool onboardingCompleted,
  }) {
    return userDocument(userId).set({
      'name': name,
      'jobTitle': jobTitle,
      'company': company,
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
      'workdays': workdays,
      'commuteMinutes': commuteMinutes,
      'hobbies': hobbies,
      'personalLife': personalLife,
      'sideQuests': sideQuests,
      'customHobbies': customHobbies,
      'customSideQuests': customSideQuests,
      'onboardingCompleted': onboardingCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isOnboardingCompleted(String userId) async {
    final snapshot = await userDocument(userId).get();
    final data = snapshot.data();

    return data?['onboardingCompleted'] == true;
  }

  Future<void> updateSleepHours({
    required String userId,
    required double sleepHours,
  }) {
    return userDocument(userId).set({
      'sleepHours': sleepHours,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateRestHours({
    required String userId,
    required double restHours,
  }) {
    return userDocument(userId).set({
      'restHours': restHours,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateWorkHours({
    required String userId,
    required String workStartTime,
    required String workEndTime,
  }) {
    return userDocument(userId).set({
      'workStartTime': workStartTime,
      'workEndTime': workEndTime,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateCommuteMinutes({
    required String userId,
    required int commuteMinutes,
  }) {
    return userDocument(userId).set({
      'commuteMinutes': commuteMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // ACTIVITIES
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> activitiesCollection(
    String userId,
  ) {
    return userDocument(userId).collection('activities');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activitiesForDate(
    String userId,
    DateTime date,
  ) {
    final dateKey = _dateKey(date);

    return activitiesCollection(userId)
        .where('date', isEqualTo: dateKey)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activitiesForWeek(
    String userId,
    DateTime weekStart,
  ) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6));

    return activitiesCollection(userId)
        .where('date', isGreaterThanOrEqualTo: _dateKey(start))
        .where('date', isLessThanOrEqualTo: _dateKey(end))
        .orderBy('date')
        .snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> createActivity({
    required String userId,
    required String title,
    required String category,
    required DateTime date,
    required String scheduleEventId,
    String? notes,
    int? durationMinutes,
  }) {
    return activitiesCollection(userId).add({
      'title': title,
      'category': category,
      'date': _dateKey(date),
      'scheduleEventId': scheduleEventId,
      'notes': notes ?? '',
      'durationMinutes': durationMinutes ?? 0,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateActivity({
    required String userId,
    required String activityId,
    required String title,
    required String category,
    required DateTime date,
    required String scheduleEventId,
    String? notes,
    int? durationMinutes,
    required bool completed,
  }) {
    return activitiesCollection(userId).doc(activityId).update({
      'title': title,
      'category': category,
      'date': _dateKey(date),
      'scheduleEventId': scheduleEventId,
      'notes': notes ?? '',
      'durationMinutes': durationMinutes ?? 0,
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateActivityCompletion({
    required String userId,
    required String activityId,
    required bool completed,
  }) {
    return activitiesCollection(userId).doc(activityId).update({
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteActivity({
    required String userId,
    required String activityId,
  }) {
    return activitiesCollection(userId).doc(activityId).delete();
  }

  // ---------------------------------------------------------------------------
  // DAILY ENERGY CHECK-INS
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> checkInsCollection(String userId) {
    return userDocument(userId).collection('checkIns');
  }

  DocumentReference<Map<String, dynamic>> checkInDocument({
    required String userId,
    required DateTime date,
  }) {
    return checkInsCollection(userId).doc(_dateKey(date));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> dailyCheckIn(
    String userId,
    DateTime date,
  ) {
    return checkInDocument(userId: userId, date: date).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> checkInsForWeek(
    String userId,
    DateTime weekStart,
  ) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 6));

    return checkInsCollection(userId)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _dateKey(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: _dateKey(end))
        .snapshots();
  }

  Future<void> createOrUpdateDailyCheckIn({
    required String userId,
    required DateTime date,
    required int energyScore,
    String? note,
  }) {
    return checkInDocument(userId: userId, date: date).set({
      'date': _dateKey(date),
      'energyScore': energyScore,
      'note': note ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveDailyCheckIn({
    required String userId,
    required DateTime date,
    required int energyScore,
    required Map<String, bool> mealStatus,
    required int sleepStartMinutes,
    required int sleepEndMinutes,
    String? mood,
  }) {
    final values = <String, dynamic>{
      'date': _dateKey(date),
      'energyScore': energyScore,
      'mealStatus': mealStatus,
      'sleepStartMinutes': sleepStartMinutes,
      'sleepEndMinutes': sleepEndMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (mood != null) values['mood'] = mood;
    return checkInDocument(
      userId: userId,
      date: date,
    ).set(values, SetOptions(merge: true));
  }

  Future<void> deleteDailyCheckIn({
    required String userId,
    required DateTime date,
  }) {
    return checkInDocument(userId: userId, date: date).delete();
  }

  CollectionReference<Map<String, dynamic>> balanceWindowsCollection(
    String userId,
  ) {
    return userDocument(userId).collection('balanceWindows');
  }

  DocumentReference<Map<String, dynamic>> currentBalanceWindowDocument(
    String userId,
  ) {
    return balanceWindowsCollection(userId).doc('current');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> currentBalanceWindow(
    String userId,
  ) {
    return currentBalanceWindowDocument(userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> balanceWindowHistory(
    String userId,
  ) {
    return balanceWindowsCollection(userId).snapshots();
  }

  Future<void> startBalanceWindow({
    required String userId,
    required DateTime wakeAt,
  }) async {
    final now = DateTime.now();
    if (wakeAt.isAfter(now)) {
      throw ArgumentError('Wake-up time cannot be in the future.');
    }
    if (wakeAt.add(const Duration(hours: 24)).isBefore(now)) {
      throw ArgumentError('Choose a wake-up time within the last 24 hours.');
    }

    final currentRef = currentBalanceWindowDocument(userId);
    final windows = balanceWindowsCollection(userId);
    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(currentRef);
      final currentData = currentSnapshot.data();
      final currentEnd = _timestampDate(currentData?['endAt']);
      final currentStatus = currentData?['status']?.toString();

      if (currentSnapshot.exists &&
          currentStatus == 'active' &&
          currentEnd != null &&
          now.isBefore(currentEnd)) {
        // Repeated check-ins inside the same window never create a second one.
        return;
      }

      DocumentReference<Map<String, dynamic>>? historyRef;
      DocumentSnapshot<Map<String, dynamic>>? historySnapshot;
      if (currentSnapshot.exists && currentData != null) {
        final previousStart = _timestampDate(currentData['startAt']);
        if (previousStart != null) {
          historyRef = windows.doc(
            'window_${previousStart.millisecondsSinceEpoch}',
          );
          historySnapshot = await transaction.get(historyRef);
        }
      }

      if (currentSnapshot.exists && currentData != null) {
        final previousEnd = _timestampDate(currentData['endAt']);
        final archivedData = <String, dynamic>{
          ...currentData,
          'status': 'complete',
          'completedAt':
              currentData['completedAt'] ??
              (previousEnd == null
                  ? Timestamp.fromDate(now)
                  : Timestamp.fromDate(previousEnd)),
          'archivedAt': FieldValue.serverTimestamp(),
        };
        if (historyRef != null && historySnapshot?.exists != true) {
          transaction.set(historyRef, archivedData);
        }
      }

      final endAt = wakeAt.add(const Duration(hours: 24));
      transaction.set(currentRef, {
        'startAt': Timestamp.fromDate(wakeAt),
        'endAt': Timestamp.fromDate(endAt),
        'utcOffsetMinutes': wakeAt.timeZoneOffset.inMinutes,
        'sleepSessionId': _sleepSessionId(wakeAt.millisecondsSinceEpoch),
        'sleepSessionDeleted': false,
        'status': 'active',
        'durationMinutes': 24 * 60,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reanchorBalanceWindow({
    required String userId,
    required DateTime wakeAt,
  }) async {
    final now = DateTime.now();
    if (wakeAt.isAfter(now)) {
      throw ArgumentError('Wake-up time cannot be in the future.');
    }
    if (!wakeAt.add(const Duration(hours: 24)).isAfter(now)) {
      throw ArgumentError('The updated window must still be in progress.');
    }

    final currentRef = currentBalanceWindowDocument(userId);
    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(currentRef);
      final currentData = currentSnapshot.data();
      final endAt = _timestampDate(currentData?['endAt']);
      if (!currentSnapshot.exists ||
          currentData?['status'] != 'active' ||
          endAt == null ||
          !now.isBefore(endAt)) {
        throw StateError('There is no active window to update.');
      }

      transaction.update(currentRef, {
        'startAt': Timestamp.fromDate(wakeAt),
        'endAt': Timestamp.fromDate(wakeAt.add(const Duration(hours: 24))),
        'utcOffsetMinutes': wakeAt.timeZoneOffset.inMinutes,
        'sleepSessionId':
            currentData?['sleepSessionId']?.toString() ??
            _sleepSessionId(wakeAt.millisecondsSinceEpoch),
        'durationMinutes': 24 * 60,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveCurrentBalanceWindowSleep({
    required String userId,
    required DateTime checkInDate,
    required int sleepStartMinutes,
    required int sleepEndMinutes,
  }) async {
    final currentRef = currentBalanceWindowDocument(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(currentRef);
      final window = snapshot.data();
      if (!snapshot.exists || window?['status'] != 'active') return;
      final startAt = _timestampDate(window?['startAt']);
      if (startAt == null) return;

      final previousStart = window?['sleepStartMinutes'];
      final previousEnd = window?['sleepEndMinutes'];
      final unchangedAfterDelete =
          window?['sleepSessionDeleted'] == true &&
          previousStart is num &&
          previousEnd is num &&
          previousStart.round() == sleepStartMinutes &&
          previousEnd.round() == sleepEndMinutes;
      if (unchangedAfterDelete) return;

      final sessionId =
          window?['sleepSessionId']?.toString() ??
          _sleepSessionId(startAt.millisecondsSinceEpoch);
      final sessionRef = scheduleCollection(userId).doc(sessionId);
      final sessionSnapshot = await transaction.get(sessionRef);
      final offsetMinutes = window?['utcOffsetMinutes'] is num
          ? (window!['utcOffsetMinutes'] as num).round()
          : startAt.timeZoneOffset.inMinutes;
      final times = _sleepSessionTimes(
        windowStart: startAt,
        startMinutes: sleepStartMinutes,
        endMinutes: sleepEndMinutes,
        offsetMinutes: offsetMinutes,
      );
      final existingCreatedAt = sessionSnapshot.data()?['createdAt'];
      transaction.update(currentRef, {
        'sleepStartMinutes': sleepStartMinutes,
        'sleepEndMinutes': sleepEndMinutes,
        'sleepSessionId': sessionId,
        'sleepSessionDeleted': false,
        'sleepUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(sessionRef, {
        'title': 'Sleep',
        'category': 'Sleep',
        'date': _dateKey(times.localStart),
        'startMinutes': times.startMinutes,
        'durationMinutes': times.durationMinutes,
        'startAt': Timestamp.fromDate(times.startAt),
        'endAt': Timestamp.fromDate(times.endAt),
        'notes': '',
        'activityId': null,
        'source': 'check-in',
        'checkInDate': _dateKey(checkInDate),
        'sleepWindowStartMillis': startAt.millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': existingCreatedAt ?? FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveBalanceWindowAllocation({
    required String userId,
    required int expectedStartMillis,
    required Map<String, int> categoryMinutes,
    required int freeMinutes,
    required int overlapMinutes,
  }) async {
    final currentRef = currentBalanceWindowDocument(userId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(currentRef);
      final data = snapshot.data();
      final startAt = _timestampDate(data?['startAt']);
      if (!snapshot.exists ||
          (data?['status'] != 'active' && data?['status'] != 'complete') ||
          startAt?.millisecondsSinceEpoch != expectedStartMillis) {
        return;
      }
      final oldCategories = data?['categoryMinutes'];
      final categoriesMatch =
          oldCategories is Map &&
          categoryMinutes.entries.every(
            (entry) => oldCategories[entry.key] == entry.value,
          ) &&
          oldCategories.length == categoryMinutes.length;
      if (categoriesMatch &&
          data?['freeMinutes'] == freeMinutes &&
          data?['overlapMinutes'] == overlapMinutes) {
        return;
      }
      transaction.update(currentRef, {
        'categoryMinutes': categoryMinutes,
        'freeMinutes': freeMinutes,
        'overlapMinutes': overlapMinutes,
        'allocationUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> saveArchivedBalanceWindowAllocation({
    required String userId,
    required String windowId,
    required Map<String, int> categoryMinutes,
    required int freeMinutes,
    required int overlapMinutes,
  }) async {
    final windowRef = balanceWindowsCollection(userId).doc(windowId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(windowRef);
      final data = snapshot.data();
      if (!snapshot.exists || data?['status'] != 'complete') return;
      final oldCategories = data?['categoryMinutes'];
      final categoriesMatch =
          oldCategories is Map &&
          categoryMinutes.entries.every(
            (entry) => oldCategories[entry.key] == entry.value,
          ) &&
          oldCategories.length == categoryMinutes.length;
      if (categoriesMatch &&
          data?['freeMinutes'] == freeMinutes &&
          data?['overlapMinutes'] == overlapMinutes) {
        return;
      }
      transaction.update(windowRef, {
        'categoryMinutes': categoryMinutes,
        'freeMinutes': freeMinutes,
        'overlapMinutes': overlapMinutes,
        'allocationUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> completeBalanceWindow({
    required String userId,
    required int expectedStartMillis,
    required Map<String, int> categoryMinutes,
    required int freeMinutes,
    required int overlapMinutes,
  }) async {
    final currentRef = currentBalanceWindowDocument(userId);
    final now = DateTime.now();
    await _firestore.runTransaction((transaction) async {
      final currentSnapshot = await transaction.get(currentRef);
      final currentData = currentSnapshot.data();
      final startAt = _timestampDate(currentData?['startAt']);
      final endAt = _timestampDate(currentData?['endAt']);
      if (!currentSnapshot.exists ||
          currentData?['status'] != 'active' ||
          startAt?.millisecondsSinceEpoch != expectedStartMillis ||
          endAt == null ||
          now.isBefore(endAt)) {
        return;
      }
      transaction.update(currentRef, {
        'status': 'complete',
        'completedAt': Timestamp.fromDate(now),
        'categoryMinutes': categoryMinutes,
        'freeMinutes': freeMinutes,
        'overlapMinutes': overlapMinutes,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> scheduleForWindow({
    required String userId,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    // Include a generous date margin for long activities and timezone changes.
    final firstDate = DateTime(
      startAt.year,
      startAt.month,
      startAt.day,
    ).subtract(const Duration(days: 2));
    final lastDate = DateTime(
      endAt.year,
      endAt.month,
      endAt.day,
    ).add(const Duration(days: 2));
    return scheduleCollection(userId)
        .where('date', isGreaterThanOrEqualTo: _dateKey(firstDate))
        .where('date', isLessThanOrEqualTo: _dateKey(lastDate))
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // GOALS
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> goalsCollection(String userId) {
    return userDocument(userId).collection('goals');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activeGoals(String userId) {
    return goalsCollection(userId)
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> createGoal({
    required String userId,
    required String title,
    required DateTime date,
    required String scheduleEventId,
    String? category,
  }) {
    return goalsCollection(userId).add({
      'title': title,
      'date': _dateKey(date),
      'scheduleEventId': scheduleEventId,
      'category': category ?? 'Personal',
      'completed': false,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGoal({
    required String userId,
    required String goalId,
    required String title,
    required DateTime date,
    required String scheduleEventId,
    String? category,
    required bool completed,
    required bool active,
  }) {
    return goalsCollection(userId).doc(goalId).update({
      'title': title,
      'date': _dateKey(date),
      'scheduleEventId': scheduleEventId,
      'category': category ?? 'Personal',
      'completed': completed,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGoalCompletion({
    required String userId,
    required String goalId,
    required bool completed,
  }) {
    return goalsCollection(userId).doc(goalId).update({
      'completed': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteGoal({required String userId, required String goalId}) {
    return goalsCollection(userId).doc(goalId).delete();
  }

  Future<void> linkGoalToScheduleEvent({
    required String userId,
    required String goalId,
    required String scheduleEventId,
  }) {
    return goalsCollection(userId).doc(goalId).update({
      'scheduleEventId': scheduleEventId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE EVENTS
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> scheduleCollection(String userId) {
    return userDocument(userId).collection('schedule');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> scheduleForDate(
    String userId,
    DateTime date,
  ) {
    final dateKey = _dateKey(date);

    return scheduleCollection(userId)
        .where('date', isEqualTo: dateKey)
        .orderBy('startMinutes', descending: false)
        .snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> createScheduleEvent({
    required String userId,
    required String title,
    required String category,
    required DateTime date,
    required int startMinutes,
    required int durationMinutes,
    String? notes,
    String? activityId,
  }) {
    final startAt = _scheduleStartAt(date, startMinutes);
    return scheduleCollection(userId).add({
      'title': title,
      'category': category,
      'date': _dateKey(date),
      'startMinutes': startMinutes,
      'durationMinutes': durationMinutes,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(
        startAt.add(Duration(minutes: durationMinutes)),
      ),
      'notes': notes ?? '',
      'activityId': activityId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adds the user's usual work and meal blocks once for this date. Routine
  /// documents use stable IDs, so opening Home again won't duplicate them.
  Future<void> ensureRoutineScheduleForDate({
    required String userId,
    required DateTime date,
    required String workStartTime,
    required String workEndTime,
    required List<String> workdays,
    required int commuteMinutes,
    String jobTitle = '',
  }) async {
    final routineDate = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (routineDate.isBefore(today)) return;

    final dateKey = _dateKey(date);
    final checkIn = await checkInDocument(userId: userId, date: date).get();
    final checkInData = checkIn.data() ?? <String, dynamic>{};
    final workStatus = checkInData['workStatus']?.toString();
    final usualWorkday = workdays.any(
      (day) => _weekdayMatches(day, date.weekday),
    );
    final includeWork =
        workStatus == 'working' || (workStatus != 'leave' && usualWorkday);
    final events = <_RoutineScheduleEntry>[
      const _RoutineScheduleEntry('lunch', 'Lunch', 'Meals', 12 * 60 + 30, 60),
    ];

    var breakfastStart = 8 * 60;
    var dinnerStart = 19 * 60;
    var dinnerDuration = 60;
    if (includeWork) {
      final start = _parseClockMinutes(workStartTime) ?? 9 * 60;
      var end = _parseClockMinutes(workEndTime) ?? 18 * 60;
      if (end <= start) end += 24 * 60;
      end = end.clamp(start + 1, 24 * 60).toInt();
      final commute = commuteMinutes.clamp(0, 240).toInt();
      final role = jobTitle.trim().isEmpty ? 'Work' : jobTitle.trim();
      final departureTime = start - commute;
      if (departureTime < breakfastStart + 30) {
        breakfastStart = (departureTime - 30).clamp(0, breakfastStart).toInt();
      }
      final returnHomeMinutes = end + commute;
      dinnerStart = returnHomeMinutes.clamp(19 * 60, 23 * 60).toInt();
      dinnerDuration = returnHomeMinutes >= 24 * 60
          ? 0
          : (24 * 60 - dinnerStart).clamp(0, 60).toInt();

      if (commute > 0 && start >= commute) {
        events.add(
          _RoutineScheduleEntry(
            'commute_to',
            'Commute to work',
            'Commute',
            start - commute,
            commute,
          ),
        );
      }

      const lunchStart = 12 * 60 + 30;
      const lunchEnd = lunchStart + 60;
      if (start < lunchStart && end > lunchEnd) {
        events.add(
          _RoutineScheduleEntry(
            'work_before_lunch',
            role,
            'Work',
            start,
            lunchStart - start,
          ),
        );
        events.add(
          _RoutineScheduleEntry(
            'work_after_lunch',
            role,
            'Work',
            lunchEnd,
            end - lunchEnd,
          ),
        );
      } else if (start < lunchEnd && end > lunchStart) {
        if (start < lunchStart) {
          events.add(
            _RoutineScheduleEntry(
              'work_before_lunch',
              role,
              'Work',
              start,
              lunchStart - start,
            ),
          );
        }
        if (end > lunchEnd) {
          events.add(
            _RoutineScheduleEntry(
              'work_after_lunch',
              role,
              'Work',
              lunchEnd,
              end - lunchEnd,
            ),
          );
        }
      } else {
        events.add(
          _RoutineScheduleEntry('work_shift', role, 'Work', start, end - start),
        );
      }

      if (commute > 0 && end < 24 * 60) {
        events.add(
          _RoutineScheduleEntry(
            'commute_home',
            'Commute home',
            'Commute',
            end,
            commute.clamp(0, 24 * 60 - end).toInt(),
          ),
        );
      }
    }

    events.add(
      _RoutineScheduleEntry(
        'breakfast',
        'Breakfast',
        'Meals',
        breakfastStart,
        30,
      ),
    );
    events.add(
      _RoutineScheduleEntry(
        'dinner',
        'Dinner',
        'Meals',
        dinnerStart,
        dinnerDuration,
      ),
    );

    final schedule = scheduleCollection(userId);
    final candidates = events
        .where((event) => event.durationMinutes > 0)
        .toList();
    final refs = candidates
        .map((event) => schedule.doc('routine_${dateKey}_${event.type}'))
        .toList();

    final checkInRef = checkInDocument(userId: userId, date: date);
    await _firestore.runTransaction((transaction) async {
      final latestCheckIn = await transaction.get(checkInRef);
      final latestData = latestCheckIn.data() ?? <String, dynamic>{};
      final latestStatus = latestData['workStatus']?.toString();
      final canScheduleWork =
          latestStatus == 'working' ||
          (latestStatus != 'leave' && usualWorkday);
      final latestRemoved =
          (latestData['removedRoutineEvents'] as List? ?? const [])
              .whereType<String>()
              .toSet();
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) {
        snapshots.add(await transaction.get(ref));
      }
      for (var index = 0; index < candidates.length; index++) {
        final event = candidates[index];
        final workEvent =
            event.type.startsWith('work_') || event.type.startsWith('commute_');
        if (latestRemoved.contains(event.type) ||
            (workEvent && !canScheduleWork)) {
          continue;
        }
        final snapshot = snapshots[index];
        final data = {
          'title': event.title,
          'category': event.category,
          'date': dateKey,
          'startMinutes': event.startMinutes,
          'durationMinutes': event.durationMinutes,
          'startAt': Timestamp.fromDate(
            _scheduleStartAt(date, event.startMinutes),
          ),
          'endAt': Timestamp.fromDate(
            _scheduleStartAt(
              date,
              event.startMinutes,
            ).add(Duration(minutes: event.durationMinutes)),
          ),
          'notes': '',
          'activityId': null,
          'source': 'routine',
          'routineType': event.type,
          'userEdited': false,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (!snapshot.exists) {
          transaction.set(refs[index], {
            ...data,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else if (snapshot.data()?['source'] == 'routine' &&
            snapshot.data()?['userEdited'] != true) {
          transaction.update(refs[index], data);
        }
      }
    });
  }

  Future<void> setWorkStatus({
    required String userId,
    required DateTime date,
    required bool working,
  }) async {
    await checkInDocument(userId: userId, date: date).set({
      'date': _dateKey(date),
      'workStatus': working ? 'working' : 'leave',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (working) return;

    final events = await scheduleForDate(userId, date).first;
    final workEvents = events.docs.where((doc) {
      final data = doc.data();
      final category = data['category']?.toString().trim().toLowerCase();
      return category == 'work' || category == 'commute';
    });
    final batch = _firestore.batch();
    for (final event in workEvents) {
      batch.delete(event.reference);
    }
    if (workEvents.isNotEmpty) await batch.commit();
  }

  Future<void> updateScheduleEvent({
    required String userId,
    required String eventId,
    required String title,
    required String category,
    required DateTime date,
    required int startMinutes,
    required int durationMinutes,
    String? notes,
    String? activityId,
  }) async {
    final ref = scheduleCollection(userId).doc(eventId);
    final startAt = _scheduleStartAt(date, startMinutes);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw StateError('This scheduled activity no longer exists.');
    }
    final oldData = snapshot.data() ?? <String, dynamic>{};
    final oldDate = oldData['date']?.toString();
    final movedRoutine =
        oldData['source'] == 'routine' && oldDate != _dateKey(date);
    await ref.update({
      'title': title,
      'category': category,
      'date': _dateKey(date),
      'startMinutes': startMinutes,
      'durationMinutes': durationMinutes,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(
        startAt.add(Duration(minutes: durationMinutes)),
      ),
      'notes': notes ?? '',
      'activityId': activityId,
      if (oldData['source'] == 'routine') 'userEdited': true,
      if (movedRoutine) 'source': FieldValue.delete(),
      if (movedRoutine) 'routineType': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (oldData['source'] == 'check-in') {
      await _syncCheckInSleepSession(
        userId: userId,
        eventId: eventId,
        oldData: oldData,
        category: category,
        startMinutes: startMinutes,
        durationMinutes: durationMinutes,
      );
    }
  }

  Future<void> deleteScheduleEvent({
    required String userId,
    required String eventId,
  }) async {
    final ref = scheduleCollection(userId).doc(eventId);
    final event = await ref.get();
    final data = event.data();
    final routineType = data?['routineType']?.toString();
    final date = data?['date']?.toString();
    if (data?['source'] == 'routine' && routineType != null && date != null) {
      final parsed = _parseDateKey(date);
      await checkInDocument(userId: userId, date: parsed).set({
        'date': date,
        'removedRoutineEvents': FieldValue.arrayUnion([routineType]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (data?['source'] == 'check-in') {
      final currentRef = currentBalanceWindowDocument(userId);
      await _firestore.runTransaction((transaction) async {
        final current = await transaction.get(currentRef);
        if (current.data()?['sleepSessionId'] == eventId) {
          transaction.update(currentRef, {
            'sleepSessionDeleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }
    await ref.delete();
  }

  Future<void> _syncCheckInSleepSession({
    required String userId,
    required String eventId,
    required Map<String, dynamic> oldData,
    required String category,
    required int startMinutes,
    required int durationMinutes,
  }) async {
    final currentRef = currentBalanceWindowDocument(userId);
    final checkInDate = oldData['checkInDate']?.toString();
    final checkInRef = checkInDate == null
        ? null
        : checkInDocument(userId: userId, date: _parseDateKey(checkInDate));
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(currentRef);
      final checkIn = checkInRef == null
          ? null
          : await transaction.get(checkInRef);
      final isSleep = category.trim().toLowerCase() == 'sleep';
      final endMinutes = (startMinutes + durationMinutes) % (24 * 60);
      if (current.data()?['sleepSessionId'] == eventId) {
        transaction.update(currentRef, {
          if (isSleep) 'sleepStartMinutes': startMinutes % (24 * 60),
          if (isSleep) 'sleepEndMinutes': endMinutes,
          'sleepSessionDeleted': !isSleep,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (checkInRef != null && checkIn?.exists == true && isSleep) {
        transaction.update(checkInRef, {
          'sleepStartMinutes': startMinutes % (24 * 60),
          'sleepEndMinutes': endMinutes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  DateTime _scheduleStartAt(DateTime date, int startMinutes) => DateTime(
    date.year,
    date.month,
    date.day,
  ).add(Duration(minutes: startMinutes));

  String _sleepSessionId(int windowStartMillis) =>
      'checkin_sleep_$windowStartMillis';

  _SleepSessionTimes _sleepSessionTimes({
    required DateTime windowStart,
    required int startMinutes,
    required int endMinutes,
    required int offsetMinutes,
  }) {
    final start = startMinutes.clamp(0, 1439).toInt();
    final end = endMinutes.clamp(0, 1439).toInt();
    final duration = (end - start + 1440) % 1440;
    if (duration == 0) {
      throw ArgumentError('Sleep start and end times must differ.');
    }
    final localWindowStart = DateTime.fromMillisecondsSinceEpoch(
      windowStart.millisecondsSinceEpoch + offsetMinutes * 60000,
      isUtc: true,
    );
    var localStart = DateTime.utc(
      localWindowStart.year,
      localWindowStart.month,
      localWindowStart.day,
    ).add(Duration(minutes: start));
    if (!localStart.isAfter(localWindowStart)) {
      localStart = localStart.add(const Duration(days: 1));
    }
    final sessionStart = DateTime.fromMillisecondsSinceEpoch(
      localStart.millisecondsSinceEpoch - offsetMinutes * 60000,
      isUtc: true,
    );
    return _SleepSessionTimes(
      localStart: localStart,
      startMinutes: start,
      durationMinutes: duration,
      startAt: sessionStart,
      endAt: sessionStart.add(Duration(minutes: duration)),
    );
  }

  DateTime? _timestampDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.round());
    }
    return null;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  DateTime _parseDateKey(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return DateTime.now();
    return DateTime(
      int.tryParse(parts[0]) ?? DateTime.now().year,
      int.tryParse(parts[1]) ?? DateTime.now().month,
      int.tryParse(parts[2]) ?? DateTime.now().day,
    );
  }

  int? _parseClockMinutes(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 1 ||
        hour > 12 ||
        minute > 59) {
      return null;
    }
    final period = match.group(3)!.toUpperCase();
    if (period == 'AM' && hour == 12) {
      hour = 0;
    } else if (period == 'PM' && hour != 12) {
      hour += 12;
    }
    return hour * 60 + minute;
  }

  bool _weekdayMatches(String day, int weekday) {
    const short = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const full = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final normalized = day.trim().toLowerCase();
    return normalized == short[weekday - 1] || normalized == full[weekday - 1];
  }
}

class _RoutineScheduleEntry {
  const _RoutineScheduleEntry(
    this.type,
    this.title,
    this.category,
    this.startMinutes,
    this.durationMinutes,
  );

  final String type;
  final String title;
  final String category;
  final int startMinutes;
  final int durationMinutes;
}

class _SleepSessionTimes {
  const _SleepSessionTimes({
    required this.localStart,
    required this.startMinutes,
    required this.durationMinutes,
    required this.startAt,
    required this.endAt,
  });

  final DateTime localStart;
  final int startMinutes;
  final int durationMinutes;
  final DateTime startAt;
  final DateTime endAt;
}
