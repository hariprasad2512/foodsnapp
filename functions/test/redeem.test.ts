import * as admin from 'firebase-admin';
import { strict as assert } from 'node:assert';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { redeemInviteForUser } from '../src/index';

const projectId = 'demo-foodsnap';

function db(): admin.firestore.Firestore {
  if (admin.apps.length === 0) {
    admin.initializeApp({ projectId });
  }
  const fs = admin.firestore();
  fs.settings({ ignoreUndefinedProperties: true });
  return fs;
}

async function expectSlug(
  promise: Promise<unknown>,
  slug: string,
): Promise<void> {
  try {
    await promise;
  } catch (e: any) {
    assert.equal(e.message, slug, `expected slug ${slug}, got ${e.message}`);
    return;
  }
  assert.fail(`expected failure ${slug}, but it succeeded`);
}

async function seedUser(
  database: admin.firestore.Firestore,
  uid: string,
  role: string,
  displayName: string,
): Promise<void> {
  await database.doc(`users/${uid}`).set({
    role,
    displayName,
    email: `${uid}@x.com`,
    timezone: 'Asia/Kolkata',
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function seedInvite(
  database: admin.firestore.Firestore,
  code: string,
  over: Record<string, unknown> = {},
): Promise<void> {
  await database.doc(`invites/${code}`).set({
    dieticianId: 'dieter',
    dieticianName: 'Dr D',
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(new Date(Date.now() + 3600e3)),
    usedBy: null,
    usedAt: null,
    revoked: false,
    ...over,
  });
}

describe('redeemInvite (TECH_SPEC §7)', () => {
  const database = db();
  const uid = (name: string): string =>
    `m3-${name}-${Date.now()}-${Math.floor(Math.random() * 1e6)}`;

  it('happy path: marks invite used + creates the relationship', async () => {
    const alice = uid('alice');
    await seedUser(database, alice, 'client', 'Alice');
    await seedInvite(database, 'ABCDEF');
    const { relId } = await redeemInviteForUser(database, alice, 'abcdef');
    assert.ok(relId.length > 0);

    const invite = (await database.doc('invites/ABCDEF').get()).data()!;
    assert.equal(invite.usedBy, alice);
    assert.ok(invite.usedAt != null);

    const rel = (await database.doc(`relationships/${relId}`).get()).data()!;
    assert.equal(rel.clientId, alice);
    assert.equal(rel.dieticianId, 'dieter');
    assert.equal(rel.clientName, 'Alice');
    assert.equal(rel.dieticianName, 'Dr D');
    assert.equal(rel.status, 'active');
    assert.equal(rel.streakCount, 0);
    assert.equal(rel.unreadForDietician, 0);
    assert.equal(rel.unreadForClient, 0);
  });

  it('unknown or malformed code → not-found', async () => {
    const alice = uid('alice2');
    await seedUser(database, alice, 'client', 'Alice');
    await expectSlug(redeemInviteForUser(database, alice, 'ZZZZZZ'), 'not-found');
    await expectSlug(redeemInviteForUser(database, alice, 'abc'), 'not-found');
    await expectSlug(redeemInviteForUser(database, alice, 'ABCDE1'), 'not-found'); // 1 excluded
  });

  it('expired or revoked code → expired', async () => {
    const alice = uid('alice3');
    await seedUser(database, alice, 'client', 'Alice');
    await seedInvite(database, 'EXPDE2', {
      expiresAt: Timestamp.fromDate(new Date(Date.now() - 1000)),
    });
    await expectSlug(redeemInviteForUser(database, alice, 'EXPDE2'), 'expired');
    await seedInvite(database, 'REV222', { revoked: true });
    await expectSlug(redeemInviteForUser(database, alice, 'REV222'), 'expired');
  });

  it('used code → already-used; second redeem → already-connected', async () => {
    const alice = uid('alice4');
    const bob = uid('bob4');
    await seedUser(database, alice, 'client', 'Alice');
    await seedUser(database, bob, 'client', 'Bob');
    await seedInvite(database, 'USED33', { usedBy: 'someone-else' });
    await expectSlug(redeemInviteForUser(database, alice, 'USED33'), 'already-used');

    await seedInvite(database, 'FRESH4');
    await redeemInviteForUser(database, alice, 'FRESH4');
    await seedInvite(database, 'FRESH5');
    await expectSlug(
      redeemInviteForUser(database, alice, 'FRESH5'),
      'already-connected',
    );
    // Bob (no relationship) can still redeem his own code.
    const { relId } = await redeemInviteForUser(database, bob, 'FRESH5');
    assert.ok(relId.length > 0);
  });

  it('dietician role cannot redeem → permission-denied', async () => {
    const dieter2 = uid('dieter2');
    await seedUser(database, dieter2, 'dietician', 'Dr D2');
    await seedInvite(database, 'RALDE6');
    try {
      await redeemInviteForUser(database, dieter2, 'RALDE6');
    } catch (e: any) {
      assert.equal(e.code, 'permission-denied');
      return;
    }
    assert.fail('expected permission-denied');
  });
});
