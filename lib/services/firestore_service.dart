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
}