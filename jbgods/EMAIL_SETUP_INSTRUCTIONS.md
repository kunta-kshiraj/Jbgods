# Email Setup Instructions for Event Registration

## Overview
After a user successfully pays for an event, they will receive a confirmation email. This requires setting up Firebase Cloud Functions with email service credentials.

## Option 1: Using Gmail (Recommended for Testing)

### Step 1: Set up Gmail App Password
1. Go to your Google Account settings: https://myaccount.google.com/
2. Enable 2-Step Verification if not already enabled
3. Go to "App passwords": https://myaccount.google.com/apppasswords
4. Generate a new app password for "Mail"
5. Copy the 16-character password

### Step 2: Install Firebase CLI and Functions
```bash
# Navigate to your project directory
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods

# Login to Firebase (using npx - no global install needed)
npx firebase-tools login

# Initialize Firebase Functions (if not already done)
npx firebase-tools init functions
# When prompted:
# - Select JavaScript
# - Say Yes to install dependencies
# - Say No to ESLint (or Yes if you want it)

# Install dependencies (if not already done)
cd functions
npm install
```

### Step 3: Configure Email Credentials
```bash
# Make sure you're in the project root directory
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods

# Set Gmail credentials (replace with your actual email and app password)
npx firebase-tools functions:config:set gmail.email="your-email@gmail.com" gmail.password="your-16-char-app-password"
```

### Step 4: Deploy the Function
```bash
# Make sure you're in the project root directory
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods

# Deploy the function (using npx)
npx firebase-tools deploy --only functions:sendEventRegistrationEmail
```

## Option 2: Using Other Email Services (SendGrid, Mailgun, etc.)

### For SendGrid:
1. Sign up at https://sendgrid.com
2. Get your API key
3. Update `functions/index.js` to use SendGrid instead of nodemailer
4. Set the API key: `firebase functions:config:set sendgrid.api_key="your-api-key"`

### For Mailgun:
1. Sign up at https://www.mailgun.com
2. Get your API key and domain
3. Update `functions/index.js` to use Mailgun
4. Set credentials: `firebase functions:config:set mailgun.api_key="your-key" mailgun.domain="your-domain"`

## Testing

After deployment, test by:
1. Registering for an event in the app
2. Completing payment
3. Checking the user's email inbox

## Troubleshooting

- **Email not sending**: Check Firebase Functions logs: `npx firebase-tools functions:log`
- **Authentication errors**: Verify Gmail app password is correct
- **Function not found**: Ensure function is deployed: `npx firebase-tools deploy --only functions`
- **Permission errors**: Use `npx firebase-tools` instead of global `firebase` command

## Notes

- The email function is called automatically after successful payment
- Email sending failures won't prevent registration (registration is saved first)
- Email status is tracked in the `registrations` collection (`emailSent` field)

