const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');

const projectId = 'worklife-bb9e9';

function parseArguments(argv) {
  const values = {};
  for (let index = 2; index < argv.length; index += 1) {
    const key = argv[index];
    if (key === '--revoke') {
      values.revoke = true;
      continue;
    }
    if ((key === '--email' || key === '--uid') && argv[index + 1]) {
      values[key.slice(2)] = argv[index + 1];
      index += 1;
    }
  }
  return values;
}

async function main() {
  const {email, uid, revoke = false} = parseArguments(process.argv);
  if (Boolean(email) === Boolean(uid)) {
    throw new Error('Pass exactly one of --email <address> or --uid <id>.');
  }

  const app = initializeApp({projectId});
  const auth = getAuth(app);
  const user = email ? await auth.getUserByEmail(email) : await auth.getUser(uid);
  if (!user.emailVerified) {
    throw new Error('The selected account must have a verified email.');
  }

  const claims = {...(user.customClaims || {})};
  if (revoke) {
    delete claims.admin;
  } else {
    claims.admin = true;
  }
  await auth.setCustomUserClaims(user.uid, claims);

  console.log(
    `${revoke ? 'Removed' : 'Granted'} admin role for ${user.email} ` +
    `(${user.uid}) in Firebase project ${projectId}.`,
  );
  console.log('The user must sign out and sign in again to refresh their token.');
}

main().catch((error) => {
  console.error(error.message || error);
  process.exitCode = 1;
});
