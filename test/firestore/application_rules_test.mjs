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
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
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
      setDoc(doc(db, 'users/student-atomic'), {
        role: 'student',
        fullName: '\u3000김민지\u00a0',
      }),
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
  const studentAtomic = environment.authenticatedContext('student-atomic').firestore();
  const signedOut = environment.unauthenticatedContext().firestore();

  const legacyJobWrite = doc(employerA, 'jobs/legacy-job-write');
  await assertSucceeds(
    setDoc(legacyJobWrite, {
      title: 'Legacy listing',
      description: 'Created without the optional work type.',
      location: 'Seoul',
      requirements: 'Experience preferred.',
      employerId: 'employer-a',
      createdAt: serverTimestamp(),
    }),
  );
  const typedJobWrite = doc(employerA, 'jobs/typed-job-write');
  await assertSucceeds(
    setDoc(typedJobWrite, {
      title: 'Typed listing',
      description: 'Created with a structured work type.',
      location: 'Seoul',
      requirements: 'Experience preferred.',
      employerId: 'employer-a',
      createdAt: serverTimestamp(),
      workType: 'Part-time',
      schedule: 'Weekdays',
    }),
  );
  await assertSucceeds(
    updateDoc(typedJobWrite, { workType: 'Temporary/Contract' }),
  );
  await assertSucceeds(updateDoc(typedJobWrite, { schedule: 'Weekends' }));
  await assertSucceeds(updateDoc(typedJobWrite, { schedule: 'Flexible' }));
  await assertFails(
    updateDoc(typedJobWrite, { schedule: 'Overnight/Unlisted' }),
  );
  await assertFails(
    updateDoc(typedJobWrite, { workType: 'Seasonal/Unlisted' }),
  );
  await assertFails(
    updateDoc(doc(employerB, 'jobs/typed-job-write'), {
      workType: 'Full-time',
    }),
  );
  await assertFails(
    updateDoc(doc(employerB, 'jobs/typed-job-write'), {
      schedule: 'Weekdays',
    }),
  );
  await assertFails(
    setDoc(doc(employerA, 'jobs/forged-work-type'), {
      title: 'Invalid work type',
      description: 'Must use a supported value.',
      location: 'Seoul',
      requirements: 'Experience preferred.',
      employerId: 'employer-a',
      createdAt: serverTimestamp(),
      workType: 'Seasonal/Unlisted',
    }),
  );
  await assertFails(
    setDoc(doc(employerA, 'jobs/forged-schedule'), {
      title: 'Invalid schedule',
      description: 'Must use a supported value.',
      location: 'Seoul',
      requirements: 'Experience preferred.',
      employerId: 'employer-a',
      createdAt: serverTimestamp(),
      schedule: 'Overnight/Unlisted',
    }),
  );

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
  const studentMessageNotification = doc(
    studentA,
    'users/employer-a/notifications/job-a_student-a__student-message',
  );
  const studentMessageBatch = writeBatch(studentA);
  studentMessageBatch.set(studentMessage, {
    senderId: 'student-a',
    receiverId: 'employer-a',
    content: 'Hello employer',
    timestamp: serverTimestamp(),
  });
  studentMessageBatch.set(studentMessageNotification, {
    type: 'new_message',
    applicationId: 'job-a_student-a',
    jobTitle: 'Employer A job',
    messageId: 'student-message',
    createdAt: serverTimestamp(),
    readAt: null,
  });
  await assertSucceeds(
    studentMessageBatch.commit(),
  );
  const employerMessage = doc(employerAMessages, 'employer-message');
  const employerMessageBatch = writeBatch(employerA);
  employerMessageBatch.set(employerMessage, {
    senderId: 'employer-a',
    receiverId: 'student-a',
    content: 'Hello student',
    timestamp: serverTimestamp(),
  });
  employerMessageBatch.set(
    doc(employerA, 'users/student-a/notifications/job-a_student-a__employer-message'),
    {
      type: 'new_message',
      applicationId: 'job-a_student-a',
      jobTitle: 'Employer A job',
      messageId: 'employer-message',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertSucceeds(employerMessageBatch.commit());
  const wrongRecipientBatch = writeBatch(studentA);
  wrongRecipientBatch.set(
    doc(studentAMessages, 'wrong-notification-recipient'),
    {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Notification recipient must match the message',
      timestamp: serverTimestamp(),
    },
  );
  wrongRecipientBatch.set(
    doc(
      studentA,
      'users/student-b/notifications/job-a_student-a__wrong-notification-recipient',
    ),
    {
      type: 'new_message',
      applicationId: 'job-a_student-a',
      jobTitle: 'Employer A job',
      messageId: 'wrong-notification-recipient',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertFails(wrongRecipientBatch.commit());

  const wrongTimestampBatch = writeBatch(studentA);
  wrongTimestampBatch.set(
    doc(studentAMessages, 'wrong-notification-timestamp'),
    {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Notification timestamp must match the message event',
      timestamp: serverTimestamp(),
    },
  );
  wrongTimestampBatch.set(
    doc(
      studentA,
      'users/employer-a/notifications/job-a_student-a__wrong-notification-timestamp',
    ),
    {
      type: 'new_message',
      applicationId: 'job-a_student-a',
      jobTitle: 'Employer A job',
      messageId: 'wrong-notification-timestamp',
      createdAt: new Date('2026-11-01T00:00:00Z'),
      readAt: null,
    },
  );
  await assertFails(wrongTimestampBatch.commit());

  const wrongNotificationIdBatch = writeBatch(studentA);
  wrongNotificationIdBatch.set(
    doc(studentAMessages, 'wrong-notification-id'),
    {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Notification ID must be deterministic',
      timestamp: serverTimestamp(),
    },
  );
  wrongNotificationIdBatch.set(
    doc(studentA, 'users/employer-a/notifications/wrong-deterministic-id'),
    {
      type: 'new_message',
      applicationId: 'job-a_student-a',
      jobTitle: 'Employer A job',
      messageId: 'wrong-notification-id',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertFails(wrongNotificationIdBatch.commit());

  const wrongNotificationTypeBatch = writeBatch(studentA);
  wrongNotificationTypeBatch.set(
    doc(studentAMessages, 'wrong-notification-type'),
    {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Notification type must match the source event',
      timestamp: serverTimestamp(),
    },
  );
  wrongNotificationTypeBatch.set(
    doc(
      studentA,
      'users/employer-a/notifications/job-a_student-a__wrong-notification-type',
    ),
    {
      type: 'application_accepted',
      applicationId: 'job-a_student-a',
      jobTitle: 'Employer A job',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertFails(wrongNotificationTypeBatch.commit());

  await assertFails(
    setDoc(doc(studentAMessages, 'impersonated-sender'), {
      senderId: 'employer-a',
      receiverId: 'student-a',
      content: 'Not the sender',
      timestamp: serverTimestamp(),
    }),
  );
  await assertSucceeds(
    setDoc(doc(studentAMessages, 'missing-notification'), {
      senderId: 'student-a',
      receiverId: 'employer-a',
      content: 'Legacy message without a notification',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(
      doc(
        studentA,
        'users/employer-a/notifications/job-a_student-a__missing-notification',
      ),
      {
        type: 'new_message',
        applicationId: 'job-a_student-a',
        jobTitle: 'Employer A job',
        messageId: 'missing-notification',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
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
  const legacyMessage = doc(legacyMessages, 'legacy-message');
  await assertSucceeds(
    setDoc(legacyMessage, {
      senderId: 'student-b',
      receiverId: 'employer-a',
      content: 'Legacy application chat works',
      timestamp: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(
      doc(
        studentB,
        'users/employer-a/notifications/legacy-job-a_student-b__legacy-message',
      ),
      {
        type: 'new_message',
        applicationId: 'legacy-job-a_student-b',
        jobTitle: 'Employer A job',
        messageId: 'legacy-message',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
  );
  await assertSucceeds(
    getDocs(
      collection(
        employerA,
        'applications/legacy-job-a_student-b/messages',
      ),
    ),
  );
  const legacyDecisionBatch = writeBatch(employerA);
  legacyDecisionBatch.update(
    doc(employerA, 'applications/legacy-job-a_student-b'),
    {
      status: 'accepted',
      statusUpdatedAt: serverTimestamp(),
    },
  );
  legacyDecisionBatch.set(
    doc(
      employerA,
      'users/student-b/notifications/status__accepted__legacy-job-a_student-b',
    ),
    {
      type: 'application_accepted',
      applicationId: 'legacy-job-a_student-b',
      jobTitle: 'Employer A job',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertSucceeds(legacyDecisionBatch.commit());

  const newApplication = doc(studentNew, 'applications/job-a_student-new');
  await assertSucceeds(setDoc(newApplication, {
    jobId: 'job-a',
    studentId: 'student-new',
    employerId: 'employer-a',
    status: 'pending',
    dateApplied: serverTimestamp(),
  }));
  const olderClientApplication = doc(employerA, 'applications/job-a_student-new');
  assert.equal(
    (await assertSucceeds(getDoc(olderClientApplication))).data().verifiedEmployerId,
    undefined,
  );
  await assertFails(updateDoc(olderClientApplication, {
    status: 'accepted',
    verifiedEmployerId: 'employer-a',
  }));
  await assertFails(
    setDoc(
      doc(
        studentNew,
        'users/employer-a/notifications/new-application__job-a_student-new',
      ),
      {
        type: 'new_application',
        applicationId: 'job-a_student-new',
        jobTitle: 'Employer A job',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
  );
  await assertFails(
    setDoc(
      doc(
        studentNew,
        'users/employer-a/notifications/new-application__job-a_nonexistent',
      ),
      {
        type: 'new_application',
        applicationId: 'job-a_nonexistent',
        jobTitle: 'Employer A job',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
  );

  const atomicApplication = doc(
    studentAtomic,
    'applications/job-a_student-atomic',
  );
  const atomicApplicationData = {
    jobId: 'job-a',
    studentId: 'student-atomic',
    employerId: 'employer-a',
    status: 'pending',
    dateApplied: serverTimestamp(),
  };
  for (const verifiedEmployerId of [null, 42, '', 'employer-b']) {
    await assertFails(setDoc(atomicApplication, {
      ...atomicApplicationData,
      verifiedEmployerId,
    }));
  }
  await assertFails(setDoc(atomicApplication, {
    ...atomicApplicationData,
    employerId: 'employer-b',
    verifiedEmployerId: 'employer-b',
  }));
  await assertSucceeds(getDoc(doc(studentAtomic, 'users/student-atomic')));
  await assertFails(getDoc(doc(employerA, 'users/student-atomic')));
  await assertFails(getDocs(collection(employerA, 'users')));
  for (const applicantName of [null, 42, '', '   ', '다른 이름', '\u3000김민지\u00a0']) {
    await assertFails(setDoc(atomicApplication, {
      ...atomicApplicationData,
      applicantName,
    }));
  }
  const longName = '가'.repeat(101);
  await assertSucceeds(updateDoc(doc(studentAtomic, 'users/student-atomic'), {
    fullName: longName,
  }));
  await assertFails(setDoc(atomicApplication, {
    ...atomicApplicationData,
    applicantName: longName,
  }));
  await assertSucceeds(updateDoc(doc(studentAtomic, 'users/student-atomic'), {
    fullName: '\u3000김민지\u00a0',
  }));
  const newApplicationBatch = writeBatch(studentAtomic);
  newApplicationBatch.set(atomicApplication, {
    ...atomicApplicationData,
    applicantName: '김민지',
    verifiedEmployerId: 'employer-a',
  });
  newApplicationBatch.set(
    doc(
      studentAtomic,
      'users/employer-a/notifications/new-application__job-a_student-atomic',
    ),
    {
      type: 'new_application',
      applicationId: 'job-a_student-atomic',
      jobTitle: 'Employer A job',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertSucceeds(newApplicationBatch.commit());
  const namedApplication = doc(employerA, 'applications/job-a_student-atomic');
  const namedApplicationData = (await assertSucceeds(getDoc(namedApplication))).data();
  assert.equal(namedApplicationData.applicantName, '김민지');
  assert.equal(namedApplicationData.verifiedEmployerId, 'employer-a');
  await assertFails(getDoc(doc(employerB, 'applications/job-a_student-atomic')));
  await assertFails(updateDoc(atomicApplication, {
    verifiedEmployerId: 'employer-b',
  }));
  for (const verifiedEmployerId of ['employer-b', deleteField()]) {
    await assertFails(updateDoc(namedApplication, {
      status: 'accepted',
      verifiedEmployerId,
    }));
  }
  await assertFails(updateDoc(atomicApplication, { applicantName: '다른 이름' }));
  await assertFails(updateDoc(namedApplication, {
    status: 'accepted',
    applicantName: '다른 이름',
  }));
  await assertSucceeds(updateDoc(doc(studentAtomic, 'users/student-atomic'), {
    fullName: '새 이름',
  }));
  assert.equal((await assertSucceeds(getDoc(namedApplication))).data().applicantName, '김민지');
  await assertFails(
    setDoc(
      doc(
        studentAtomic,
        'users/employer-a/notifications/new-application__job-a_student-atomic',
      ),
      {
        type: 'new_application',
        applicationId: 'job-a_student-atomic',
        jobTitle: 'Employer A job',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
  );
  await assertFails(
    setDoc(doc(studentNew, 'applications/job-b_student-new'), {
      jobId: 'job-b',
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
  await assertFails(
    updateDoc(employerASecondApplication, {
      status: 'rejected',
      statusUpdatedAt: serverTimestamp(),
    }),
  );
  const invalidStatusTimestampBatch = writeBatch(employerA);
  invalidStatusTimestampBatch.update(
    employerASecondApplication,
    {
      status: 'rejected',
      statusUpdatedAt: new Date('2026-11-01T00:00:00Z'),
    },
  );
  invalidStatusTimestampBatch.set(
    doc(
      employerA,
      'users/student-b/notifications/status__rejected__job-a_student-b',
    ),
    {
      type: 'application_rejected',
      applicationId: 'job-a_student-b',
      jobTitle: 'Employer A job',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertFails(invalidStatusTimestampBatch.commit());

  await assertSucceeds(
    updateDoc(employerAApplication, {
      status: 'accepted',
    }),
  );
  await assertSucceeds(
    updateDoc(employerASecondApplication, {
      status: 'rejected',
    }),
  );
  await assertFails(
    setDoc(
      doc(
        employerA,
        'users/student-a/notifications/status__accepted__job-a_student-a',
      ),
      {
        type: 'application_accepted',
        applicationId: 'job-a_student-a',
        jobTitle: 'Employer A job',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
  );

  const acceptedBatch = writeBatch(employerA);
  acceptedBatch.update(
    doc(employerA, 'applications/job-a_student-atomic'),
    {
      status: 'accepted',
      statusUpdatedAt: serverTimestamp(),
    },
  );
  acceptedBatch.set(
    doc(
      employerA,
      'users/student-atomic/notifications/status__accepted__job-a_student-atomic',
    ),
    {
      type: 'application_accepted',
      applicationId: 'job-a_student-atomic',
      jobTitle: 'Employer A job',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertSucceeds(acceptedBatch.commit());
  assert.equal(
    (await assertSucceeds(getDoc(namedApplication))).data().verifiedEmployerId,
    'employer-a',
  );

  const rejectedBatch = writeBatch(employerB);
  rejectedBatch.update(doc(employerB, 'applications/job-b_student-b'), {
    status: 'rejected',
    statusUpdatedAt: serverTimestamp(),
  });
  rejectedBatch.set(
    doc(
      employerB,
      'users/student-b/notifications/status__rejected__job-b_student-b',
    ),
    {
      type: 'application_rejected',
      applicationId: 'job-b_student-b',
      jobTitle: 'Employer B job',
      createdAt: serverTimestamp(),
      readAt: null,
    },
  );
  await assertSucceeds(rejectedBatch.commit());

  const studentANotifications = collection(
    studentA,
    'users/student-a/notifications',
  );
  const studentAEvents = await assertSucceeds(
    getDocs(studentANotifications),
  );
  assert.equal(studentAEvents.size, 1);
  const employerAEvents = await assertSucceeds(
    getDocs(collection(employerA, 'users/employer-a/notifications')),
  );
  assert.equal(employerAEvents.size, 2);
  await assertFails(
    getDoc(
      doc(
        studentB,
        'users/student-atomic/notifications/status__accepted__job-a_student-atomic',
      ),
    ),
  );
  await assertFails(
    getDocs(collection(studentA, 'users/employer-a/notifications')),
  );

  const studentAStatusNotification = doc(
    studentAtomic,
    'users/student-atomic/notifications/status__accepted__job-a_student-atomic',
  );
  await assertSucceeds(
    updateDoc(studentAStatusNotification, {
      readAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(studentAStatusNotification, {
      jobTitle: 'Changed job title',
    }),
  );
  await assertFails(
    updateDoc(studentAStatusNotification, {
      readAt: serverTimestamp(),
    }),
  );
  await assertFails(
    setDoc(
      doc(studentA, 'users/student-a/notifications/forged-event'),
      {
        type: 'application_accepted',
        applicationId: 'job-a_student-a',
        jobTitle: 'Employer A job',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
  );
  await assertFails(
    setDoc(
      doc(studentA, 'users/student-b/notifications/forged-recipient'),
      {
        type: 'new_message',
        applicationId: 'job-a_student-a',
        jobTitle: 'Employer A job',
        messageId: 'missing-message',
        createdAt: serverTimestamp(),
        readAt: null,
      },
    ),
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

  await assertSucceeds(deleteDoc(doc(employerA, 'jobs/job-a')));
  assert.equal(
    (await assertSucceeds(getDoc(namedApplication))).data().verifiedEmployerId,
    'employer-a',
  );
  await assertFails(getDoc(doc(employerB, 'applications/job-a_student-atomic')));

  console.log('PASS Employer A can list only applications owned by Employer A');
  console.log('PASS job work types and schedules are optional for legacy writes and validated for authorized employer writes');
  console.log('PASS Employer B cannot read Employer A applications');
  console.log('PASS unrelated students and signed-out users cannot list others’ applications');
  console.log('PASS students retain own-application reads');
  console.log('PASS create validates job-derived employerId and ownership is immutable');
  console.log('PASS only the owning Employer can accept or reject a pending application');
  console.log('PASS application ownership and date fields cannot change');
  console.log('PASS final decisions and invalid status transitions are denied');
  console.log('PASS legacy application, decision, and message writes work without notifications');
  console.log('PASS updated application, decision, and message events atomically create notifications');
  console.log('PASS notifications cannot be forged, duplicated, stale, misaddressed, or mistimed');
  console.log('PASS users can read only their own notification records');
  console.log('PASS only recipients can mark notifications read and cannot forge events');
  console.log('PASS legacy applications are listed by authoritative job ownership');
  console.log('PASS only application participants can read and send messages');
  console.log('PASS chat messages enforce participant identity, schema, and immutability');
  console.log('PASS deleted applications and missing jobs deny chat access');
  console.log('PASS legacy applications without employerId use the owning job safely');
  console.log('PASS optional verifiedEmployerId is bound to the job owner, immutable, and retained after job deletion');
} finally {
  await environment.cleanup();
}
