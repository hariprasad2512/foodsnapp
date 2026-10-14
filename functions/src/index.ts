import * as admin from 'firebase-admin';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

admin.initializeApp();

const REGION = 'asia-south1';

/** Slugs the client maps to the S03 error strings (TECH_SPEC §7). */
export type RedeemFailure =
  | 'not-found'
  | 'expired'
  | 'already-used'
  | 'already-connected';

/**
 * Core redeem logic, separated from the onCall wrapper so it can be
 * unit-tested against the Firestore emulator without wrapping v2 functions.
 *
 * Throws HttpsError whose `message` is a RedeemFailure slug (or a standard
 * code for auth/role problems). On success returns `{ relId }`.
 *
 * Notes:
 * - A revoked invite is reported as `expired`: either way the client must
 *   ask the dietician for a fresh code (the S03 copy for that case).
 * - A client can be in at most one active relationship in v1.
 */
export async function redeemInviteForUser(
  db: admin.firestore.Firestore,
  uid: string,
  rawCode: string,
): Promise<{ relId: string }> {
  const code = (rawCode ?? '').toUpperCase().trim();
  const fail = (message: RedeemFailure): never => {
    throw new HttpsError(
      message === 'not-found' ? 'not-found' : 'failed-precondition',
      message,
    );
  };
  // Alphabet per TECH_SPEC §5: no I, O, 0, 1.
  if (!/^[A-HJ-NP-Z2-9]{6}$/.test(code)) fail('not-found');

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(db.doc(`users/${uid}`));
    const role = userSnap.data()?.role;
    if (!userSnap.exists || role !== 'client') {
      throw new HttpsError(
        'permission-denied',
        'only clients can redeem invites',
      );
    }

    const inviteRef = db.doc(`invites/${code}`);
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) fail('not-found');
    const invite = inviteSnap.data()!;
    if (invite.revoked === true) fail('expired'); // see note above
    if (invite.usedBy != null) fail('already-used');
    const expiresAt = invite.expiresAt as admin.firestore.Timestamp | null;
    if (!expiresAt || expiresAt.toMillis() < Date.now()) fail('expired');

    const existing = await tx.get(
      db
        .collection('relationships')
        .where('clientId', '==', uid)
        .limit(1),
    );
    if (!existing.empty) fail('already-connected');

    const relId = db.collection('relationships').doc().id;
    const now = admin.firestore.FieldValue.serverTimestamp();
    tx.update(inviteRef, {
      usedBy: uid,
      usedAt: now,
    });
    tx.set(db.doc(`relationships/${relId}`), {
      dieticianId: invite.dieticianId,
      clientId: uid,
      dieticianName: invite.dieticianName,
      clientName: userSnap.data()!.displayName,
      status: 'active',
      createdAt: now,
      lastMealAt: null,
      lastMealTag: null,
      lastMealLocalDate: null,
      streakCount: 0,
      unreadForDietician: 0,
      unreadForClient: 0,
      lastActivityAt: now,
    });
    return { relId };
  });
}

/**
 * Callable `redeemInvite({code})` — the only way to redeem (TECH_SPEC §7).
 * Direct client writes to relationships/invites are denied by rules (M1).
 */
export const redeemInvite = onCall(
  { region: REGION, memory: '256MiB', timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'sign in first');
    }
    return redeemInviteForUser(
      admin.firestore(),
      request.auth.uid,
      request.data?.code as string,
    );
  },
);
