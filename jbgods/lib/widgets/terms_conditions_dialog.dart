import 'package:flutter/material.dart';

class TermsConditionsDialog extends StatelessWidget {
  const TermsConditionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Dialog(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Terms & Conditions for Payments',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: secondaryTextColor,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      context,
                      theme,
                      textColor,
                      secondaryTextColor,
                      '1. Event Payments',
                      [
                        'Event fees are for joining real-world skating events.',
                        'When you pay, your spot is confirmed for that event.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      theme,
                      textColor,
                      secondaryTextColor,
                      '2. Rose Award Annual Membership',
                      [
                        'The annual membership fee gives you physical access to the skating rink and its facilities for one year.',
                        'This payment does not give any special digital features inside the app.',
                        'It is meant only for real-world use at the rink.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      theme,
                      textColor,
                      secondaryTextColor,
                      '3. Annual Rink Owners Access',
                      [
                        'When you pay for the monthly plan, you get access to all rink owner features inside the app for 30 days.',
                        'After 30 days, the access ends and you can pay again whenever you want.',
                        'This monthly payment is not automatic. You will never be charged without your permission.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      theme,
                      textColor,
                      secondaryTextColor,
                      '4. Refunds',
                      [
                        'Monthly access payments are handled by Apple and follow Apple\'s refund rules.',
                        'Annual membership and event payments are normally non-refundable unless the rink cancels the membership or the event.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      theme,
                      textColor,
                      secondaryTextColor,
                      '5. Correct Information',
                      [
                        'Please make sure your name and details are correct when making a payment.',
                        'Your confirmation may be checked at the rink or during events.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      theme,
                      textColor,
                      secondaryTextColor,
                      '6. Access After Payment',
                      [
                        'For monthly access, your features unlock instantly inside the app.',
                        'For annual membership and events, you may need to show your confirmation message at the rink.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSection(
                      context,
                      theme,
                      textColor,
                      secondaryTextColor,
                      '7. Misuse',
                      [
                        'Sharing your account or using someone else\'s payment may lead to your access being removed.',
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '8. By making a payment, you agree to these terms.',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('I Understand'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    ThemeData theme,
    Color textColor,
    Color secondaryTextColor,
    String title,
    List<String> points,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...points.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}



