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
  bool _adminsExpanded = true;
  bool _membersExpanded = true;
  bool _ownersExpanded = true;

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
    ref.invalidate(ownersStreamProvider);
    ref.invalidate(communityCountProvider);
  }

  bool _match(Map<String, dynamic> u) {
    if (_q.isEmpty) return true;
    final needle = _q.toLowerCase();
    final name = (u['name'] ?? '').toString().toLowerCase();
    final username = (u['username'] ?? '').toString().toLowerCase();
    final email = (u['email'] ?? '').toString().toLowerCase();
    final rinkName = (u['rinkName'] ?? '').toString().toLowerCase();
    final address = (u['address'] ?? '').toString().toLowerCase();
    final ownerName = (u['ownerName'] ?? '').toString().toLowerCase();
    return name.contains(needle) || 
           username.contains(needle) || 
           email.contains(needle) ||
           rinkName.contains(needle) ||
           address.contains(needle) ||
           ownerName.contains(needle);
  }
  
  bool _matchOwner(Map<String, dynamic> u) {
    if (_q.isEmpty) return true;
    final needle = _q.toLowerCase();
    final rinkName = (u['rinkName'] ?? '').toString().toLowerCase();
    final address = (u['address'] ?? '').toString().toLowerCase();
    final ownerName = (u['ownerName'] ?? '').toString().toLowerCase();
    final email = (u['email'] ?? '').toString().toLowerCase();
    return rinkName.contains(needle) ||
           address.contains(needle) ||
           ownerName.contains(needle) ||
           email.contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final admins = ref.watch(adminsStreamProvider);
    final members = ref.watch(membersStreamProvider);
    final owners = ref.watch(ownersStreamProvider);

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
                  ref.invalidate(ownersStreamProvider);
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
                hintText: 'Search name / username / email / rink / address',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 20),

            // Admins Section Header
            InkWell(
              onTap: () => setState(() => _adminsExpanded = !_adminsExpanded),
              child: Row(
                children: [
                  Text('Admins', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _adminsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _adminsExpanded
                  ? admins.when(
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
                        email: u['email'] ?? '',
                        since: memberSince == null
                            ? '-'
                            : memberSince.toLocal().toString().split('.').first,
                        actions: [
                            ElevatedButton(
                              onPressed: () => _setRole(d.id, 'member'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Remove as admin', style: TextStyle(fontSize: 12)),
                            ),
                            OutlinedButton(
                              onPressed: () => _setRole(d.id, 'first_time', resetRejectCount: true),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: const Text('Remove as member', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                        );
                    }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),
            // Members Section Header
            InkWell(
              onTap: () => setState(() => _membersExpanded = !_membersExpanded),
              child: Row(
                children: [
                  Text('Members', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _membersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _membersExpanded
                  ? members.when(
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
                      email: u['email'] ?? '',
                      since: memberSince == null ? '-' : memberSince.toLocal().toString().split('.').first,
                      actions: [
                        // Member card buttons
                        ElevatedButton(
                          onPressed: () => _setRole(d.id, 'admin'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Accept as admin', style: TextStyle(fontSize: 12)),
                        ),
                        OutlinedButton(
                          onPressed: () => _setRole(d.id, 'first_time', resetRejectCount: true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Remove as member', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),
            // Owners Section Header
            InkWell(
              onTap: () => setState(() => _ownersExpanded = !_ownersExpanded),
              child: Row(
                children: [
                  Text('Skating Rink Owners', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _ownersExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _ownersExpanded
                  ? owners.when(
              data: (snap) {
                if (snap.docs.isEmpty) {
                  return const Text('No owners yet.');
                }

                final docs = [...snap.docs]..sort((a, b) {
                    final ar = (a.data()['rinkName'] ?? '').toString();
                    final br = (b.data()['rinkName'] ?? '').toString();
                    return ar.toLowerCase().compareTo(br.toLowerCase());
                  });
                    
                return Column(
                  children: docs.map((d) {
                    final u = d.data();
                    if (!_matchOwner(u)) return const SizedBox.shrink();
                    return _OwnerCard(
                      rinkName: u['rinkName'] ?? '',
                      address: u['address'] ?? '',
                      ownerName: u['ownerName'] ?? '',
                      email: u['email'] ?? '',
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            )
                  : const SizedBox.shrink(),
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
    required this.email,
    required this.since,
    required this.actions,
  });

  final String name;
  final String username;
  final String email;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Name: $name', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('User name: $username'),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Email: $email', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: body,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  Expanded(child: actions[i]),
                  if (i < actions.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({
    required this.rinkName,
    required this.address,
    required this.ownerName,
    required this.email,
  });

  final String rinkName;
  final String address;
  final String ownerName;
  final String email;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rink: $rinkName',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (ownerName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Owner: $ownerName', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9))),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: body,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place, size: 16, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Address: $address',
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (email.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.email, size: 16, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Email: $email',
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
