const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
} = require('firebase/firestore');
const {ref, uploadBytes, getBytes} = require('firebase/storage');

const projectRoot = path.resolve(__dirname, '../..');
let testEnvironment;

test.before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: 'demo-worklife',
    firestore: {
      rules: fs.readFileSync(path.join(projectRoot, 'firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(projectRoot, 'storage.rules'), 'utf8'),
    },
  });
});

test.beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.clearStorage();
});

test.after(async () => {
  await testEnvironment.cleanup();
});

test('users can read their own profile but not another user profile', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'users/alice'), {name: 'Alice'});
    await setDoc(doc(firestore, 'users/bob'), {name: 'Bob'});
  });

  const aliceDb = testEnvironment.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(aliceDb, 'users/alice')));
  await assertFails(getDoc(doc(aliceDb, 'users/bob')));
});

test('verified admins can manage user records but cannot edit security fields', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/alice'), {name: 'Alice'});
    await setDoc(doc(context.firestore(), 'users/alice/goals/g1'), {title: 'Walk'});
  });
  const adminDb = testEnvironment.authenticatedContext('admin', {
    admin: true,
    email_verified: true,
  }).firestore();
  const ordinaryDb = testEnvironment.authenticatedContext('ordinary').firestore();
  await assertSucceeds(getDoc(doc(adminDb, 'users/alice')));
  await assertSucceeds(getDocs(collection(adminDb, 'users')));
  await assertSucceeds(setDoc(doc(adminDb, 'users/alice/goals/g1'), {title: 'Rest'}));
  await assertSucceeds(setDoc(doc(adminDb, 'users/alice/goals/g2'), {title: 'Read'}));
  await assertSucceeds(deleteDoc(doc(adminDb, 'users/alice/goals/g1')));
  await assertFails(deleteDoc(doc(ordinaryDb, 'users/alice/goals/g2')));
  await assertFails(setDoc(doc(adminDb, 'users/alice'), {name: 'Changed', role: 'admin'}, {merge: true}));
  await assertFails(getDoc(doc(ordinaryDb, 'users/alice')));
  await assertFails(getDocs(collection(ordinaryDb, 'users')));
  await assertFails(setDoc(doc(ordinaryDb, 'users/alice/goals/g2'), {title: 'No'}));
});

test('users cannot assign themselves an admin or protected account field', async () => {
  const aliceDb = testEnvironment.authenticatedContext('alice').firestore();
  await assertSucceeds(setDoc(doc(aliceDb, 'users/alice'), {name: 'Alice'}));
  await assertFails(
    setDoc(doc(aliceDb, 'users/alice'), {name: 'Alice', admin: true}),
  );
  await assertFails(
    setDoc(
      doc(aliceDb, 'users/alice'),
      {name: 'Alice', accountDisabled: false},
    ),
  );
});

test('a disabled user cannot read their profile or subcollection records', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'users/alice'), {
      name: 'Alice',
      accountDisabled: true,
    });
    await setDoc(doc(firestore, 'users/alice/activities/a1'), {title: 'Walk'});
  });

  const aliceDb = testEnvironment.authenticatedContext('alice').firestore();
  await assertFails(getDoc(doc(aliceDb, 'users/alice')));
  await assertFails(getDoc(doc(aliceDb, 'users/alice/activities/a1')));
});

test('only a verified admin claim can read admin audit and no client can write it', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    await setDoc(doc(firestore, 'adminAudit/event-1'), {action: 'disable_user'});
  });

  const adminDb = testEnvironment
      .authenticatedContext('admin', {admin: true, email_verified: true})
      .firestore();
  const unverifiedAdminDb = testEnvironment
      .authenticatedContext('unverified-admin', {
        admin: true,
        email_verified: false,
      })
      .firestore();
  const userDb = testEnvironment.authenticatedContext('user').firestore();

  await assertSucceeds(getDoc(doc(adminDb, 'adminAudit/event-1')));
  await assertFails(getDoc(doc(unverifiedAdminDb, 'adminAudit/event-1')));
  await assertFails(getDoc(doc(userDb, 'adminAudit/event-1')));
  await assertFails(
    setDoc(doc(adminDb, 'adminAudit/event-2'), {action: 'self-promote'}),
  );
});

test('profile photo storage is owner-only and rejects non-images and oversized files', async () => {
  const photo = new Uint8Array([1, 2, 3, 4]);
  const aliceStorage = testEnvironment.authenticatedContext('alice').storage();
  const bobStorage = testEnvironment.authenticatedContext('bob').storage();

  await assertSucceeds(
    uploadBytes(
      ref(aliceStorage, 'profile_photos/alice/profile_photo'),
      photo,
      {contentType: 'image/png'},
    ),
  );
  await assertSucceeds(
    getBytes(ref(aliceStorage, 'profile_photos/alice/profile_photo')),
  );
  await assertFails(
    uploadBytes(
      ref(bobStorage, 'profile_photos/alice/another-photo'),
      photo,
      {contentType: 'image/png'},
    ),
  );
  await assertFails(
    getBytes(ref(bobStorage, 'profile_photos/alice/profile_photo')),
  );
  await assertFails(
    uploadBytes(
      ref(aliceStorage, 'profile_photos/alice/not-an-image'),
      photo,
      {contentType: 'text/plain'},
    ),
  );
  await assertFails(
    uploadBytes(
      ref(aliceStorage, 'profile_photos/alice/oversized'),
      new Uint8Array(10 * 1024 * 1024),
      {contentType: 'image/png'},
    ),
  );
});
