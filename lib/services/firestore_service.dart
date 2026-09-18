import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> usersCollection() {
    return _firestore.collection('users');
  }

  DocumentReference<Map<String, dynamic>> userDocument(String userId) {
    return usersCollection().doc(userId);
  }
}