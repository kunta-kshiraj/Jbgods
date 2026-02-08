const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Configure email transporter
// You need to set up email credentials in Firebase Functions config
// Run: firebase functions:config:set gmail.email="your-email@gmail.com" gmail.password="your-app-password"
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().gmail?.email || process.env.GMAIL_EMAIL,
    pass: functions.config().gmail?.password || process.env.GMAIL_PASSWORD,
  },
});

// Cloud Function to send event registration email
exports.sendEventRegistrationEmail = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { email, fullName, eventTitle, eventDate, eventLocation, amountPaid } = data;

  if (!email || !fullName || !eventTitle) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Format event date if provided
  let dateStr = 'TBD';
  if (eventDate) {
    try {
      let date;
      
      // Handle Firestore Timestamp format (seconds and nanoseconds)
      if (typeof eventDate === 'object' && eventDate.seconds) {
        date = new Date(eventDate.seconds * 1000);
      }
      // Handle ISO string or timestamp string
      else if (typeof eventDate === 'string') {
        // Check if it's a Firestore Timestamp string format
        if (eventDate.includes('Timestamp')) {
          // Extract timestamp from string like "Timestamp(seconds=1234567890, nanoseconds=0)"
          const match = eventDate.match(/seconds=(\d+)/);
          if (match) {
            date = new Date(parseInt(match[1]) * 1000);
          } else {
            date = new Date(eventDate);
          }
        } else {
          date = new Date(eventDate);
        }
      }
      // Handle number (timestamp in milliseconds or seconds)
      else if (typeof eventDate === 'number') {
        // If it's less than 13 digits, it's likely in seconds
        date = eventDate < 1000000000000 
          ? new Date(eventDate * 1000)
          : new Date(eventDate);
      }
      else {
        date = new Date(eventDate);
      }
      
      // Check if date is valid
      if (isNaN(date.getTime())) {
        dateStr = 'TBD';
      } else {
        dateStr = date.toLocaleDateString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        });
      }
    } catch (e) {
      console.error('Error parsing date:', e, 'Raw date:', eventDate);
      dateStr = 'TBD';
    }
  }

  // Email content
  const mailOptions = {
    from: functions.config().gmail?.email || process.env.GMAIL_EMAIL,
    to: email,
    subject: `✅ Payment Successful - Registration Confirmed for ${eventTitle}`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
          .content { background-color: #f9f9f9; padding: 20px; border-radius: 0 0 5px 5px; }
          .success-icon { font-size: 48px; text-align: center; margin: 20px 0; }
          .details { background-color: white; padding: 15px; margin: 15px 0; border-radius: 5px; border-left: 4px solid #4CAF50; }
          .detail-row { margin: 10px 0; }
          .label { font-weight: bold; color: #666; }
          .value { color: #333; }
          .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Payment Successful!</h1>
          </div>
          <div class="content">
            <div class="success-icon">✅</div>
            <h2>Hello ${fullName},</h2>
            <p>Your payment has been processed successfully and you have been registered for the event.</p>
            
            <div class="details">
              <h3>Registration Details:</h3>
              <div class="detail-row">
                <span class="label">Event:</span>
                <span class="value">${eventTitle}</span>
              </div>
              ${eventDate ? `
              <div class="detail-row">
                <span class="label">Date:</span>
                <span class="value">${dateStr}</span>
              </div>
              ` : ''}
              ${eventLocation ? `
              <div class="detail-row">
                <span class="label">Location:</span>
                <span class="value">${eventLocation}</span>
              </div>
              ` : ''}
              <div class="detail-row">
                <span class="label">Amount Paid:</span>
                <span class="value">$${amountPaid?.toFixed(2) || '0.00'} USD</span>
              </div>
            </div>
            
            <p>We look forward to seeing you at the event!</p>
            <p>If you have any questions, please don't hesitate to contact us.</p>
            
            <div class="footer">
              <p>Best regards,<br>JB Gods Team</p>
            </div>
          </div>
        </div>
      </body>
      </html>
    `,
    text: `
      Payment Successful - Registration Confirmed

      Hello ${fullName},

      Your payment has been processed successfully and you have been registered for the event.

      Registration Details:
      - Event: ${eventTitle}
      ${eventDate ? `- Date: ${dateStr}` : ''}
      ${eventLocation ? `- Location: ${eventLocation}` : ''}
      - Amount Paid: $${amountPaid?.toFixed(2) || '0.00'} USD

      We look forward to seeing you at the event!

      Best regards,
      JB Gods Team
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    
    // Update registration document to mark email as sent
    if (data.registrationId) {
      await admin.firestore()
        .collection('registrations')
        .doc(data.registrationId)
        .update({
          'emailSent': true,
          'emailSentAt': admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    
    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending email:', error);
    
    // Update registration document to mark email error
    if (data.registrationId) {
      await admin.firestore()
        .collection('registrations')
        .doc(data.registrationId)
        .update({
          'emailSent': false,
          'emailError': error.message,
        });
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to send email', error);
  }
});

// Cloud Function to send Rose Awards subscription confirmation email
exports.sendRoseAwardsSubscriptionEmail = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { email, fullName, amountPaid, subscriptionType, expiresAt } = data;

  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Format expiration date if provided
  let expirationStr = '1 year from today';
  if (expiresAt) {
    try {
      let date;
      
      // Handle Firestore Timestamp format (seconds and nanoseconds)
      if (typeof expiresAt === 'object' && expiresAt.seconds) {
        date = new Date(expiresAt.seconds * 1000);
      }
      // Handle ISO string or timestamp string
      else if (typeof expiresAt === 'string') {
        // Check if it's a Firestore Timestamp string format
        if (expiresAt.includes('Timestamp')) {
          // Extract timestamp from string like "Timestamp(seconds=1234567890, nanoseconds=0)"
          const match = expiresAt.match(/seconds=(\d+)/);
          if (match) {
            date = new Date(parseInt(match[1]) * 1000);
          } else {
            date = new Date(expiresAt);
          }
        } else {
          date = new Date(expiresAt);
        }
      }
      // Handle number (timestamp in milliseconds or seconds)
      else if (typeof expiresAt === 'number') {
        // If it's less than 13 digits, it's likely in seconds
        date = expiresAt < 1000000000000 
          ? new Date(expiresAt * 1000)
          : new Date(expiresAt);
      }
      else {
        date = new Date(expiresAt);
      }
      
      // Check if date is valid
      if (!isNaN(date.getTime())) {
        expirationStr = date.toLocaleDateString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        });
      }
    } catch (e) {
      console.error('Error parsing expiration date:', e, 'Raw date:', expiresAt);
      expirationStr = '1 year from today';
    }
  }

  const userName = fullName || 'Valued Member';
  const subscriptionTypeText = subscriptionType === 'annual' ? 'Annual' : 'Subscription';

  // Email content
  const mailOptions = {
    from: functions.config().gmail?.email || process.env.GMAIL_EMAIL,
    to: email,
    subject: `✅ Payment Successful - Rose Awards ${subscriptionTypeText} Confirmed`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #E91E63; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
          .content { background-color: #f9f9f9; padding: 20px; border-radius: 0 0 5px 5px; }
          .success-icon { font-size: 48px; text-align: center; margin: 20px 0; }
          .details { background-color: white; padding: 15px; margin: 15px 0; border-radius: 5px; border-left: 4px solid #E91E63; }
          .detail-row { margin: 10px 0; }
          .label { font-weight: bold; color: #666; }
          .value { color: #333; }
          .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          .highlight { color: #E91E63; font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🎗️ Rose Awards Subscription Confirmed!</h1>
          </div>
          <div class="content">
            <div class="success-icon">✅</div>
            <h2>Hello ${userName},</h2>
            <p>Your payment has been processed successfully and you are now a <span class="highlight">Rose Awards Voting Member</span>!</p>
            
            <div class="details">
              <h3>Subscription Details:</h3>
              <div class="detail-row">
                <span class="label">Subscription Type:</span>
                <span class="value">${subscriptionTypeText} Membership</span>
              </div>
              <div class="detail-row">
                <span class="label">Amount Paid:</span>
                <span class="value">$${amountPaid?.toFixed(2) || '500.00'} USD</span>
              </div>
              <div class="detail-row">
                <span class="label">Membership Expires:</span>
                <span class="value">${expirationStr}</span>
              </div>
            </div>
            
            <p><strong>What's Next?</strong></p>
            <p>As a Rose Awards Voting Member, you now have the privilege to:</p>
            <ul>
              <li>Cast your vote for the annual Rose Awards</li>
              <li>Participate in exclusive voting events</li>
              <li>Have your voice heard in the community</li>
            </ul>
            
            <p>You can access the voting section from your profile page in the app.</p>
            <p>If you have any questions, please don't hesitate to contact us.</p>
            
            <div class="footer">
              <p>Best regards,<br>JB Gods Team</p>
            </div>
          </div>
        </div>
      </body>
      </html>
    `,
    text: `
      Rose Awards Subscription Confirmed

      Hello ${userName},

      Your payment has been processed successfully and you are now a Rose Awards Voting Member!

      Subscription Details:
      - Subscription Type: ${subscriptionTypeText} Membership
      - Amount Paid: $${amountPaid?.toFixed(2) || '500.00'} USD
      - Membership Expires: ${expirationStr}

      What's Next?
      As a Rose Awards Voting Member, you now have the privilege to:
      - Cast your vote for the annual Rose Awards
      - Participate in exclusive voting events
      - Have your voice heard in the community

      You can access the voting section from your profile page in the app.

      Best regards,
      JB Gods Team
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    
    // Update subscription document to mark email as sent
    if (data.subscriptionId) {
      await admin.firestore()
        .collection('rose_awards_subscriptions')
        .doc(data.subscriptionId)
        .update({
          'emailSent': true,
          'emailSentAt': admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    
    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending email:', error);
    
    // Update subscription document to mark email error
    if (data.subscriptionId) {
      await admin.firestore()
        .collection('rose_awards_subscriptions')
        .doc(data.subscriptionId)
        .update({
          'emailSent': false,
          'emailError': error.message,
        });
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to send email', error);
  }
});

// ---------- IN-APP NOTIFICATIONS ----------
const db = admin.firestore();

async function getUserIdsByRole(role) {
  const snap = await db.collection('users').where('role', '==', role).get();
  return snap.docs.map(d => d.id);
}

async function getMasters() { return getUserIdsByRole('master'); }
async function getAdmins() { return getUserIdsByRole('admin'); }
async function getMembers() { return getUserIdsByRole('member'); }
async function getOwners() { return getUserIdsByRole('owner'); }

const BATCH_SIZE = 400; // Firestore batch limit is 500

async function notifyUsers(userIds, { type, title, body, data }) {
  if (!userIds.length) return;
  const now = admin.firestore.FieldValue.serverTimestamp();
  const payload = {
    type: type || 'general',
    title: title || 'Notification',
    body: body || '',
    data: data || {},
    createdAt: now,
    read: false,
  };
  for (let i = 0; i < userIds.length; i += BATCH_SIZE) {
    const chunk = userIds.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const uid of chunk) {
      const ref = db.collection('notifications').doc();
      batch.set(ref, { ...payload, recipientUid: uid });
    }
    await batch.commit();
  }
}

// 1a. New user request (member approval) → notify masters only
exports.onRequestCreated = functions.firestore.document('requests/{uid}').onCreate(async (snap) => {
  const masters = await getMasters();
  await notifyUsers(masters, {
    type: 'user_request',
    title: 'New User Request',
    body: 'You have a new user request pending approval.',
    data: { requestId: snap.id },
  });
});

// 1b. User re-applies after rejection (status rejected → pending) → notify masters again
exports.onRequestUpdated = functions.firestore.document('requests/{uid}').onUpdate((change, context) => {
  const before = change.before.data() || {};
  const after = change.after.data() || {};
  if (before.status !== 'rejected' || after.status !== 'pending') return null;
  return getMasters().then((masters) =>
    notifyUsers(masters, {
      type: 'user_request',
      title: 'New User Request',
      body: 'You have a new user request pending approval.',
      data: { requestId: context.params.uid },
    })
  );
});

// 2. New skating rink owner request → notify masters only
exports.onOwnerRequestCreated = functions.firestore.document('owner_requests/{uid}').onCreate(async (snap) => {
  const masters = await getMasters();
  await notifyUsers(masters, {
    type: 'owner_request',
    title: 'New Skating Rink Owner Request',
    body: 'A skating rink owner has requested approval.',
    data: { ownerRequestId: snap.id },
  });
});

// 3. New update → notify masters only
exports.onUpdateCreated = functions.firestore.document('updates/{id}').onCreate(async (snap) => {
  const masters = await getMasters();
  await notifyUsers(masters, {
    type: 'update',
    title: 'New Event Request',
    body: 'A new event request has been submitted for review.',
    data: { updateId: snap.id },
  });
});

// 4a. New event (after approval) → notify masters only
exports.onEventCreated = functions.firestore.document('events/{id}').onCreate(async (snap) => {
  const masters = await getMasters();
  await notifyUsers(masters, {
    type: 'event',
    title: 'New Event Request',
    body: 'A new event request has been submitted for review.',
    data: { eventId: snap.id },
  });
});

// 4b. New event request (pending approval) → notify masters only
exports.onEventRequestCreated = functions.firestore.document('event_requests/{id}').onCreate(async (snap) => {
  const masters = await getMasters();
  await notifyUsers(masters, {
    type: 'event_request',
    title: 'New Event Request',
    body: 'A new event request has been submitted for review.',
    data: { eventRequestId: snap.id },
  });
});

// 5. New report → notify masters only
exports.onReportCreated = functions.firestore.document('reports/{id}').onCreate(async (snap) => {
  const masters = await getMasters();
  await notifyUsers(masters, {
    type: 'report',
    title: 'New Report Submitted',
    body: 'A new report has been submitted. Please review it.',
    data: { reportId: snap.id },
  });
});

// 6. Admin submitted skating rink listing for approval → notify masters only
exports.onRinkListingCreated = functions.firestore.document('rink_listings/{id}').onCreate(async (snap) => {
  const data = snap.data() || {};
  if (data.status !== 'pending' || data.addedByRole !== 'admin') return;
  const masters = await getMasters();
  await notifyUsers(masters, {
    type: 'rink_listing_pending',
    title: 'New Skating Rink Listing Request',
    body: 'An admin has submitted a skating rink for approval.',
    data: { rinkListingId: snap.id },
  });
});

// 7. Chat messages: no in-app notifications (masters-only feature; admins/normal users get none)
exports.onMessageCreated = functions.firestore.document('messages/{id}').onCreate(() => {
  return null; // no notifications
});

// 8. Delete notifications older than 3 days (run daily)
exports.cleanupOldNotifications = functions.pubsub.schedule('0 2 * * *').timeZone('UTC').onRun(async () => {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 3);
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoff);
  const snap = await db.collection('notifications')
    .where('createdAt', '<', cutoffTimestamp)
    .limit(500)
    .get();
  if (snap.empty) return null;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
  return null;
});

// Event pass check-in (callable)
exports.checkInEventPass = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  }
  const { rid, code } = data || {};
  if (!rid || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing rid or code');
  }

  const regRef = db.collection('event_registrations').doc(rid);
  const regSnap = await regRef.get();
  if (!regSnap.exists) {
    return { ok: false, message: 'Invalid pass' };
  }

  const reg = regSnap.data();
  if (reg.paymentStatus !== 'paid') {
    return { ok: false, message: 'Pass not paid' };
  }
  if (reg.passCode !== code) {
    return { ok: false, message: 'Invalid QR code' };
  }
  if (reg.checkedIn === true) {
    return { ok: false, message: 'Already checked in', alreadyCheckedIn: true };
  }

  const eventId = reg.eventId;
  const eventSnap = await db.collection('events').doc(eventId).get();
  if (!eventSnap.exists) {
    return { ok: false, message: 'Event not found' };
  }
  const event = eventSnap.data();
  const createdByUid = event.createdBy || event.createdByUid;
  const callerUid = context.auth.uid;

  const isMaster = await db.collection('users').doc(callerUid).get()
    .then((d) => (d.data() || {}).role === 'master');
  const isCreator = createdByUid === callerUid;

  if (!isMaster && !isCreator) {
    throw new functions.https.HttpsError('permission-denied', 'Not authorized to check in for this event');
  }

  const now = admin.firestore.Timestamp.now();
  await regRef.update({
    checkedIn: true,
    checkedInAt: now,
    checkedInByUid: callerUid,
  });

  return {
    ok: true,
    userName: reg.userName || 'Attendee',
    checkedInAt: { _seconds: now.seconds, _nanoseconds: now.nanoseconds },
  };
});

// Create event pass from registration (recovery when client create was denied)
exports.createEventPassFromRegistration = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  }
  const { registrationId } = data || {};
  if (!registrationId || typeof registrationId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Missing registrationId');
  }

  const regRef = db.collection('registrations').doc(registrationId);
  const regSnap = await regRef.get();
  if (!regSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Registration not found');
  }

  const reg = regSnap.data();
  if (reg.userId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'Not your registration');
  }
  const status = reg.paymentStatus || '';
  if (status !== 'completed' && status !== 'paid') {
    throw new functions.https.HttpsError('failed-precondition', 'Payment not completed');
  }

  const eventId = reg.eventId != null ? String(reg.eventId) : '';
  if (!eventId) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid registration data');
  }

  const userName = reg.fullName || reg.userName || '';
  const userEmail = reg.email || reg.userEmail || '';

  const passRef = db.collection('event_registrations').doc(registrationId);
  const existingPass = await passRef.get();

  let passCode;
  if (existingPass.exists && existingPass.data().passCode) {
    passCode = existingPass.data().passCode;
  } else {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    passCode = '';
    for (let i = 0; i < 8; i++) {
      passCode += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    await passRef.set({
      eventId,
      userId: context.auth.uid,
      userName,
      userEmail,
      paymentStatus: 'paid',
      passCode,
      checkedIn: false,
      checkedInAt: null,
      checkedInByUid: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  return {
    ok: true,
    pass: { eventId, passCode, userName, userEmail },
  };
});

// Cloud Function to send Rink Owner subscription email
exports.sendRinkOwnerSubscriptionEmail = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { email, fullName, subscriptionType, expiresAt, subscriptionId } = data;

  if (!email) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Format expiration date if provided
  let expirationStr = '1 month from today';
  if (expiresAt) {
    try {
      let date;
      
      if (typeof expiresAt === 'object' && expiresAt.seconds) {
        date = new Date(expiresAt.seconds * 1000);
      } else if (typeof expiresAt === 'string') {
        if (expiresAt.includes('Timestamp')) {
          const match = expiresAt.match(/seconds=(\d+)/);
          if (match) {
            date = new Date(parseInt(match[1]) * 1000);
          } else {
            date = new Date(expiresAt);
          }
        } else {
          date = new Date(expiresAt);
        }
      } else if (typeof expiresAt === 'number') {
        date = expiresAt < 1000000000000 
          ? new Date(expiresAt * 1000)
          : new Date(expiresAt);
      } else {
        date = new Date(expiresAt);
      }
      
      if (!isNaN(date.getTime())) {
        expirationStr = date.toLocaleDateString('en-US', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        });
      }
    } catch (e) {
      console.error('Error parsing expiration date:', e, 'Raw date:', expiresAt);
      expirationStr = '1 month from today';
    }
  }

  const userName = fullName || 'Valued Rink Owner';

  const mailOptions = {
    from: functions.config().gmail?.email || process.env.GMAIL_EMAIL,
    to: email,
    subject: `✅ Payment Successful - Rink Owner Monthly Subscription Confirmed`,
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #4CAF50; color: white; padding: 20px; text-align: center; border-radius: 5px 5px 0 0; }
          .content { background-color: #f9f9f9; padding: 20px; border-radius: 0 0 5px 5px; }
          .success-icon { font-size: 48px; text-align: center; margin: 20px 0; }
          .details { background-color: white; padding: 15px; margin: 15px 0; border-radius: 5px; border-left: 4px solid #4CAF50; }
          .detail-row { margin: 10px 0; }
          .label { font-weight: bold; color: #666; }
          .value { color: #333; }
          .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
          .highlight { color: #4CAF50; font-weight: bold; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🏒 Rink Owner Subscription Confirmed!</h1>
          </div>
          <div class="content">
            <div class="success-icon">✅</div>
            <h2>Hello ${userName},</h2>
            <p>Your payment has been processed successfully and you now have <span class="highlight">full access to all rink owner features</span>!</p>
            
            <div class="details">
              <h3>Subscription Details:</h3>
              <div class="detail-row">
                <span class="label">Subscription Type:</span>
                <span class="value">Monthly Membership</span>
              </div>
              <div class="detail-row">
                <span class="label">Subscription Expires:</span>
                <span class="value">${expirationStr}</span>
              </div>
            </div>
            
            <p><strong>What's Next?</strong></p>
            <p>As an active rink owner, you now have access to:</p>
            <ul>
              <li>All rink owner features in the app</li>
              <li>Your rink location displayed on the map</li>
              <li>Event creation and management</li>
              <li>Chat and community features</li>
            </ul>
            
            <p>Your rink will be visible on the map to all users, and you can manage your rink details from your profile.</p>
            <p>If you have any questions, please don't hesitate to contact us.</p>
            
            <div class="footer">
              <p>Best regards,<br>JB Gods Team</p>
            </div>
          </div>
        </div>
      </body>
      </html>
    `,
    text: `
      Rink Owner Subscription Confirmed

      Hello ${userName},

      Your payment has been processed successfully and you now have full access to all rink owner features!

      Subscription Details:
      - Subscription Type: Monthly Membership
      - Subscription Expires: ${expirationStr}

      What's Next?
      As an active rink owner, you now have access to:
      - All rink owner features in the app
      - Your rink location displayed on the map
      - Event creation and management
      - Chat and community features

      Your rink will be visible on the map to all users, and you can manage your rink details from your profile.

      Best regards,
      JB Gods Team
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    
    if (subscriptionId) {
      await admin.firestore()
        .collection('rink_owner_subscriptions')
        .doc(subscriptionId)
        .update({
          'emailSent': true,
          'emailSentAt': admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    
    return { success: true, message: 'Email sent successfully' };
  } catch (error) {
    console.error('Error sending rink owner subscription email:', error);
    
    if (subscriptionId) {
      await admin.firestore()
        .collection('rink_owner_subscriptions')
        .doc(subscriptionId)
        .update({
          'emailSent': false,
          'emailError': error.message,
        });
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to send email', error);
  }
});

