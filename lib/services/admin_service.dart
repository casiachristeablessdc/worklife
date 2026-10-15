import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  AdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _recordCollections = [
    'activities',
    'checkIns',
    'goals',
    'schedule',
  ];
  static const _userPageSize = 50;
  final FirebaseFirestore _firestore;

  /// Counts profile documents and per-user WorkLife subcollection records.
  /// This uses only Firestore reads authorized by the current user's rules.
  Future<Map<String, dynamic>> loadDashboard() async {
    final userPage = await _firestore
        .collection('users')
        .orderBy(FieldPath.documentId)
        .get();
    var recordCount = 0;

    // Bound concurrent aggregate requests so larger profile lists do not
    // create an unbounded burst of Firestore traffic.
    const usersPerBatch = 8;
    for (
      var offset = 0;
      offset < userPage.docs.length;
      offset += usersPerBatch
    ) {
      final end = offset + usersPerBatch < userPage.docs.length
          ? offset + usersPerBatch
          : userPage.docs.length;
      final batch = userPage.docs.sublist(offset, end);
      final counts = await Future.wait(
        batch.expand(
          (user) => _recordCollections.map((collectionName) async {
            final result = await _firestore
                .collection('users')
                .doc(user.id)
                .collection(collectionName)
                .count()
                .get();
            return result.count ?? 0;
          }),
        ),
      );
      recordCount += counts.fold<int>(0, (total, value) => total + value);
    }

    return {'totalUsers': userPage.docs.length, 'totalRecords': recordCount};
  }

  Future<AdminUsersPage> listUsers({
    String? pageToken,
    int pageSize = _userPageSize,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .orderBy(FieldPath.documentId)
        .limit(pageSize);
    if (pageToken != null && pageToken.isNotEmpty) {
      final cursor = await _firestore.collection('users').doc(pageToken).get();
      if (cursor.exists) query = query.startAfterDocument(cursor);
    }

    final page = await query.get();
    return AdminUsersPage(
      users: page.docs.map(_mapProfile).toList(growable: false),
      nextPageToken: page.docs.length == pageSize ? page.docs.last.id : null,
    );
  }

  /// Firestore does not provide full-text search. Fetches real profile pages
  /// and filters name, email, and document ID locally for complete results.
  Future<AdminUsersPage> searchUsers(String query) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return listUsers();

    final users = <Map<String, dynamic>>[];
    String? pageToken;
    do {
      final page = await listUsers(pageToken: pageToken, pageSize: 100);
      users.addAll(page.users);
      pageToken = page.nextPageToken;
    } while (pageToken != null);

    final matches = users
        .where(
          (user) =>
              (user['name'] as String).toLowerCase().contains(term) ||
              (user['email'] as String).toLowerCase().contains(term) ||
              (user['uid'] as String).toLowerCase().contains(term),
        )
        .toList(growable: false);
    return AdminUsersPage(users: matches, nextPageToken: null);
  }

  Future<AdminUserDetails> loadUserDetails(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    if (!snapshot.exists) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'The user profile no longer exists.',
      );
    }
    return AdminUserDetails(profile: _mapProfile(snapshot));
  }

  /// Updates only ordinary profile fields. Account and admin fields are never
  /// writable through this client operation.
  Future<void> updateUser({
    required String uid,
    required String name,
    String jobTitle = '',
    String company = '',
  }) {
    return _firestore.collection('users').doc(uid).update({
      'name': name.trim(),
      'jobTitle': jobTitle.trim(),
      'company': company.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> _mapProfile(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return {
      'uid': snapshot.id,
      'name': (data['name'] ?? data['displayName'] ?? '').toString().trim(),
      'email': (data['email'] ?? '').toString().trim(),
      'jobTitle': (data['jobTitle'] ?? '').toString().trim(),
      'company': (data['company'] ?? '').toString().trim(),
      'photoURL': (data['photoURL'] ?? data['photoUrl'] ?? '').toString(),
    };
  }
}

String adminServiceErrorMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Firestore denied this request. Sign in again with the verified admin account and confirm its admin access.';
      case 'unauthenticated':
        return 'Your session has expired. Sign in again to continue.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Firestore is temporarily unavailable. Check your connection and try again.';
      case 'not-found':
        return error.message ??
            'The requested Firebase record could not be found.';
      default:
        return error.message?.isNotEmpty == true
            ? error.message!
            : 'Firestore could not complete that request.';
    }
  }
  return 'Firestore could not complete that request. Please try again.';
}

class AdminUsersPage {
  const AdminUsersPage({required this.users, required this.nextPageToken});

  final List<Map<String, dynamic>> users;
  final String? nextPageToken;
}

class AdminUserDetails {
  const AdminUserDetails({required this.profile});

  final Map<String, dynamic> profile;
}
