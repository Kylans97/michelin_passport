// The "Secret Key (for OAuth)" Supabase's Apple provider needs for Sign in
// with Apple on the website: an ES256 JWT signed with the Sign in with Apple
// key (.p8), valid for at most six months, so it has to be made again
// before then (Supabase does not renew it). The app's native sign-in does
// not use it.
//
//   node scripts/apple-oauth-secret.mjs <key.p8> <key id> <team id> <services id> | pbcopy
//
// Prints only the token, for piping straight into the clipboard; the key
// itself is never printed. The expiry date goes to stderr.
import { readFileSync } from 'node:fs';
import { createPrivateKey, sign } from 'node:crypto';

const [keyFile, keyId, teamId, servicesId] = process.argv.slice(2);
if (!keyFile || !keyId || !teamId || !servicesId) {
  console.error('Usage: node scripts/apple-oauth-secret.mjs <key.p8> <key id> <team id> <services id>');
  process.exit(1);
}

const b64url = (input) => Buffer.from(input).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const sixMonths = 15777000; // Apple's maximum
const header = b64url(JSON.stringify({ alg: 'ES256', kid: keyId }));
const claims = b64url(JSON.stringify({
  iss: teamId,
  iat: now,
  exp: now + sixMonths,
  aud: 'https://appleid.apple.com',
  sub: servicesId,
}));
const key = createPrivateKey(readFileSync(keyFile));
const signature = sign('sha256', Buffer.from(`${header}.${claims}`), { key, dsaEncoding: 'ieee-p1363' });
process.stdout.write(`${header}.${claims}.${b64url(signature)}`);
console.error(`Valid until ${new Date((now + sixMonths) * 1000).toISOString().slice(0, 10)}. Make a new one before then.`);
