import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/jb_button.dart';
import '../../data/auth_providers.dart';

class AdminRequestsScreen extends ConsumerWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider);
    final theme = Theme.of(context);
    
    // Redirect if not admin or master
    if (userRole != 'admin' && userRole != 'master') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/shell/home');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/shell/profile'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ref.read(firestoreProvider)
            .collection('requests')
            .where('status', isEqualTo: 'pending')
            // Note: Removed orderBy to avoid composite index requirement
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No pending requests'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data() as Map<String, dynamic>;
              final byUid = data['byUid'] as String;
              
              return _RequestCard(
                requestId: request.id,
                byUid: byUid,
                requestedAt: (data['requestedAt'] as Timestamp?)?.toDate(),
                userRole: userRole,
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final String requestId;
  final String byUid;
  final DateTime? requestedAt;
  final String userRole;

  const _RequestCard({
    required this.requestId,
    required this.byUid,
    this.requestedAt,
    required this.userRole,
  });

  Future<void> _acceptRequest(WidgetRef ref, BuildContext context, String newRole) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final currentUser = ref.read(currentUserProvider);
      
      if (currentUser == null) return;

      await firestore.runTransaction((transaction) async {
        // Update user role
        transaction.update(
          firestore.collection('users').doc(byUid),
          {'role': newRole},
        );
        
        // Update request status
        transaction.update(
          firestore.collection('requests').doc(requestId),
          {
            'status': 'approved',
            'deciderUid': currentUser.uid,
            'decidedAt': FieldValue.serverTimestamp(),
          },
        );
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request approved - User is now $newRole')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve request: $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(WidgetRef ref, BuildContext context) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final currentUser = ref.read(currentUserProvider);
      
      if (currentUser == null) return;

      await firestore.runTransaction((transaction) async {
        // Get current user data
        final userDoc = await transaction.get(firestore.collection('users').doc(byUid));
        final currentRejectCount = userDoc.data()?['rejectCount'] ?? 0;
        final newRejectCount = (currentRejectCount + 1).clamp(0, 3);
        
        // Increment reject count (capped at 3)
        transaction.update(
          firestore.collection('users').doc(byUid),
          {'rejectCount': newRejectCount},
        );
        
        // Update request status
        transaction.update(
          firestore.collection('requests').doc(requestId),
          {
            'status': 'rejected',
            'deciderUid': currentUser.uid,
            'decidedAt': FieldValue.serverTimestamp(),
          },
        );
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject request: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return StreamBuilder<DocumentSnapshot>(
      stream: ref.read(firestoreProvider).collection('users').doc(byUid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Card(
            child: ListTile(
              title: Text('Loading...'),
            ),
          );
        }
        
        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          return const Card(
            child: ListTile(
              title: Text('User not found'),
            ),
          );
        }
        
        final username = userData['username'] ?? 'Unknown';
        final email = userData['email'] ?? 'No email';
        final rejectCount = userData['rejectCount'] ?? 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(userData['avatarUrl'] ?? ''),
                      child: (userData['avatarUrl'] ?? '').isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          if (rejectCount > 0)
                            Text(
                              'Rejected $rejectCount times',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (requestedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Requested: ${_formatDate(requestedAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: JBButton(
                        label: 'Accept as Member',
                        dense: true,
                        onPressed: () => _acceptRequest(ref, context, 'member'),
                      ),
                    ),
                    if (userRole == 'master') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: JBButton(
                          label: 'Accept as Admin',
                          dense: true,
                          onPressed: () => _acceptRequest(ref, context, 'admin'),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: JBButton(
                        label: 'Reject',
                        outline: true,
                        dense: true,
                        onPressed: () => _rejectRequest(ref, context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}