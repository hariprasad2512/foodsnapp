import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';
import { doc, setDoc, Timestamp } from 'firebase/firestore';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

let testEnv;
const alice = () => testEnv.authenticatedContext('alice'); // client of rel1
const dieter = () => testEnv.authenticatedContext('dieter'); // dietician
const bob = () => testEnv.authenticatedContext('bob'); // outsider
const anon = () => testEnv.unauthenticatedContext();

const jpeg = (size = 1024) => new Uint8Array(size); // size-checked, not decoded
const jpgMeta = { contentType: 'image/jpeg' };

describe('storage rules (TECH_SPEC §6)', () => {
before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-foodsnap',
    firestore: { host: '127.0.0.1', port: 8080 },
    storage: {
      rules: readFileSync(resolve(root, 'storage.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
}); // before

// Membership lives in Firestore; storage rules read it via firestore.get.
// Re-seed every test: clearFirestore wipes docs (storage objects persist
// and are overwritten by re-upload).
beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'relationships/rel1'), {
      dieticianId: 'dieter', clientId: 'alice', status: 'active',
      createdAt: Timestamp.now(),
    });
  });
  // Seed one object as the client so read tests have something to fetch.
  await uploadBytes(ref(alice().storage(), 'meals/rel1/seed.jpg'), jpeg(), jpgMeta);
});

after(async () => testEnv.cleanup());

describe('storage meals/{relId}', () => {
  it('only the client of the relationship may upload jpeg < 3MB', async () => {
    await assertSucceeds(uploadBytes(ref(alice().storage(), 'meals/rel1/a.jpg'), jpeg(), jpgMeta));
    await assertFails(uploadBytes(ref(dieter().storage(), 'meals/rel1/a.jpg'), jpeg(), jpgMeta));
    await assertFails(uploadBytes(ref(bob().storage(), 'meals/rel1/a.jpg'), jpeg(), jpgMeta));
    await assertFails(uploadBytes(ref(anon().storage(), 'meals/rel1/a.jpg'), jpeg(), jpgMeta));
    await assertFails(uploadBytes(ref(alice().storage(), 'meals/rel1/b.png'), jpeg(), { contentType: 'image/png' }));
    await assertFails(uploadBytes(ref(alice().storage(), 'meals/rel1/big.jpg'), jpeg(3 * 1024 * 1024 + 1), jpgMeta));
  });
  it('members can read; outsiders cannot', async () => {
    await assertSucceeds(getBytes(ref(alice().storage(), 'meals/rel1/seed.jpg')));
    await assertSucceeds(getBytes(ref(dieter().storage(), 'meals/rel1/seed.jpg')));
    await assertFails(getBytes(ref(bob().storage(), 'meals/rel1/seed.jpg')));
    await assertFails(getBytes(ref(anon().storage(), 'meals/rel1/seed.jpg')));
  });
  it('only the client may delete', async () => {
    await uploadBytes(ref(alice().storage(), 'meals/rel1/del.jpg'), jpeg(), jpgMeta);
    await assertFails(deleteObject(ref(dieter().storage(), 'meals/rel1/del.jpg')));
    await assertSucceeds(deleteObject(ref(alice().storage(), 'meals/rel1/del.jpg')));
  });
}); // storage meals/{relId}
}); // storage rules
