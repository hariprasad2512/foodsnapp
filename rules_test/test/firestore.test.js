import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  addDoc,
  collection,
  runTransaction,
  serverTimestamp,
  Timestamp,
} from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

let testEnv;
const alice = () => testEnv.authenticatedContext('alice'); // client
const dieter = () => testEnv.authenticatedContext('dieter'); // dietician
const bob = () => testEnv.authenticatedContext('bob'); // other client
const anon = () => testEnv.unauthenticatedContext();

const mealDoc = (over = {}) => ({
  clientId: 'alice',
  mealTag: 'lunch',
  note: 'yummy',
  photoUrl: 'https://x/y.jpg',
  thumbUrl: 'https://x/y_thumb.jpg',
  photoPath: 'meals/rel1/m1.jpg',
  thumbPath: 'meals/rel1/m1_thumb.jpg',
  createdAt: serverTimestamp(),
  localDate: '2026-10-14',
  localTime: '13:40',
  reaction: null,
  dieticianComment: null,
  calories: null,
  caloriesSource: null,
  ...over,
});

describe('firestore rules (TECH_SPEC §6)', () => {
before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-foodsnap',
    firestore: {
      rules: readFileSync(resolve(root, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), {
      role: 'client', displayName: 'Alice', email: 'a@x.com',
      timezone: 'Asia/Kolkata', createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'users/dieter'), {
      role: 'dietician', displayName: 'Dr D', email: 'd@x.com',
      timezone: 'Asia/Kolkata', createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'users/bob'), {
      role: 'client', displayName: 'Bob', email: 'b@x.com',
      timezone: 'Asia/Kolkata', createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'relationships/rel1'), {
      dieticianId: 'dieter', clientId: 'alice',
      dieticianName: 'Dr D', clientName: 'Alice',
      status: 'active', createdAt: Timestamp.now(),
      lastMealAt: null, lastMealTag: null, lastMealLocalDate: null,
      streakCount: 0, unreadForDietician: 3, unreadForClient: 2,
      lastActivityAt: Timestamp.now(),
    });
    await setDoc(doc(db, 'relationships/rel1/meals/m1'), mealDoc({ createdAt: Timestamp.now() }));
  });
});

after(async () => testEnv.cleanup());

describe('users', () => {
  it('owner can read own profile; others and anon cannot', async () => {
    await assertSucceeds(getDoc(doc(alice().firestore(), 'users/alice')));
    await assertFails(getDoc(doc(bob().firestore(), 'users/alice')));
    await assertFails(getDoc(doc(anon().firestore(), 'users/alice')));
  });
  it('role is immutable after creation', async () => {
    await assertFails(updateDoc(doc(alice().firestore(), 'users/alice'), { role: 'dietician' }));
    await assertSucceeds(updateDoc(doc(alice().firestore(), 'users/alice'), { displayName: 'Alicia' }));
  });
  it('create requires owner uid + valid role + allowed keys', async () => {
    const fresh = () => testEnv.authenticatedContext('newbie');
    await assertSucceeds(setDoc(doc(fresh().firestore(), 'users/newbie'), {
      role: 'client', displayName: 'N', email: 'n@x.com',
      timezone: 'Asia/Kolkata', createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(fresh().firestore(), 'users/newbie'), {
      role: 'admin', displayName: 'N', email: 'n@x.com',
      timezone: 'Asia/Kolkata', createdAt: serverTimestamp(),
    }));
    await assertFails(setDoc(doc(alice().firestore(), 'users/newbie'), {
      role: 'client', displayName: 'N', email: 'n@x.com',
      timezone: 'Asia/Kolkata', createdAt: serverTimestamp(),
    }));
  });
  it('tokens: only owner may read/write', async () => {
    await assertSucceeds(setDoc(doc(alice().firestore(), 'users/alice/tokens/t1'), { platform: 'android' }));
    await assertFails(setDoc(doc(bob().firestore(), 'users/alice/tokens/t1'), { platform: 'android' }));
  });
});

describe('invites', () => {
  const inviteDoc = (over = {}) => ({
    dieticianId: 'dieter', dieticianName: 'Dr D',
    createdAt: Timestamp.now(),
    expiresAt: Timestamp.fromDate(new Date(Date.now() + 3600e3)),
    usedBy: null, usedAt: null, revoked: false, ...over,
  });
  it('dietician can create; client cannot; >48h expiry fails', async () => {
    await assertSucceeds(setDoc(doc(dieter().firestore(), 'invites/ABC123'), inviteDoc()));
    await assertFails(setDoc(doc(alice().firestore(), 'invites/ABC124'), { ...inviteDoc(), dieticianId: 'alice' }));
    await assertFails(setDoc(doc(dieter().firestore(), 'invites/ABC125'),
      inviteDoc({ expiresAt: Timestamp.fromDate(new Date(Date.now() + 72 * 3600e3)) })));
  });
  it('any signed-in user may GET one invite (redeem needs it); LIST stays owner-only', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/READ01'), inviteDoc()));
    await assertSucceeds(getDoc(doc(dieter().firestore(), 'invites/READ01')));
    await assertSucceeds(getDoc(doc(alice().firestore(), 'invites/READ01')));
    await assertFails(getDoc(doc(anon().firestore(), 'invites/READ01')));
    // Unfiltered list by a non-owner fails; owner filter would pass.
    await assertFails(getDocs(collection(alice().firestore(), 'invites')));
    await assertFails(updateDoc(doc(alice().firestore(), 'invites/READ01'), { usedBy: 'alice' }));
  });
  it('owner may only revoke; cannot edit other fields; nobody deletes', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/REV01'), inviteDoc()));
    await assertSucceeds(updateDoc(doc(dieter().firestore(), 'invites/REV01'), { revoked: true }));
    await assertFails(updateDoc(doc(dieter().firestore(), 'invites/REV01'), { usedBy: 'alice' }));
    await assertFails(updateDoc(doc(alice().firestore(), 'invites/REV01'), { revoked: true }));
    await assertFails(deleteDoc(doc(dieter().firestore(), 'invites/REV01')));
  });
});

describe('relationships', () => {
  it('a client cannot read another relationship; members can', async () => {
    await assertSucceeds(getDoc(doc(alice().firestore(), 'relationships/rel1')));
    await assertSucceeds(getDoc(doc(dieter().firestore(), 'relationships/rel1')));
    await assertFails(getDoc(doc(bob().firestore(), 'relationships/rel1')));
    await assertFails(getDoc(doc(anon().firestore(), 'relationships/rel1')));
  });
  it('no one can create random-id relationships or delete them', async () => {
    await assertFails(setDoc(doc(alice().firestore(), 'relationships/relX'), {
      dieticianId: 'dieter', clientId: 'alice', status: 'active',
    }));
    await assertFails(setDoc(doc(dieter().firestore(), 'relationships/relX'), {
      dieticianId: 'dieter', clientId: 'alice', status: 'active',
    }));
    await assertFails(deleteDoc(doc(alice().firestore(), 'relationships/rel1')));
  });
  it('each side may reset only its own unread counter, only to 0', async () => {
    await assertSucceeds(updateDoc(doc(alice().firestore(), 'relationships/rel1'), { unreadForClient: 0 }));
    await assertFails(updateDoc(doc(alice().firestore(), 'relationships/rel1'), { unreadForDietician: 0 }));
    await assertFails(updateDoc(doc(alice().firestore(), 'relationships/rel1'), { unreadForClient: 5 }));
    await assertSucceeds(updateDoc(doc(dieter().firestore(), 'relationships/rel1'), { unreadForDietician: 0 }));
    // Make the cross-side write a real change (not a no-op): admin bumps it.
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      updateDoc(doc(ctx.firestore(), 'relationships/rel1'), { unreadForClient: 7 }));
    await assertFails(updateDoc(doc(dieter().firestore(), 'relationships/rel1'), { unreadForClient: 0 }));
    await assertFails(updateDoc(doc(bob().firestore(), 'relationships/rel1'), { unreadForClient: 0 }));
  });
});

describe('spark pairing (TECH_SPEC §17)', () => {
  const inviteDoc = (over = {}) => ({
    dieticianId: 'dieter', dieticianName: 'Dr D',
    createdAt: Timestamp.now(),
    expiresAt: Timestamp.fromDate(new Date(Date.now() + 3600e3)),
    usedBy: null, usedAt: null, revoked: false, ...over,
  });
  // Deterministic id rel_{uid}; full valid shape per the create rule.
  const relDoc = (over = {}) => ({
    dieticianId: 'dieter', clientId: 'alice',
    dieticianName: 'Dr D', clientName: 'Alice',
    status: 'active', createdAt: serverTimestamp(),
    lastMealAt: null, lastMealTag: null, lastMealLocalDate: null,
    streakCount: 0, unreadForDietician: 0, unreadForClient: 0,
    lastActivityAt: serverTimestamp(), inviteCode: 'PAIR01', ...over,
  });

  it('missing relationship docs are gettable (pairing probe); existing stay member-only', async () => {
    await assertSucceeds(getDoc(doc(alice().firestore(), 'relationships/rel_alice')));
    await assertFails(getDoc(doc(bob().firestore(), 'relationships/rel1')));
  });

  it('client claims a valid invite; bad claims fail', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/PAIR01'), inviteDoc()));
    await assertSucceeds(updateDoc(doc(alice().firestore(), 'invites/PAIR01'),
      { usedBy: 'alice', usedAt: serverTimestamp() }));
    // Bare usedBy without usedAt fails; wrong owner fails.
    await assertFails(updateDoc(doc(bob().firestore(), 'invites/PAIR01'), { usedBy: 'bob' }));
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/USED99'), inviteDoc({ usedBy: 'x' })));
    await assertFails(updateDoc(doc(bob().firestore(), 'invites/USED99'),
      { usedBy: 'bob', usedAt: serverTimestamp() }));
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/EXP999'),
        inviteDoc({ expiresAt: Timestamp.fromDate(new Date(Date.now() - 1000)) })));
    await assertFails(updateDoc(doc(bob().firestore(), 'invites/EXP999'),
      { usedBy: 'bob', usedAt: serverTimestamp() }));
    // Client that already has a rel is stopped app-side (already-connected
    // check); rules still permit the claim itself — the deterministic rel id
    // is what makes a second relationship impossible.
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'relationships/rel_bob'), { ...relDoc(), clientId: 'bob', clientName: 'Bob' }));
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/PAIR02'), inviteDoc()));
    await assertSucceeds(updateDoc(doc(bob().firestore(), 'invites/PAIR02'),
      { usedBy: 'bob', usedAt: serverTimestamp() }));
  });

  it('client creates rel_{uid} against a valid invite; bad creates fail', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/PAIR01'), inviteDoc()));
    await assertSucceeds(
      setDoc(doc(alice().firestore(), 'relationships/rel_alice'), relDoc()));
    await assertFails( // wrong id
      setDoc(doc(alice().firestore(), 'relationships/rel_other'), relDoc()));
    await assertFails( // unknown invite code
      setDoc(doc(bob().firestore(), 'relationships/rel_bob'), relDoc({ inviteCode: 'NOPE00' })));
    await assertFails( // mismatched dietician
      setDoc(doc(bob().firestore(), 'relationships/rel_bob'), relDoc({ dieticianId: 'mallory' })));
    await assertFails( // non-zero counters
      setDoc(doc(bob().firestore(), 'relationships/rel_bob'), relDoc({ streakCount: 5 })));
    await assertFails( // dietician cannot create
      setDoc(doc(dieter().firestore(), 'relationships/rel_dieter'), relDoc({ clientId: 'dieter' })));
  });

  it('full pairing transaction: claim + create atomically', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) =>
      setDoc(doc(ctx.firestore(), 'invites/TXN111'), inviteDoc()));
    const db = alice().firestore();
    await assertSucceeds(runTransaction(db, async (tx) => {
      const inviteRef = doc(db, 'invites/TXN111');
      const snap = await tx.get(inviteRef);
      if (!snap.exists()) throw new Error('missing');
      tx.update(inviteRef, { usedBy: 'alice', usedAt: serverTimestamp() });
      tx.set(doc(db, 'relationships/rel_alice'), relDoc({ inviteCode: 'TXN111' }));
    }));
    // Second pairing for the same client is impossible (doc exists).
    await assertFails(runTransaction(db, async (tx) => {
      tx.set(doc(db, 'relationships/rel_alice'), relDoc({ inviteCode: 'TXN111' }));
    }));
  });
});

describe('meals', () => {
  it('members can read; outsiders cannot', async () => {
    await assertSucceeds(getDoc(doc(alice().firestore(), 'relationships/rel1/meals/m1')));
    await assertSucceeds(getDoc(doc(dieter().firestore(), 'relationships/rel1/meals/m1')));
    await assertFails(getDoc(doc(bob().firestore(), 'relationships/rel1/meals/m1')));
  });
  it('client can create a valid meal; outsiders and dieticians cannot', async () => {
    await assertSucceeds(addDoc(collection(alice().firestore(), 'relationships/rel1/meals'), mealDoc()));
    await assertFails(addDoc(collection(bob().firestore(), 'relationships/rel1/meals'), mealDoc({ clientId: 'bob' })));
    await assertFails(addDoc(collection(dieter().firestore(), 'relationships/rel1/meals'), mealDoc({ clientId: 'dieter' })));
  });
  it('create rejects bad tag, long note, calories, dietician-only fields', async () => {
    const col = collection(alice().firestore(), 'relationships/rel1/meals');
    await assertFails(addDoc(col, mealDoc({ mealTag: 'brunch' })));
    await assertFails(addDoc(col, mealDoc({ note: 'x'.repeat(201) })));
    await assertFails(addDoc(col, mealDoc({ calories: 500 })));
    await assertFails(addDoc(col, mealDoc({ reaction: '👍' })));
    await assertFails(addDoc(col, mealDoc({ dieticianComment: 'nice' })));
  });
  it('only the dietician may write reaction/comment; client cannot', async () => {
    const dRef = doc(dieter().firestore(), 'relationships/rel1/meals/m1');
    await assertSucceeds(updateDoc(dRef, { reaction: '👍', dieticianComment: 'Looks good' }));
    await assertFails(updateDoc(dRef, { reaction: '💩' }));
    await assertFails(updateDoc(dRef, { dieticianComment: 'x'.repeat(301) }));
    await assertFails(updateDoc(dRef, { note: 'hijack' }));
    await assertFails(updateDoc(doc(alice().firestore(), 'relationships/rel1/meals/m1'), { note: 'edit' }));
    await assertFails(updateDoc(doc(bob().firestore(), 'relationships/rel1/meals/m1'), { reaction: '👍' }));
  });
  it('client can delete own meal; dietician cannot', async () => {
    await assertFails(deleteDoc(doc(dieter().firestore(), 'relationships/rel1/meals/m1')));
    await assertSucceeds(deleteDoc(doc(alice().firestore(), 'relationships/rel1/meals/m1')));
  });
});

describe('messages', () => {
  const msg = (over = {}) => ({ senderId: 'alice', text: 'hello', createdAt: serverTimestamp(), ...over });
  it('members can chat; sender must match; text 1–1000 chars', async () => {
    await assertSucceeds(addDoc(collection(alice().firestore(), 'relationships/rel1/messages'), msg()));
    await assertSucceeds(addDoc(collection(dieter().firestore(), 'relationships/rel1/messages'),
      { senderId: 'dieter', text: 'hi', createdAt: serverTimestamp() }));
    await assertFails(addDoc(collection(bob().firestore(), 'relationships/rel1/messages'), msg({ senderId: 'bob' })));
    await assertFails(addDoc(collection(alice().firestore(), 'relationships/rel1/messages'), msg({ senderId: 'dieter' })));
    await assertFails(addDoc(collection(alice().firestore(), 'relationships/rel1/messages'), msg({ text: '' })));
    await assertFails(addDoc(collection(alice().firestore(), 'relationships/rel1/messages'), msg({ text: 'x'.repeat(1001) })));
  });
  it('messages are immutable', async () => {
    let id;
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      id = (await addDoc(collection(ctx.firestore(), 'relationships/rel1/messages'),
        { senderId: 'alice', text: 'hi', createdAt: Timestamp.now() })).id;
    });
    await assertFails(updateDoc(doc(alice().firestore(), `relationships/rel1/messages/${id}`), { text: 'edited' }));
    await assertFails(deleteDoc(doc(alice().firestore(), `relationships/rel1/messages/${id}`)));
  });
}); // firestore rules

});
