import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
              context.go('/shell/profile');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ListView(
          children: [
            Text(
              'JB GODS Privacy Policy',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: ${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            _Section(
              title: '1. Information We Collect',
              bullets: const [
                'Account details such as username, email, Date of Birth.',
                'Profile information you choose to provide (e.g., state, country).',
                'Show your shared location to the audience you select; you can stop sharing anytime.'
                'Usage and log data necessary to operate the service.',
              ],
            ),
            _Section(
              title: '2. How We Use Your Information',
              bullets: const [
                'To create and manage your account.',
                'To provide community features (chat, events).',
                'To improve app reliability and security.',
              ],
            ),
            _Section(
              title: '3. Sharing',
              bullets: const [
                'We do not sell your data.',
                'We may share limited information with service providers (e.g., Firebase) for authentication to operate the app.',
              ],
            ),
            _Section(
              title: '4. Your Choices',
              bullets: const [
                'You can update your profile information from the app.',
                'You can request account deletion from the Profile menu.',
              ],
            ),
            _Section(
              title: '5. Contact',
              bullets: const [
                'For questions or requests, contact: support@jbgods.com',
              ],
            ),

            const SizedBox(height: 24),
            Text(
              'This privacy policy may be updated as our services evolve. We will notify you of any material changes within the app.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.bullets});
  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...bullets.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(b, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}


