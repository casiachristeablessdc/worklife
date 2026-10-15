const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {FieldValue, getFirestore} = require('firebase-admin/firestore');
const {getStorage} = require('firebase-admin/storage');
const {HttpsError, onCall} = require('firebase-functions/v2/https');

initializeApp();

const db = getFirestore();
const auth = getAuth();
const FUNCTION_OPTIONS = {
  region: 'asia-southeast1',
  timeoutSeconds: 300,
  memory: '1GiB',
};

function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to continue.');
  }

  if (request.auth.token.email_verified !== true ||
      request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Administrator access required.');
  }
}

function serializeAuthUser(user, profile = {}) {
  return {
    uid: user.uid,
    email: user.email || '',
    displayName: profile.name || user.displayName || '',
    photoURL: profile.photoUrl || user.photoURL || '',
    jobTitle: profile.jobTitle || '',
    company: profile.company || '',
    emailVerified: user.emailVerified,
    disabled: user.disabled,
    isAdmin: user.customClaims?.admin === true,
    createdAt: user.metadata.creationTime || null,
    lastSignInAt: user.metadata.lastSignInTime || null,
  };
}

async function profilesForUsers(users) {
  if (users.length === 0) return [];
  const refs = users.map((user) => db.collection('users').doc(user.uid));
  const snapshots = await db.getAll(...refs);
  return snapshots.map((snapshot) => snapshot.data() || {});
}

function normalizeSearchText(value) {
  return typeof value === 'string' ? value.trim().toLocaleLowerCase() : '';
}

async function countAuthUsers() {
  let count = 0;
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    count += page.users.length;
    pageToken = page.pageToken;
  } while (pageToken);
  return count;
}

exports.getAdminDashboard = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);

  const [totalUsers, goals, activities, scheduleEvents, checkIns] = await Promise.all([
    countAuthUsers(),
    db.collectionGroup('goals').count().get(),
    db.collectionGroup('activities').count().get(),
    db.collectionGroup('schedule').count().get(),
    db.collectionGroup('checkIns').count().get(),
  ]);

  const totalRecords = goals.data().count + activities.data().count +
    scheduleEvents.data().count + checkIns.data().count;
  return {
    totalUsers,
    totalRecords,
  };
});

exports.createAdminUser = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);
  const {email, password, name, jobTitle = '', company = ''} = request.data || {};
  if (typeof email !== 'string' || !email.trim() ||
      typeof password !== 'string' || password.length < 8 ||
      typeof name !== 'string' || !name.trim() ||
      typeof jobTitle !== 'string' || typeof company !== 'string') {
    throw new HttpsError('invalid-argument', 'Enter a valid email, name, and password of at least 8 characters.');
  }
  const user = await auth.createUser({
    email: email.trim(),
    password,
    displayName: name.trim(),
    emailVerified: false,
  });
  try {
    await db.collection('users').doc(user.uid).set({
      name: name.trim(),
      email: email.trim(),
      jobTitle: jobTitle.trim(),
      company: company.trim(),
      onboardingCompleted: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    await auth.deleteUser(user.uid);
    throw error;
  }
  let verificationLink = null;
  try {
    verificationLink = await auth.generateEmailVerificationLink(email.trim());
  } catch (error) {
    console.error('Could not generate a new-user verification link.', error);
  }
  return {uid: user.uid, verificationLink};
});

exports.updateAdminUser = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);
  const {uid, name, jobTitle = '', company = ''} = request.data || {};
  if (typeof uid !== 'string' || !uid || typeof name !== 'string' ||
      !name.trim() || typeof jobTitle !== 'string' ||
      typeof company !== 'string') {
    throw new HttpsError('invalid-argument', 'Enter a valid name and profile details.');
  }
  const target = await auth.getUser(uid);
  if (target.customClaims?.admin === true) {
    throw new HttpsError('failed-precondition', 'Administrator profiles cannot be edited here.');
  }
  const profileRef = db.collection('users').doc(uid);
  const previousProfile = await profileRef.get();
  const profileUpdate = {
    name: name.trim(),
    jobTitle: jobTitle.trim(),
    company: company.trim(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  await profileRef.set(profileUpdate, {merge: true});
  try {
    await auth.updateUser(uid, {displayName: name.trim()});
  } catch (error) {
    try {
      if (previousProfile.exists) {
        await profileRef.set(previousProfile.data(), {merge: false});
      } else {
        await profileRef.delete();
      }
    } catch (rollbackError) {
      console.error('Could not roll back an admin profile update.', rollbackError);
    }
    throw error;
  }
  return {uid};
});

exports.deleteAdminUser = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);
  const uid = request.data?.uid;
  if (typeof uid !== 'string' || !uid || uid === request.auth.uid) {
    throw new HttpsError('failed-precondition', 'Choose another user account to delete.');
  }
  const target = await auth.getUser(uid);
  if (target.customClaims?.admin === true) {
    throw new HttpsError('failed-precondition', 'Administrator accounts cannot be deleted here.');
  }
  // Mark deletion in progress first. If a later cleanup step fails, the account
  // is blocked and this callable can safely be retried without allowing sign-in.
  await auth.updateUser(uid, {disabled: true});
  await auth.revokeRefreshTokens(uid);
  await db.collection('users').doc(uid).set({
    accountDisabled: true,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  const profile = db.collection('users').doc(uid);
  await db.recursiveDelete(profile);
  await getStorage().bucket().deleteFiles({prefix: `profile_photos/${uid}/`}).catch((error) => {
    if (error.code !== 404) throw error;
  });
  await auth.deleteUser(uid);
  await db.collection('adminAudit').add({
    action: 'delete_user',
    actorUid: request.auth.uid,
    targetUid: uid,
    targetEmail: target.email || '',
    createdAt: FieldValue.serverTimestamp(),
  });
  return {uid};
});

exports.listAdminUsers = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);
  const pageToken = request.data?.pageToken;
  const requestedPageSize = request.data?.pageSize ?? 50;

  if (pageToken !== undefined &&
      (typeof pageToken !== 'string' || pageToken.length > 4096)) {
    throw new HttpsError('invalid-argument', 'Invalid page token.');
  }
  if (!Number.isInteger(requestedPageSize) ||
      requestedPageSize < 1 || requestedPageSize > 1000) {
    throw new HttpsError('invalid-argument', 'Page size must be between 1 and 1000.');
  }

  const page = await auth.listUsers(requestedPageSize, pageToken);
  const profiles = await profilesForUsers(page.users);
  return {
    users: page.users.map((user, index) =>
      serializeAuthUser(user, profiles[index]),
    ),
    nextPageToken: page.pageToken || null,
  };
});

exports.searchAdminUsers = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);
  const query = normalizeSearchText(request.data?.query);

  if (query.length < 2 || query.length > 120) {
    throw new HttpsError(
      'invalid-argument',
      'Search text must be between 2 and 120 characters.',
    );
  }

  if (query.includes('@')) {
    try {
      const user = await auth.getUserByEmail(query);
      const [profile] = await profilesForUsers([user]);
      return {users: [serializeAuthUser(user, profile)], truncated: false};
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        return {users: [], truncated: false};
      }
      throw error;
    }
  }

  const matches = [];
  const maxScannedUsers = 20000;
  let pageToken;
  let scanned = 0;

  do {
    const remaining = maxScannedUsers - scanned;
    const page = await auth.listUsers(Math.min(1000, remaining), pageToken);
    scanned += page.users.length;
    const profiles = await profilesForUsers(page.users);

    for (let index = 0; index < page.users.length; index += 1) {
      const user = page.users[index];
      const profile = profiles[index];
      const searchable = [user.uid, user.displayName, profile.name, user.email]
          .filter(Boolean)
          .join(' ')
          .toLocaleLowerCase();
      if (searchable.includes(query)) {
        matches.push(serializeAuthUser(user, profile));
        if (matches.length === 100) {
          return {users: matches, truncated: true};
        }
      }
    }

    pageToken = page.pageToken;
  } while (pageToken && scanned < maxScannedUsers);

  return {
    users: matches,
    truncated: Boolean(pageToken),
  };
});

exports.getAdminUserDetails = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);
  const uid = request.data?.uid;

  if (typeof uid !== 'string' || uid.length < 1 || uid.length > 128) {
    throw new HttpsError('invalid-argument', 'A valid user ID is required.');
  }

  const [authUser, profileSnapshot, activities, goals, schedule] =
    await Promise.all([
      auth.getUser(uid).catch((error) => {
        if (error.code === 'auth/user-not-found') {
          throw new HttpsError('not-found', 'User not found.');
        }
        throw error;
      }),
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(uid).collection('activities').count().get(),
      db.collection('users').doc(uid).collection('goals').count().get(),
      db.collection('users').doc(uid).collection('schedule').count().get(),
    ]);

  const profile = profileSnapshot.data() || {};
  return {
    user: serializeAuthUser(authUser),
    profile: {
      name: profile.name || authUser.displayName || '',
      email: profile.email || authUser.email || '',
      jobTitle: profile.jobTitle || '',
      company: profile.company || '',
      photoUrl: profile.photoUrl || authUser.photoURL || '',
      workStartTime: profile.workStartTime || '',
      workEndTime: profile.workEndTime || '',
      workdays: Array.isArray(profile.workdays) ? profile.workdays : [],
      commuteMinutes: Number.isFinite(profile.commuteMinutes) ?
        profile.commuteMinutes : 0,
      onboardingCompleted: profile.onboardingCompleted === true,
      createdAt: profile.createdAt?.toDate?.().toISOString() || null,
    },
    counts: {
      activities: activities.data().count,
      goals: goals.data().count,
      scheduleEvents: schedule.data().count,
    },
  };
});

exports.setAdminUserDisabled = onCall(FUNCTION_OPTIONS, async (request) => {
  requireAdmin(request);
  const uid = request.data?.uid;
  const disabled = request.data?.disabled;

  if (typeof uid !== 'string' || uid.length < 1 || uid.length > 128 ||
      typeof disabled !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Invalid account update.');
  }
  if (uid === request.auth.uid) {
    throw new HttpsError(
      'failed-precondition',
      'You cannot disable your own administrator account.',
    );
  }

  const target = await auth.getUser(uid);
  if (target.customClaims?.admin === true) {
    throw new HttpsError(
      'failed-precondition',
      'Administrator accounts cannot be changed from this dashboard.',
    );
  }

  await auth.updateUser(uid, {disabled});
  if (disabled) {
    await auth.revokeRefreshTokens(uid);
  }
  await db.collection('users').doc(uid).set({
    accountDisabled: disabled,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await db.collection('adminAudit').add({
    action: disabled ? 'disable_user' : 'enable_user',
    actorUid: request.auth.uid,
    actorEmail: request.auth.token.email || '',
    targetUid: uid,
    targetEmail: target.email || '',
    createdAt: FieldValue.serverTimestamp(),
  });

  return {uid, disabled};
});
