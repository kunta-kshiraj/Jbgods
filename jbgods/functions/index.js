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

// Cloud Function to send Rink Owner subscription confirmation email
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

