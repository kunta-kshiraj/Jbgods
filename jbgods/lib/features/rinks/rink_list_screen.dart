import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/auth_providers.dart';
import 'add_rink_listing_screen.dart';
import 'edit_rink_listing_screen.dart';

class RinkListScreen extends ConsumerStatefulWidget {
  const RinkListScreen({super.key});

  @override
  ConsumerState<RinkListScreen> createState() => _RinkListScreenState();
}

class _RinkListScreenState extends ConsumerState<RinkListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static bool _matchesQuery(Map<String, dynamic> data, String query) {
    if (query.isEmpty) return true;
    final name = (data['name'] as String? ?? '').toLowerCase();
    final city = (data['city'] as String? ?? '').toLowerCase();
    final state = (data['state'] as String? ?? '').toLowerCase();
    return name.contains(query) || city.contains(query) || state.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userRole = ref.watch(userRoleProvider);
    final isMaster = userRole == 'master';
    final isAdminOrMaster = userRole == 'admin' || userRole == 'master';
    final firestore = ref.watch(firestoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('List of skating rinks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isAdminOrMaster)
            TextButton.icon(
              onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRinkListingScreen()),
            ),
              icon: const Icon(Icons.add),
              label: const Text('Add rink'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by rink name, city or state',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (isMaster) _PendingSection(firestore: firestore),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('rink_listings')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)));
                }
                var docs = snapshot.data?.docs ?? [];
                docs = List.from(docs)
                  ..sort((a, b) {
                    final at = (a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    final bt = (b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
                    return bt.compareTo(at);
                  });
                final filtered = docs.where((d) => _matchesQuery(d.data(), _searchQuery)).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          docs.isEmpty ? 'No skating rinks yet' : 'No rinks match "${_searchController.text.trim()}"',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    return _RinkListingCard(
                      id: doc.id,
                      name: data['name'] as String? ?? 'Unnamed',
                      city: data['city'] as String? ?? '',
                      state: data['state'] as String? ?? '',
                      country: data['country'] as String? ?? '',
                      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
                      claimed: data['claimed'] == true,
                      isMaster: isMaster,
                      firestore: firestore,
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

class _PendingSection extends StatelessWidget {
  final FirebaseFirestore firestore;

  const _PendingSection({required this.firestore});

  Future<void> _updateStatus(BuildContext context, String id, String status) async {
    try {
      if (status == 'approved') {
        await firestore.collection('rink_listings').doc(id).update({'status': 'approved'});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rink approved'), backgroundColor: Colors.green),
          );
        }
      } else {
        await firestore.collection('rink_listings').doc(id).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing rejected and removed'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('rink_listings')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (isDark ? Colors.orange : Colors.orange.shade50).withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending approval (${docs.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...docs.map((doc) {
                final d = doc.data();
                return _PendingCard(
                  id: doc.id,
                  name: d['name'] as String? ?? 'Unnamed',
                  city: d['city'] as String? ?? '',
                  state: d['state'] as String? ?? '',
                  country: d['country'] as String? ?? '',
                  onApprove: () => _updateStatus(context, doc.id, 'approved'),
                  onReject: () => _updateStatus(context, doc.id, 'rejected'),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _PendingCard extends StatelessWidget {
  final String id;
  final String name;
  final String city;
  final String state;
  final String country;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.country,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? theme.colorScheme.surface : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  if (city.isNotEmpty || state.isNotEmpty)
                    Text('$city${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}$state',
                        style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
                  if (country.isNotEmpty)
                    Text(country,
                        style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white70 : Colors.black54)),
                ],
              ),
            ),
            TextButton(onPressed: onReject, child: const Text('Reject')),
            const SizedBox(width: 4),
            ElevatedButton(onPressed: onApprove, child: const Text('Approve')),
          ],
        ),
      ),
    );
  }
}

class _RinkListingCard extends StatelessWidget {
  final String id;
  final String name;
  final String city;
  final String state;
  final String country;
  final int likeCount;
  final bool claimed;
  final bool isMaster;
  final FirebaseFirestore firestore;

  const _RinkListingCard({
    required this.id,
    required this.name,
    required this.city,
    required this.state,
    required this.country,
    required this.likeCount,
    required this.claimed,
    required this.isMaster,
    required this.firestore,
  });

  Future<void> _onLongPress(BuildContext context) async {
    if (!isMaster) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (choice == 'edit') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditRinkListingScreen(
            listingId: id,
            initialName: name,
            initialCity: city,
            initialState: state,
            initialCountry: country,
            initialClaimed: claimed,
          ),
        ),
      );
      return;
    }
    if (choice != 'delete') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete skating rink'),
        backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
        content: Text(
          'Remove "$name" from the list? This cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await firestore.collection('rink_listings').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skating rink removed'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = Colors.red.shade50;
    return GestureDetector(
      onLongPress: isMaster ? () => _onLongPress(context) : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      city.isNotEmpty || state.isNotEmpty
                          ? '${city.isNotEmpty ? city : ''}${city.isNotEmpty && state.isNotEmpty ? ', ' : ''}${state.isNotEmpty ? state : ''}'
                          : '—',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    if (country.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        country,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                    if (isMaster)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Long press to edit or delete',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black38,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _LikeButton(
                listingId: id,
                initialCount: likeCount,
                iconColor: Colors.white,
                textColor: Colors.white,
              ),
            ],
          ),
            ),
            if (claimed)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'Claimed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final String listingId;
  final int initialCount;
  final Color? iconColor;
  final Color? textColor;

  const _LikeButton({
    required this.listingId,
    required this.initialCount,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestore = FirebaseFirestore.instance;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final iconC = iconColor ?? theme.colorScheme.primary;
    final textC = textColor ?? theme.colorScheme.primary;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('rink_listings')
          .doc(listingId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final count = (data?['likeCount'] as num?)?.toInt() ?? initialCount;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              try {
                await firestore.collection('rink_listings').doc(listingId).collection('likes').add({
                  'userId': userId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                await firestore.collection('rink_listings').doc(listingId).update({
                  'likeCount': FieldValue.increment(1),
                });
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not add like: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor != null ? Colors.red.shade400 : null,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: iconC, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textC,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
