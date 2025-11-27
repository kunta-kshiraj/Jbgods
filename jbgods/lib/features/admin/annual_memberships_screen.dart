// lib/features/admin/annual_memberships_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_providers.dart';
import '../../widgets/header_logo.dart';

class AnnualMembershipsScreen extends ConsumerStatefulWidget {
  const AnnualMembershipsScreen({super.key});

  @override
  ConsumerState<AnnualMembershipsScreen> createState() => _AnnualMembershipsScreenState();
}

class _AnnualMembershipsScreenState extends ConsumerState<AnnualMembershipsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestore = ref.watch(firestoreProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annual Memberships'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/shell/profile'),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase().trim());
              },
            ),
          ),
          // Subscriptions list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('rose_awards_subscriptions')
                  .where('status', isEqualTo: 'active')
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
                
                final subscriptions = snapshot.data?.docs ?? [];
                final now = DateTime.now();
                
                // Filter out expired subscriptions (expiresAt < now)
                final activeSubscriptions = subscriptions.where((sub) {
                  final data = sub.data();
                  final expiresAt = data['expiresAt'] as Timestamp?;
                  if (expiresAt == null) return true; // Keep if no expiration date
                  return expiresAt.toDate().isAfter(now); // Keep if not expired
                }).toList();
                
                // Sort subscriptions by subscribedAt in descending order (newest first)
                activeSubscriptions.sort((a, b) {
                  final aTime = (a.data()['subscribedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  final bTime = (b.data()['subscribedAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  return bTime.compareTo(aTime);
                });
                
                // Filter subscriptions based on search query
                final filteredSubscriptions = _searchQuery.isEmpty
                    ? activeSubscriptions
                    : activeSubscriptions.where((sub) {
                        final data = sub.data();
                        // Check both 'email' (from subscription) and 'userEmail' (if exists)
                        final subscriptionEmail = (data['email'] ?? data['userEmail'] ?? '').toString().toLowerCase();
                        return subscriptionEmail.contains(_searchQuery);
                      }).toList();
                
                if (filteredSubscriptions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.people_outline
                              : Icons.search_off,
                          size: 64,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No active memberships'
                              : 'No results found',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No users have subscribed to the annual Rose Awards membership yet'
                              : 'No memberships found matching "$_searchQuery"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSubscriptions.length,
                  itemBuilder: (context, index) {
                    final subscription = filteredSubscriptions[index];
                    final data = subscription.data();
                    final userId = subscription.id;
                    
                    return _MembershipCard(
                      userId: userId,
                      subscriptionData: data,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipCard extends ConsumerWidget {
  const _MembershipCard({
    required this.userId,
    required this.subscriptionData,
  });

  final String userId;
  final Map<String, dynamic> subscriptionData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firestore = ref.watch(firestoreProvider);
    
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestore.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        final userData = userSnapshot.data?.data();
        final userName = userData?['name'] ?? 'Unknown User';
        // Get email from subscription data first, then fallback to user data
        final userEmail = subscriptionData['email'] ?? subscriptionData['userEmail'] ?? userData?['email'] ?? 'No email';
        final userRole = userData?['role'] ?? 'Unknown';
        
        final subscribedAt = (subscriptionData['subscribedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final amount = subscriptionData['amount'] ?? 500.00;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // User details
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
                      _buildDetailRow(
                        context,
                        'Email',
                        userEmail,
                        theme,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        'Role',
                        userRole,
                        theme,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        'Amount Paid',
                        '\$${amount.toStringAsFixed(2)} USD',
                        theme,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        context,
                        'Subscribed On',
                        DateFormat('MMM d, yyyy h:mm a').format(subscribedAt),
                        theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    ThemeData theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

