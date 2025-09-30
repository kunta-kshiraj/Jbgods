import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/signup');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Terms & Privacy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JBGODS – Terms & Conditions & Privacy Policy',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: 9/25/2025',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _Section(
              title: '1. Acceptance of Terms',
              content:
                  'By creating an account and using this app, you agree to these Terms & Conditions and this Privacy Policy. '
                  'If you do not agree, please do not use the app.',
            ),

            _Section(
              title: '2. Who Can Use the App',
              content:
                  'Users who became members on admin approval may view content and read admin messages.\n\n'
                  'Only authorized admins may send messages.\n\n'
                  'A Master Admin may remove admins and users who violate these rules.\n\n'
                  'Users also have the ability to report abusive users.',
            ),

            _Section(
              title: '3. Community Guidelines (Admins)',
              content:
                  'We maintain a zero-tolerance policy for objectionable or abusive content.\n\n'
                  'Admins must not post content that is: offensive, abusive, discriminatory, hateful, threatening, illegal, spam, '
                  'or violating privacy or intellectual property rights.\n\n'
                  'Users can report objectionable messages directly within the app. All reports are reviewed by the Master Admin.\n\n'
                  'The Master Admin may remove or demote admins who violate these rules.\n\n'
                  'We act on reports within 24 hours by removing the offending content and ejecting the violator.',
            ),

            _Section(
              title: '4. Information We Collect',
              content:
                  'We may collect:\n\n'
                  '• Account details: username, name, email, password.\n\n'
                  '• Usage data: device type, app activity, crash logs (to improve reliability and security).',
            ),

            _Section(
              title: '5. How We Use Information',
              content:
                  'We use your data to:\n\n'
                  '• Create and manage accounts.\n\n'
                  '• Provide admin chat features.\n\n'
                  '• Improve reliability, security, and support.',
            ),

            _Section(
              title: '6. Sharing of Information',
              content:
                  'We do not sell your data.\n\n'
                  'We may share limited data with service providers strictly to operate the app (e.g., Firebase Authentication, Firestore).\n\n'
                  'These providers must comply with applicable data protection laws and use the data only to provide their services to us.',
            ),

            _Section(
              title: '7. Data Storage & Security',
              content:
                  'Data is stored securely in cloud services (e.g., Firebase), encrypted in transit and at rest.\n\n'
                  'We retain data only as long as necessary to provide the service or until you request deletion.\n\n'
                  'We use reasonable safeguards to prevent unauthorized access, misuse, or disclosure.',
            ),

            _Section(
              title: '8. Your Rights & Choices',
              content:
                  '• Update or delete profile info from within the app.\n\n'
                  '• Request account deletion from the Profile menu or by contacting us.\n\n'
                  '• Report objectionable content directly in the app for review by the Master Admin.',
            ),

            _Section(
              title: '9. Contact Us',
              content: 'For questions or requests, contact: support@jbgods.com',
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                'This privacy policy may be updated as our services evolve. We will notify you of any material changes within the app.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
