import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_providers.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _q = '';

  Future<void> _setRole(String uid, String role,
      {bool resetRejectCount = false}) async {
    final fs = ref.read(firestoreProvider);
    final data = <String, dynamic>{
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (role == 'member') {
      data['memberSince'] = FieldValue.serverTimestamp();
    }
    if (resetRejectCount) data['rejectCount'] = 0;
    await fs.collection('users').doc(uid).set(data, SetOptions(merge: true));
    
    // Force refresh the streams after role change
    ref.invalidate(adminsStreamProvider);
    ref.invalidate(membersStreamProvider);
    ref.invalidate(communityCountProvider);
  }

  bool _match(Map<String, dynamic> u) {
    if (_q.isEmpty) return true;
    final needle = _q.toLowerCase();
    final name = (u['name'] ?? '').toString().toLowerCase();
    final username = (u['username'] ?? '').toString().toLowerCase();
    final email = (u['email'] ?? '').toString().toLowerCase();
    return name.contains(needle) || username.contains(needle) || email.contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final admins = ref.watch(adminsStreamProvider);
    final members = ref.watch(membersStreamProvider);

    return Scaffold(
      appBar: AppBar(
            leading: IconButton(
                tooltip: 'Back to Profile',
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () {
                if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                } else {
                    context.go('/shell/profile'); // <-- change to your profile path if different
                }
                },
            ),
            centerTitle: true,
            title: const Text('Community'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(adminsStreamProvider);
                  ref.invalidate(membersStreamProvider);
                  ref.invalidate(communityCountProvider);
                },
              ),
            ],
            ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Search
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search name / username / email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 20),

            Text('Admins', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            admins.when(
                data: (snap) {
                    if (snap.docs.isEmpty) return const Text('No admins yet.');

                    final docs = [...snap.docs]..sort((a, b) {
                    final au = (a.data()['username'] ?? '') as String;
                    final bu = (b.data()['username'] ?? '') as String;
                    return au.toLowerCase().compareTo(bu.toLowerCase());
                    });

                    return Column(
                    children: docs.map((d) {
                        final u = d.data();
                        if (!_match(u)) return const SizedBox.shrink();
                        final memberSince = (u['memberSince'] as Timestamp?)?.toDate();
                        return _UserCard(
                        name: u['name'] ?? '',
                        username: u['username'] ?? '',
                        since: memberSince == null
                            ? '-'
                            : memberSince.toLocal().toString().split('.').first,
                        actions: [
                            ElevatedButton(
                            onPressed: () => _setRole(d.id, 'member'),
                            child: const Text('Remove as admin'),
                            ),
                            OutlinedButton(
                            onPressed: () =>
                                _setRole(d.id, 'first_time', resetRejectCount: true),
                            child: const Text('Remove as member'),
                            ),
                        ],
                        );
                    }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),

            const SizedBox(height: 24),
            Text('Members', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            members.when(
              data: (snap) {
                if (snap.docs.isEmpty) {
                  return const Text('No members yet.');
                }

                final docs = [...snap.docs]..sort((a, b) {
                    final au = (a.data()['username'] ?? a.data()['name'] ?? '').toString();
                    final bu = (b.data()['username'] ?? b.data()['name'] ?? '').toString();
                    return au.toLowerCase().compareTo(bu.toLowerCase());
                    });
                    
                return Column(
                  children: docs.map((d) {
                    final u = d.data();
                    if (!_match(u)) return const SizedBox.shrink();
                    final memberSince = (u['memberSince'] as Timestamp?)?.toDate();
                    return _UserCard(
                      name: u['name'] ?? '',
                      username: u['username'] ?? '',
                      since: memberSince == null ? '-' : memberSince.toLocal().toString().split('.').first,
                      actions: [
                        // Member card buttons
                        ElevatedButton(
                          onPressed: () => _setRole(d.id, 'admin'),
                          child: const Text('Accept as admin'),
                        ),
                        OutlinedButton(
                          onPressed: () => _setRole(d.id, 'first_time', resetRejectCount: true),
                          child: const Text('Remove as member'),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.name,
    required this.username,
    required this.since,
    required this.actions,
  });

  final String name;
  final String username;
  final String since;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.primary;
    final head = base.withOpacity(0.20);
    final body = base.withOpacity(0.12);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: head,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Name: $name', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('User name: $username'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: body,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member Date: $since'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final a in actions) ...[
                      a,
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
