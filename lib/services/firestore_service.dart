import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> usersCollection() {
    return _firestore.collection('users');
  }

  DocumentReference<Map<String, dynamic>> userDocument(String userId) {
    return usersCollection().doc(userId);
  }

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
    String? notes,
    int? durationMinutes,
  }) {
    return activitiesCollection(userId).add({
      'title': title,
      'category': category,
      'date': _dateKey(date),
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
    String? notes,
    int? durationMinutes,
    required bool completed,
  }) {
    return activitiesCollection(userId).doc(activityId).update({
      'title': title,
      'category': category,
      'date': _dateKey(date),
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

  Future<void> deleteDailyCheckIn({
    required String userId,
    required DateTime date,
  }) {
    return checkInDocument(userId: userId, date: date).delete();
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
    String? category,
  }) {
    return goalsCollection(userId).add({
      'title': title,
      'date': _dateKey(date),
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
    String? category,
    required bool completed,
    required bool active,
  }) {
    return goalsCollection(userId).doc(goalId).update({
      'title': title,
      'date': _dateKey(date),
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
    return scheduleCollection(userId).add({
      'title': title,
      'category': category,
      'date': _dateKey(date),
      'startMinutes': startMinutes,
      'durationMinutes': durationMinutes,
      'notes': notes ?? '',
      'activityId': activityId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
  }) {
    return scheduleCollection(userId).doc(eventId).update({
      'title': title,
      'category': category,
      'date': _dateKey(date),
      'startMinutes': startMinutes,
      'durationMinutes': durationMinutes,
      'notes': notes ?? '',
      'activityId': activityId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteScheduleEvent({
    required String userId,
    required String eventId,
  }) {
    return scheduleCollection(userId).doc(eventId).delete();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
