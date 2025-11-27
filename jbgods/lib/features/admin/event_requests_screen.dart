// lib/features/admin/event_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_providers.dart';
import '../../widgets/jb_button.dart';

class EventRequestsScreen extends ConsumerStatefulWidget {
  const EventRequestsScreen({super.key});

  @override
  ConsumerState<EventRequestsScreen> createState() => _EventRequestsScreenState();
}

class _EventRequestsScreenState extends ConsumerState<EventRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Requests'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/shell/profile'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('event_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Pending Requests',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All event requests have been reviewed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data();
              final requestId = request.id;

              return _EventRequestCard(
                requestId: requestId,
                requestData: data,
              );
            },
          );
        },
      ),
    );
  }
}

class _EventRequestCard extends ConsumerWidget {
  const _EventRequestCard({
    required this.requestId,
    required this.requestData,
  });

  final String requestId;
  final Map<String, dynamic> requestData;

  Future<void> _approveRequest(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    final firestore = ref.read(firestoreProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Event'),
        content: Text(
          'Are you sure you want to approve "${requestData['title'] ?? 'this event'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove status and request-specific fields
      final eventData = Map<String, dynamic>.from(requestData);
      eventData.remove('status');
      eventData.remove('requestedAt');
      eventData.remove('creatorName');
      eventData.remove('creatorRole');
      
      // Add approved timestamp
      eventData['approvedAt'] = FieldValue.serverTimestamp();
      eventData['approvedBy'] = ref.read(currentUserProvider)?.uid;

      // Create event in events collection
      await firestore.collection('events').add(eventData);

      // Update request status
      await firestore.collection('event_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': ref.read(currentUserProvider)?.uid,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Event approved and published'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to approve event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    Map<String, dynamic> requestData,
  ) async {
    final firestore = ref.read(firestoreProvider);
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject "${requestData['title'] ?? 'this event'}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await firestore.collection('event_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': ref.read(currentUserProvider)?.uid,
        'rejectionReason': reasonController.text.trim(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Event request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to reject event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = requestData['title'] ?? 'Untitled Event';
    final description = requestData['description'] ?? '';
    final cost = requestData['cost'] ?? 0.0;
    final location = requestData['location'] ?? '';
    final date = requestData['date'] as Timestamp?;
    final time = requestData['time'] ?? '';
    final creatorName = requestData['creatorName'] ?? 'Unknown';
    final creatorRole = requestData['creatorRole'] ?? 'unknown';
    final requestedAt = requestData['requestedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Requested by: $creatorName (${creatorRole.toUpperCase()})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Event details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(context, 'Description', description.isNotEmpty ? description : 'No description', theme),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, 'Location', location, theme),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, 'Cost', '\$${cost.toStringAsFixed(2)}', theme),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    context,
                    'Date',
                    date != null
                        ? DateFormat('MMM d, yyyy').format(date.toDate())
                        : 'Not set',
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, 'Time', time.isNotEmpty ? time : 'Not set', theme),
                  if (requestedAt != null) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      context,
                      'Requested On',
                      DateFormat('MMM d, yyyy h:mm a').format(requestedAt.toDate()),
                      theme,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: JBButton(
                    label: 'Approve',
                    onPressed: () => _approveRequest(context, ref, requestId, requestData),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectRequest(context, ref, requestId, requestData),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

