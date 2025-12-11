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
              'Last updated: 12/1/2025',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _Section(
              title: '1. Acceptance of Terms',
              content:
                  'By creating an account and using this app, you agree to these Terms & Conditions and this Privacy Policy. '
                  'If you do not agree, please stop using the app.',
            ),

            _Section(
              title: '2. Who Can Use the App',
              content:
                  'Users approved by the admin may view content and use the available features. '
                  'Only authorized admins can send messages. '
                  'A Master Admin may remove admins or users who violate rules. '
                  'Users may also report abusive messages.',
            ),

            _Section(
              title: '3. Payment Plans and What They Provide',
              content:
                  'The app offers three types of payments:\n\n'
                  '• Skating Rink Owner Monthly Subscription\n\n'
                  'This provides access to all rink-owner features inside the app for 30 days. '
                  'After 30 days, access ends automatically and you can purchase again whenever you want. '
                  'This plan does not renew by itself.\n\n'
                  '• Annual JBGODS ROSE Awards Membership\n\n'
                  'This provides the users to give their vote for JBGODS Rose Awards. '
                  'This payment does not unlock any extra digital features inside the app.\n\n'
                  '• Event Registration Fees\n\n'
                  'These payments confirm your participation in real-world skating events. '
                  'Event fees do not unlock digital features inside the app.',
            ),

            _Section(
              title: '4. Refund Policy',
              content:
                  '• Monthly access payments follow the refund rules of the app store you purchased through.\n\n'
                  '• Annual membership and event fees are normally non-refundable unless the rink cancels the membership or event.\n\n'
                  '• For physical services, refund requests must be handled directly with rink management.',
            ),

            _Section(
              title: '5. Correct Information',
              content:
                  'Please make sure your details are accurate while making any payment. '
                  'You may be asked to show your confirmation message when visiting the rink or attending events.',
            ),

            _Section(
              title: '6. Access After Payment',
              content:
                  '• Monthly access features unlock instantly inside the app after payment.\n\n'
                  '• Event access may require showing your confirmation email at the rink.\n\n'
                  'You can Give your vote anytime after the Annual Payment to vote for JBGODS Rose Awards.',
            ),

            _Section(
              title: '7. Misuse',
              content:
                  'Sharing your account or using someone else\'s payment may lead to access being removed. '
                  'Abusive behavior or violating community rules can also result in account suspension.',
            ),

            _Section(
              title: '8. Community Guidelines (Admins)',
              content:
                  'We maintain a zero-tolerance policy for objectionable or abusive content.\n\n'
                  'Admins must not post content that is: offensive, abusive, discriminatory, hateful, threatening, illegal, spam, '
                  'or violating privacy or intellectual property rights.\n\n'
                  'Users can report objectionable messages directly within the app. All reports are reviewed by the Master Admin.\n\n'
                  'The Master Admin may remove or demote admins who violate these rules.\n\n'
                  'We act on reports within 24 hours by removing the offending content and ejecting the violator.',
            ),

            _Section(
              title: '9. Information We Collect',
              content:
                  'We may collect:\n\n'
                  '• Profile details such as name, email, and username\n\n'
                  '• Device information and basic usage data\n\n'
                  '• Payment status (for unlocking features)\n\n'
                  '• Messages sent by admins or users (for safety and moderation)\n\n'
                  'We do not collect or store any card numbers or sensitive payment details.',
            ),

            _Section(
              title: '10. How We Use Your Information',
              content:
                  'We use your information to:\n\n'
                  '• Create and manage your account\n\n'
                  '• Unlock the correct features based on your plan\n\n'
                  '• Improve app performance and security\n\n'
                  '• Keep the community safe\n\n'
                  '• Provide support when needed',
            ),

            _Section(
              title: '11. Sharing of Information',
              content:
                  'We do not sell your data. '
                  'We only share limited information with trusted service providers that help operate the app. '
                  'They may not use the data for any other purpose.',
            ),

            _Section(
              title: '12. Data Security',
              content:
                  'Your data is stored securely and protected with industry-standard encryption. '
                  'We take reasonable steps to prevent unauthorized access, misuse, or data loss.',
            ),

            _Section(
              title: '13. Your Rights',
              content:
                  'You may:\n\n'
                  '• Update your profile details\n\n'
                  '• Request account deletion from the Profile page\n\n'
                  '• Report users who violate rules\n\n'
                  '• Block abusive users within the chat',
            ),

            _Section(
              title: '14. Changes to These Terms',
              content:
                  'These Terms & Privacy details may be updated as our services grow. '
                  'We will notify you inside the app if important changes are made.',
            ),

            _Section(
              title: '15. Contact Us',
              content: 'For questions or requests, please contact: support@jbgods.com',
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
