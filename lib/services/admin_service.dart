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

  /// Reads the profile and record counts available to the verified admin.
  Future<Map<String, dynamic>> loadDashboard() async {
    final userPage = await _firestore
        .collection('users')
        .orderBy(FieldPath.documentId)
        .get();
    final recordCounts = {for (final name in _recordCollections) name: 0};

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
      final userCounts = await Future.wait(
        batch.map(
          (user) => Future.wait(
            _recordCollections.map((collectionName) async {
              final result = await _firestore
                  .collection('users')
                  .doc(user.id)
                  .collection(collectionName)
                  .count()
                  .get();
              return result.count ?? 0;
            }),
          ),
        ),
      );
      for (final counts in userCounts) {
        for (var index = 0; index < _recordCollections.length; index++) {
          final collection = _recordCollections[index];
          recordCounts[collection] = recordCounts[collection]! + counts[index];
        }
      }
    }

    final totalRecords = recordCounts.values.fold<int>(
      0,
      (total, records) => total + records,
    );
    return {
      'totalUsers': userPage.docs.length,
      'totalRecords': totalRecords,
      'recordsByCollection': recordCounts,
    };
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
      query = query.startAfter([pageToken]);
    }

    final page = await query.get();
    return AdminUsersPage(
      users: page.docs.map(_mapProfile).toList(growable: false),
      nextPageToken: page.docs.length == pageSize ? page.docs.last.id : null,
    );
  }

  /// Firestore has no full-text search. Scan profile pages and match locally.
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

  /// Updates editable profile fields. Protected access fields remain untouched.
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
  const AdminUsersPage({
    required this.users,
    required this.nextPageToken,
    this.truncated = false,
  });

  final List<Map<String, dynamic>> users;
  final String? nextPageToken;
  final bool truncated;
}

class AdminUserDetails {
  const AdminUserDetails({required this.profile});

  final Map<String, dynamic> profile;
}
