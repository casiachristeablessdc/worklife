const test = require('node:test');
const assert = require('node:assert/strict');
const functions = require('../index');

const adminCallableNames = [
  'getAdminDashboard',
  'listAdminUsers',
  'searchAdminUsers',
  'getAdminUserDetails',
  'setAdminUserDisabled',
  'createAdminUser',
  'updateAdminUser',
  'deleteAdminUser',
];

for (const name of adminCallableNames) {
  test(`${name} rejects a signed-out caller`, async () => {
    await assert.rejects(
      functions[name].run({auth: null, data: {}}),
      (error) => error.code === 'unauthenticated',
    );
  });

  test(`${name} rejects a signed-in non-admin caller`, async () => {
    await assert.rejects(
      functions[name].run({
        auth: {
          uid: 'ordinary-user',
          token: {
            admin: false,
            email_verified: true,
            email: 'user@example.com',
          },
        },
        data: {},
      }),
      (error) => error.code === 'permission-denied',
    );
  });

  test(`${name} rejects an unverified admin claim`, async () => {
    await assert.rejects(
      functions[name].run({
        auth: {
          uid: 'unverified-admin',
          token: {
            admin: true,
            email_verified: false,
            email: 'admin@example.com',
          },
        },
        data: {},
      }),
      (error) => error.code === 'permission-denied',
    );
  });
}
