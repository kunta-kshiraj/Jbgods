// lib/features/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_providers.dart';
import '../../data/firestore_streams.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsStream = ref.watch(notificationsQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/shell/home'),
        ),
      ),
      body: notificationsStream.when(
        data: (snap) {
          if (snap.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No notifications yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: snap.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = snap.docs[index];
              final data = doc.data();
              final rawBody = data['body'] as String? ?? '';
              // Show only first line (hide any "On click → ..." or extra lines)
              final body = rawBody.split(RegExp(r'\n')).first.trim();
              return _NotificationTile(
                notificationId: doc.id,
                title: data['title'] as String? ?? 'Notification',
                body: body,
                type: data['type'] as String?,
                read: data['read'] == true,
                createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({
    required this.notificationId,
    required this.title,
    required this.body,
    this.type,
    required this.read,
    this.createdAt,
  });

  final String notificationId;
  final String title;
  final String body;
  final String? type;
  final bool read;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firestore = ref.read(firestoreProvider);

    return Container(
      decoration: BoxDecoration(
        color: read ? Colors.white : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () async {
            if (!read) {
              await firestore.collection('notifications').doc(notificationId).update({'read': true});
            }
            _navigateFromType(context, type, ref);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Icon(
                    _iconForType(type),
                    size: 20,
                    color: read ? theme.colorScheme.primary : Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: read ? FontWeight.normal : FontWeight.w600,
                        color: read ? null : Colors.black,
                      ),
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      DateFormat('MMM d, h:mm a').format(createdAt!.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: read ? Colors.grey : Colors.black87,
                      ),
                    ),
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: read
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                        : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'user_request':
        return Icons.person_add;
      case 'owner_request':
        return Icons.store;
      case 'update':
        return Icons.update;
      case 'event':
      case 'event_request':
        return Icons.event;
      case 'report':
        return Icons.flag;
      case 'rink_listing_pending':
        return Icons.place;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  void _navigateFromType(BuildContext context, String? type, WidgetRef ref) {
    switch (type) {
      case 'user_request':
        context.go('/admin/requests?tab=member');
        break;
      case 'owner_request':
        context.go('/admin/requests?tab=owner');
        break;
      case 'report':
        context.go('/admin/reports');
        break;
      case 'rink_listing_pending':
        context.go('/shell/rinks/list');
        break;
      case 'update':
      case 'event':
      case 'event_request':
        context.go('/admin/event-requests');
        break;
      case 'announcement':
        context.go('/shell/chat');
        break;
      default:
        break;
    }
  }
}
