import assert from 'node:assert/strict';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const root = new URL('../../', import.meta.url);
const rules = fs.readFileSync(
  fileURLToPath(new URL('firestore.rules', root)),
  'utf8',
);
const emulator = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
const [host, rawPort] = emulator.split(':');
const environment = await initializeTestEnvironment({
  projectId: 'demo-pallijob-rules',
  firestore: {
    host,
    port: Number(rawPort),
    rules,
  },
});

try {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'users/employer-a'), { role: 'employer' }),
      setDoc(doc(db, 'users/employer-b'), { role: 'employer' }),
      setDoc(doc(db, 'users/student-a'), { role: 'student' }),
      setDoc(doc(db, 'users/student-b'), { role: 'student' }),
      setDoc(doc(db, 'users/student-new'), { role: 'student' }),
      setDoc(doc(db, 'jobs/job-a'), {
        employerId: 'employer-a',
        title: 'Employer A job',
      }),
      setDoc(doc(db, 'jobs/job-b'), {
        employerId: 'employer-b',
        title: 'Employer B job',
      }),
      setDoc(doc(db, 'applications/job-a_student-a'), {
        jobId: 'job-a',
        studentId: 'student-a',
        employerId: 'employer-a',
        status: 'pending',
        dateApplied: new Date('2026-11-01T00:00:00Z'),
      }),
      setDoc(doc(db, 'applications/job-a_student-b'), {
        jobId: 'job-a',
        studentId: 'student-b',
        employerId: 'employer-a',
        status: 'pending',
        dateApplied: new Date('2026-11-02T00:00:00Z'),
      }),
      setDoc(doc(db, 'applications/job-b_student-b'), {
        jobId: 'job-b',
        studentId: 'student-b',
        employerId: 'employer-b',
        status: 'pending',
        dateApplied: new Date(),
      }),
      setDoc(doc(db, 'applications/job-b_student-mismatch'), {
        jobId: 'job-b',
        studentId: 'student-b',
        employerId: 'employer-a',
        status: 'pending',
        dateApplied: new Date(),
      }),
      setDoc(doc(db, 'applications/legacy-job-a_student-b'), {
        jobId: 'job-a',
        studentId: 'student-b',
        status: 'pending',
        dateApplied: new Date(),
      }),
      setDoc(doc(db, 'applications/missing-job_student-a'), {
        jobId: 'missing-job',
        studentId: 'student-a',
        status: 'pending',
        dateApplied: new Date(),
      }),
      setDoc(doc(db, 'applications/deleted-job_student-a'), {
        jobId: 'deleted-job',
        studentId: 'student-a',
        employerId: 'employer-a',
        status: 'pending',
        dateApplied: new Date(),
      }),
      setDoc(doc(db, 'applications/deleted-parent_student-a'), {
        jobId: 'job-a',
        studentId: 'student-a',
        employerId: 'employer-a',
        status: 'pending',
        dateApplied: new Date(),
      }),
    ]);
    await setDoc(
      doc(db, 'applications/deleted-parent_student-a/messages/orphan'),
      {
        senderId: 'student-a',
        receiverId: 'employer-a',
        content: 'Orphaned message',
        timestamp: new Date(),
      },
    );
    await deleteDoc(doc(db, 'applications/deleted-parent_student-a'));
  });

  const employerA = environment.authenticatedContext('employer-a').firestore();
  const employerB = environment.authenticatedContext('employer-b').firestore();
  const studentA = environment.authenticatedContext('student-a').firestore();
  const studentB = environment.authenticatedContext('student-b').firestore();
  const studentNew = environment.authenticatedContext('student-new').firestore();
  const signedOut = environment.unauthenticatedContext().firestore();

  const employerAApplications = await assertSucceeds(
    getDocs(
      query(
        collection(employerA, 'applications'),
        where('jobId', '==', 'job-a'),
      ),
    ),
  );
  assert.equal(employerAApplications.size, 3);
  assert.deepEqual(
    employerAApplications.docs.map((application) => application.id).sort(),
    [
      'job-a_student-a',
      'job-a_student-b',
      'legacy-job-a_student-b',
    ],
  );

  const employerBApplications = await assertSucceeds(
    getDocs(
      query(
        collection(employerB, 'applications'),
        where('jobId', '==', 'job-b'),
      ),
    ),
  );
  assert.equal(employerBApplications.size, 2);
  assert.deepEqual(
    employerBApplications.docs.map((application) => application.id).sort(),
    ['job-b_student-b', 'job-b_student-mismatch'],
  );
  await assertFails(
    getDocs(
      query(
        collection(employerB, 'applications'),
        where('jobId', '==', 'job-a'),
      ),
    ),
  );
  const employerAStoredOwnerApplications = await assertSucceeds(
    getDocs(
      query(
        collection(employerA, 'applications'),
        where('employerId', '==', 'employer-a'),
      ),
    ),
  );
  assert.equal(employerAStoredOwnerApplications.size, 4);
  await assertSucceeds(
    getDoc(doc(employerA, 'applications/deleted-job_student-a')),
  );
  await assertFails(getDocs(collection(employerA, 'applications')));
  await assertFails(getDoc(doc(employerB, 'applications/job-a_student-a')));

  const studentAApplications = await assertSucceeds(
    getDocs(
      query(
        collection(studentA, 'applications'),
        where('studentId', '==', 'student-a'),
      ),
    ),
  );
  assert.deepEqual(
    studentAApplications.docs.map((application) => application.id).sort(),
    [
      'deleted-job_student-a',
      'job-a_student-a',
      'missing-job_student-a',
    ],
  );
  await assertFails(getDoc(doc(studentA, 'applications/job-a_student-b')));
  await assertFails(
    getDocs(
      query(
        collection(studentA, 'applications'),
        where('employerId', '==', 'employer-a'),
      ),
    ),
  );
  await assertFails(getDocs(collection(studentA, 'applications')));
  await assertFails(getDocs(collection(signedOut, 'applications')));

  const studentAMessages = collection(
    studentA,
    'applications/job-a_student-a/messages',
  );
  const employerAMessages = collection(
    employerA,
    'applications/job-a_student-a/messages',
  );
  await assertSucceeds(getDocs(studentAMessages));
  await assertSucceeds(getDocs(employerAMessages));
  await assertFails(
    getDocs(collection(studentB, 'applications/job-a_student-a/messages')),
  );
  await assertFails(
    getDocs(collection(employerB, 'applications/job-a_student-a/messages')),
  );
  await assertFails(
    getDocs(collection(studentNew, 'applications/job-a_student-a/messages')),
  );
  await assertFails(
    getDocs(collection(signedOut, 'applications/job-a_student-a/messages')),
  );

  const studentMessage = doc(studentAMessages, 'student-message');
  await assertSucceeds(
    setDoc(studentMessage, {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Hello employer',
      timestamp: serverTimestamp(),
    }),
  );
  const employerMessage = doc(employerAMessages, 'employer-message');
  await assertSucceeds(
    setDoc(employerMessage, {
      senderId: 'employer-a',
      receiverId: 'student-a',
      content: 'Hello student',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(studentAMessages, 'impersonated-sender'), {
      senderId: 'employer-a',
      receiverId: 'student-a',
      content: 'Not the sender',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(studentAMessages, 'wrong-receiver'), {
      senderId: 'student-a',
      receiverId: 'student-b',
      content: 'Wrong recipient',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(employerAMessages, 'employer-impersonation'), {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Not the sender',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(studentAMessages, 'extra-field'), {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Unexpected metadata',
      timestamp: serverTimestamp(),
      edited: false,
    }),
  );
  await assertFails(
    setDoc(doc(studentAMessages, 'blank-content'), {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: '   ',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(studentAMessages, 'long-content'), {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'x'.repeat(2001),
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(studentAMessages, 'wrong-timestamp'), {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Invalid timestamp',
      timestamp: new Date(),
    }),
  );
  await assertFails(
    setDoc(doc(studentAMessages, 'missing-receiver'), {
      senderId: 'student-a',
      content: 'Missing receiver',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(studentMessage, { content: 'Edited message' }),
  );
  await assertFails(deleteDoc(studentMessage));
  await assertFails(
    getDocs(collection(studentA, 'applications/missing-job_student-a/messages')),
  );
  await assertFails(
    getDocs(collection(studentA, 'applications/deleted-job_student-a/messages')),
  );
  await assertFails(
    setDoc(
      doc(studentA, 'applications/missing-job_student-a/messages/new'),
      {
        senderId: 'student-a',
        receiverId: 'employer-a',
        content: 'Missing job',
        timestamp: serverTimestamp(),
      },
    ),
  );
  await assertFails(
    getDocs(
      collection(studentA, 'applications/deleted-parent_student-a/messages'),
    ),
  );
  await assertFails(
    setDoc(
      doc(studentA, 'applications/deleted-parent_student-a/messages/new'),
      {
        senderId: 'student-a',
        receiverId: 'employer-a',
        content: 'Missing application',
        timestamp: serverTimestamp(),
      },
    ),
  );

  const legacyMessages = collection(
    studentB,
    'applications/legacy-job-a_student-b/messages',
  );
  await assertSucceeds(getDocs(legacyMessages));
  await assertSucceeds(
    setDoc(doc(legacyMessages, 'legacy-message'), {
      senderId: 'student-b',
      receiverId: 'employer-a',
      content: 'Legacy application chat works',
      timestamp: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    getDocs(
      collection(
        employerA,
        'applications/legacy-job-a_student-b/messages',
      ),
    ),
  );
  await assertSucceeds(
    updateDoc(doc(employerA, 'applications/legacy-job-a_student-b'), {
      status: 'accepted',
    }),
  );

  const newApplication = doc(studentNew, 'applications/job-a_student-new');
  await assertSucceeds(
    setDoc(newApplication, {
      jobId: 'job-a',
      studentId: 'student-new',
      employerId: 'employer-a',
      status: 'pending',
      dateApplied: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(doc(studentNew, 'applications/job-a_student-new-2'), {
      jobId: 'job-a',
      studentId: 'student-new',
      employerId: 'employer-b',
      status: 'pending',
      dateApplied: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(newApplication, {
      employerId: 'employer-b',
    }),
  );
  await assertFails(
    updateDoc(newApplication, {
      studentId: 'student-b',
    }),
  );
  await assertFails(
    updateDoc(newApplication, {
      status: 'accepted',
    }),
  );
  await assertFails(
    setDoc(newApplication, {
      jobId: 'job-a',
      studentId: 'student-new',
      employerId: 'employer-a',
      status: 'pending',
      dateApplied: serverTimestamp(),
    }),
  );

  const employerAApplication = doc(employerA, 'applications/job-a_student-a');
  const employerASecondApplication = doc(
    employerA,
    'applications/job-a_student-b',
  );
  const mismatchedOwnerApplication = doc(
    employerA,
    'applications/job-b_student-mismatch',
  );

  await assertFails(
    updateDoc(doc(employerB, 'applications/job-a_student-a'), {
      status: 'accepted',
    }),
  );
  await assertFails(
    updateDoc(doc(studentA, 'applications/job-a_student-a'), {
      status: 'accepted',
    }),
  );
  await assertFails(
    updateDoc(doc(signedOut, 'applications/job-a_student-a'), {
      status: 'accepted',
    }),
  );
  await assertFails(
    updateDoc(mismatchedOwnerApplication, {
      status: 'accepted',
    }),
  );

  await assertFails(
    updateDoc(employerASecondApplication, {
      jobId: 'job-b',
    }),
  );
  await assertFails(
    updateDoc(employerASecondApplication, {
      studentId: 'student-a',
    }),
  );
  await assertFails(
    updateDoc(employerASecondApplication, {
      employerId: 'employer-b',
    }),
  );
  await assertFails(
    updateDoc(employerASecondApplication, {
      dateApplied: new Date('2026-12-01T00:00:00Z'),
    }),
  );
  await assertFails(
    updateDoc(employerASecondApplication, {
      status: 'withdrawn',
    }),
  );
  await assertFails(
    updateDoc(employerASecondApplication, {
      status: 'pending',
    }),
  );

  await assertSucceeds(
    updateDoc(employerAApplication, {
      status: 'accepted',
    }),
  );
  await assertFails(
    updateDoc(employerAApplication, {
      status: 'rejected',
    }),
  );
  await assertSucceeds(
    updateDoc(employerASecondApplication, {
      status: 'rejected',
    }),
  );

  let finalizedApplication;
  await environment.withSecurityRulesDisabled(async (context) => {
    const snapshot = await getDoc(
      doc(context.firestore(), 'applications/job-a_student-a'),
    );
    finalizedApplication = snapshot.data();
  });
  assert.equal(finalizedApplication.status, 'accepted');
  assert.equal(finalizedApplication.jobId, 'job-a');
  assert.equal(finalizedApplication.studentId, 'student-a');
  assert.equal(finalizedApplication.employerId, 'employer-a');
  assert.equal(
    finalizedApplication.dateApplied.toMillis(),
    new Date('2026-11-01T00:00:00Z').getTime(),
  );

  console.log('PASS Employer A can list only applications owned by Employer A');
  console.log('PASS Employer B cannot read Employer A applications');
  console.log('PASS unrelated students and signed-out users cannot list others’ applications');
  console.log('PASS students retain own-application reads');
  console.log('PASS create validates job-derived employerId and ownership is immutable');
  console.log('PASS only the owning Employer can accept or reject a pending application');
  console.log('PASS application ownership and date fields cannot change');
  console.log('PASS final decisions and invalid status transitions are denied');
  console.log('PASS legacy applications are listed by authoritative job ownership');
  console.log('PASS only application participants can read and send messages');
  console.log('PASS chat messages enforce participant identity, schema, and immutability');
  console.log('PASS deleted applications and missing jobs deny chat access');
  console.log('PASS legacy applications without employerId use the owning job safely');
} finally {
  await environment.cleanup();
}
