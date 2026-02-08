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

    // Redirect if not admin or master
    if (userRole != 'admin' && userRole != 'master') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/shell/home');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Open Owner Requests tab when coming from notification (?tab=owner)
    final tabParam = GoRouterState.of(context).uri.queryParameters['tab'];
    final initialTabIndex = (tabParam == 'owner') ? 1 : 0;

    return DefaultTabController(
      initialIndex: initialTabIndex,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Requests'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/shell/profile'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Member Requests'),
              Tab(text: 'Owner Requests'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MemberRequestsTab(),
            OwnerRequestsTab(),
          ],
        ),
      ),
    );
  }
}

class MemberRequestsTab extends ConsumerWidget {
  const MemberRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider);

    return StreamBuilder<QuerySnapshot>(
      stream: ref.read(firestoreProvider)
          .collection('requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No pending member requests'),
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
    );
  }
}

class OwnerRequestsTab extends StatelessWidget {
  const OwnerRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('owner_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No owner requests found'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final uid = docs[index].id;

            final theme = Theme.of(context);
            final base = theme.colorScheme.primary;
            
            // Match home page card colors
            final headColor = base.withValues(alpha: 0.20);
            final bodyColor = base.withValues(alpha: 0.12);
            final footColor = base.withValues(alpha: 0.10);
            
            final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;
            
            // Extract address fields
            final address1 = data['address1'] ?? '';
            final address2 = data['address2'] ?? '';
            final city = data['city'] ?? '';
            final state = data['state'] ?? '';
            final fullAddress = data['address'] ?? '';
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Rink Name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      color: headColor,
                    ),
                    child: Text(
                      data['rinkName'] ?? 'Unknown Rink',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // Body: Owner details
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    color: bodyColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['ownerName'] != null && (data['ownerName'] as String).isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: textColor.withOpacity(0.8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Owner: ${data['ownerName'] ?? ''}',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (data['email'] != null && (data['email'] as String).isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(Icons.email, size: 16, color: textColor.withOpacity(0.8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Email: ${data['email'] ?? ''}',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        // Display address - prefer individual fields if available, otherwise use full address
                        if (address1.isNotEmpty || city.isNotEmpty || state.isNotEmpty || fullAddress.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.place, size: 16, color: textColor.withOpacity(0.8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (address1.isNotEmpty)
                                      Text(
                                        'Address 1: $address1',
                                        style: TextStyle(color: textColor),
                                      ),
                                    if (address2.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Address 2: $address2',
                                        style: TextStyle(color: textColor),
                                      ),
                                    ],
                                    if (city.isNotEmpty || state.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${city.isNotEmpty ? city : ''}${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}${state.isNotEmpty ? state : ''}',
                                        style: TextStyle(color: textColor),
                                      ),
                                    ],
                                    if (address1.isEmpty && address2.isEmpty && city.isEmpty && state.isEmpty && fullAddress.isNotEmpty)
                                      Text(
                                        'Location: $fullAddress',
                                        style: TextStyle(color: textColor),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Footer: Action buttons
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      color: footColor,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                        // Update user role and owner details
                        await firestore.collection('users').doc(uid).update({
                          'role': 'owner',
                          'rinkName': data['rinkName'],
                          'address': data['address'] ?? '',
                          'address1': data['address1'] ?? '',
                          'address2': data['address2'] ?? '',
                          'city': data['city'] ?? '',
                          'state': data['state'] ?? '',
                          'ownerName': data['ownerName'],
                          'email': data['email'],
                          'latitude': data['latitude'],
                          'longitude': data['longitude'],
                        });
                        // Update rinks collection
                        await firestore.collection('rinks').doc(uid).set({
                          'rinkName': data['rinkName'],
                          'address': data['address'] ?? '',
                          'address1': data['address1'] ?? '',
                          'address2': data['address2'] ?? '',
                          'city': data['city'] ?? '',
                          'state': data['state'] ?? '',
                          'ownerName': data['ownerName'],
                          'email': data['email'],
                          'latitude': data['latitude'],
                          'longitude': data['longitude'],
                          'status': 'approved',
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        // Delete the owner request
                        await firestore.collection('owner_requests').doc(uid).delete();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Owner approved')),
                        );
                      },
                    ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await firestore.collection('owner_requests').doc(uid).update({'status': 'rejected'});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Owner request rejected')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        transaction.update(firestore.collection('users').doc(byUid), {'role': newRole});
        transaction.update(firestore.collection('requests').doc(requestId), {
          'status': 'approved',
          'deciderUid': currentUser.uid,
          'decidedAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request approved - User is now $newRole')),
        );
        ref.invalidate(currentUserRoleProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(adminsStreamProvider);
        ref.invalidate(membersStreamProvider);
        ref.invalidate(communityCountProvider);
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
        final userDoc = await transaction.get(firestore.collection('users').doc(byUid));
        final currentRejectCount = userDoc.data()?['rejectCount'] ?? 0;
        final newRejectCount = (currentRejectCount + 1).clamp(0, 3);

        transaction.update(firestore.collection('users').doc(byUid), {'rejectCount': newRejectCount});
        transaction.update(firestore.collection('requests').doc(requestId), {
          'status': 'rejected',
          'deciderUid': currentUser.uid,
          'decidedAt': FieldValue.serverTimestamp(),
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request rejected')),
        );
        ref.invalidate(currentUserRoleProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(adminsStreamProvider);
        ref.invalidate(membersStreamProvider);
        ref.invalidate(communityCountProvider);
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
          return const Card(child: ListTile(title: Text('Loading...')));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          return Card(
            color: Colors.red.withOpacity(0.1),
            margin: const EdgeInsets.all(12),
            child: ListTile(
              title: Text('User deleted ($byUid)'),
              subtitle: const Text('Orphaned request'),
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
                      backgroundImage: (userData['avatarUrl'] != null && 
                                       (userData['avatarUrl'] as String).isNotEmpty)
                          ? NetworkImage(userData['avatarUrl'] as String)
                          : null,
                      child: (userData['avatarUrl'] == null || 
                             (userData['avatarUrl'] as String).isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(username, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text(email, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                          if (rejectCount > 0)
                            Text('Rejected $rejectCount times', style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (requestedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Requested: ${_formatDate(requestedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ),
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
