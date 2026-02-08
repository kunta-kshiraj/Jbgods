import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/auth_providers.dart';

class MyPassScreen extends ConsumerWidget {
  final String registrationId;
  final Map<String, dynamic>? initialPassData;

  const MyPassScreen({super.key, required this.registrationId, this.initialPassData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialPassData != null && initialPassData!.isNotEmpty) {
      return _PassContentFromData(
        registrationId: registrationId,
        passData: initialPassData!,
      );
    }
    final firestore = ref.watch(firestoreProvider);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('event_registrations').doc(registrationId).snapshots(),
      builder: (context, regSnap) {
        if (regSnap.connectionState == ConnectionState.waiting && !regSnap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Pass')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final doc = regSnap.data;
        if (doc == null || !doc.exists || doc.data() == null) {
          return _PassNotFoundView(registrationId: registrationId);
        }
        final reg = doc.data()!;
        final eventId = reg['eventId'] as String?;
        if (eventId == null || eventId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Pass')),
            body: const Center(child: Text('Invalid pass')),
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('events').doc(eventId).snapshots(),
          builder: (context, eventSnap) {
            if (!eventSnap.hasData || eventSnap.data?.data() == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('My Pass')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final event = eventSnap.data!.data()!;
            final passCode = reg['passCode'] as String? ?? '';
            final checkedIn = reg['checkedIn'] == true;
            final checkedInAt = reg['checkedInAt'] as Timestamp?;
            final userName = reg['userName'] as String? ?? '';
            final paymentStatus = reg['paymentStatus'] as String? ?? '';

            final qrPayload = jsonEncode({'rid': registrationId, 'code': passCode});

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final eventDate = event['date'] as Timestamp?;
            final eventTitle = event['title'] as String? ?? 'Event';
            final location = event['location'] as String? ?? '';

            return Scaffold(
              appBar: AppBar(
                title: const Text('My Pass'),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/shell/events'),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventTitle,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (eventDate != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                DateFormat('EEEE, MMM d, y • h:mm a').format(eventDate.toDate().toLocal()),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.place, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(location, style: theme.textTheme.bodyMedium)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: qrPayload,
                          version: QrVersions.auto,
                          size: 220,
                          gapless: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        userName,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: checkedIn
                              ? Colors.green.withValues(alpha: 0.2)
                              : theme.colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          checkedIn
                              ? 'Checked in${checkedInAt != null ? ' • ${DateFormat('MMM d, h:mm a').format(checkedInAt.toDate().toLocal())}' : ''}'
                              : 'Valid',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: checkedIn ? Colors.green.shade800 : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    if (paymentStatus != 'paid')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Text(
                            'Payment: $paymentStatus',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Shows pass with QR immediately using data returned from Cloud Function (no wait for Firestore).
class _PassContentFromData extends ConsumerWidget {
  final String registrationId;
  final Map<String, dynamic> passData;

  const _PassContentFromData({required this.registrationId, required this.passData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = passData['eventId'] as String? ?? '';
    final passCode = passData['passCode'] as String? ?? '';
    final userName = passData['userName'] as String? ?? '';
    final firestore = ref.watch(firestoreProvider);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestore.collection('events').doc(eventId).get(),
      builder: (context, eventSnap) {
        if (!eventSnap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Pass')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final event = eventSnap.data!.data();
        if (event == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Pass')),
            body: const Center(child: Text('Event not found')),
          );
        }
        final theme = Theme.of(context);
        final eventDate = event['date'] as Timestamp?;
        final eventTitle = event['title'] as String? ?? 'Event';
        final location = event['location'] as String? ?? '';
        final qrPayload = jsonEncode({'rid': registrationId, 'code': passCode});
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Pass'),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/shell/events'),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eventTitle,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (eventDate != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('EEEE, MMM d, y • h:mm a').format(eventDate.toDate().toLocal()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.place, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Expanded(child: Text(location, style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 220,
                      gapless: true,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    userName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Valid',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shown when event_registrations doc is missing (e.g. payment succeeded but pass creation failed).
/// Lets user create the pass from their registration if it exists.
class _PassNotFoundView extends ConsumerStatefulWidget {
  final String registrationId;

  const _PassNotFoundView({required this.registrationId});

  @override
  ConsumerState<_PassNotFoundView> createState() => _PassNotFoundViewState();
}

class _PassNotFoundViewState extends ConsumerState<_PassNotFoundView> {
  bool _creating = false;

  Future<void> _createPass() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to create your pass')),
          );
        }
        return;
      }
      final functions = ref.read(firebaseFunctionsProvider);
      final result = await functions.httpsCallable('createEventPassFromRegistration').call({
        'registrationId': widget.registrationId,
      });
      Map<String, dynamic>? passData;
      if (result.data != null && result.data is Map) {
        final pass = (result.data as Map)['pass'];
        if (pass is Map) {
          passData = Map<String, dynamic>.from(pass);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pass created! Opening your pass…'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
        if (passData != null && passData.isNotEmpty) {
          context.push('/event-pass/${widget.registrationId}', extra: passData);
        } else {
          context.push('/event-pass/${widget.registrationId}');
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        String message = 'Could not create pass.';
        switch (e.code) {
          case 'unauthenticated':
            message = 'Please sign in to create your pass.';
            break;
          case 'not-found':
            message = 'Registration not found. Contact support with your payment details.';
            break;
          case 'permission-denied':
            message = 'This pass is not yours.';
            break;
          case 'failed-precondition':
            message = 'Payment not completed. Contact support.';
            break;
          case 'invalid-argument':
            message = e.message ?? 'Invalid request. Contact support.';
            break;
          default:
            message = e.message ?? message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create pass: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pass'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/shell/events'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.confirmation_number_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Your pass isn’t loaded yet',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap below to generate your pass. You’ll then be taken to your pass with the QR code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _creating ? null : _createPass,
                icon: _creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.confirmation_number_outlined),
                label: Text(_creating ? 'Creating…' : 'Generate pass'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.go('/shell/events'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Events'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
