import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app_state.dart';
import '../../data/auth_providers.dart';
import '../../data/firestore_streams.dart';
import 'edit_profile_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BurgerMenuButton extends ConsumerWidget {
  const BurgerMenuButton({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.menu, size: 32),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => const BurgerMenuSheet(),
        );
      },
    );
  }
}

class BurgerMenuSheet extends ConsumerWidget {
  const BurgerMenuSheet({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMaster = ref.watch(userRoleProvider) == 'master';
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMaster)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text("Notifications"),
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              },
            ),
          ListTile(
            leading: Icon(Icons.edit),
            title: Text("Edit Profile"),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => const EditProfileSheet(),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.brightness_6),
            title: Text("Theme"),
            onTap: () {
              ref.read(appStateProvider.notifier).toggleTheme();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text("Terms & Privacy Policy"),
            onTap: () {
              Navigator.pop(context);
              context.go('/terms-privacy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.orange),
            title: const Text("Blocked Users"),
            onTap: () {
              Navigator.pop(context);
              _showBlockedUsersDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
            onTap: () async {
              // Read providers BEFORE closing the sheet to avoid using `ref` after dispose
              final firestore = ref.read(firestoreProvider);
              final auth = ref.read(firebaseAuthProvider);
              final appState = ref.read(appStateProvider.notifier);

              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: const Text('This will permanently delete your account and profile data. This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirmed != true) return;

              try {
                final user = auth.currentUser;
                if (user == null) {
                  // If already signed out, just route to login
                  context.go('/login');
                  return;
                }

                // Remove all user-related Firestore docs (best-effort)
                await firestore.collection('users').doc(user.uid).delete().catchError((_) {});
                await firestore.collection('requests').doc(user.uid).delete().catchError((_) {});
                
                // Delete owner_request if exists (but NOT rink - only master can delete rinks)
                await firestore.collection('owner_requests').doc(user.uid).delete().catchError((_) {});
                
                // Delete user's chat messages
                final messagesQuery = await firestore
                    .collection('messages')
                    .where('authorId', isEqualTo: user.uid)
                    .get();
                for (final doc in messagesQuery.docs) {
                  await doc.reference.delete().catchError((_) {});
                }

                // Delete auth user (may require recent login)
                await user.delete();
              } on FirebaseAuthException catch (e) {
                final needsRecent = e.code == 'requires-recent-login';
                if (needsRecent) {
                  // Prompt for password and reauthenticate, then retry once
                  final password = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final ctrl = TextEditingController();
                      return AlertDialog(
                        title: const Text('Re-authenticate'),
                        content: TextField(
                          controller: ctrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Enter your password'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Confirm')),
                        ],
                      );
                    },
                  );

                  if (password != null && password.isNotEmpty) {
                    try {
                      final user = auth.currentUser;
                      if (user != null && user.email != null) {
                        final cred = EmailAuthProvider.credential(email: user.email!, password: password);
                        await user.reauthenticateWithCredential(cred);

                        // Retry deletion after successful reauth
                        await firestore.collection('users').doc(user.uid).delete().catchError((_) {});
                        await firestore.collection('requests').doc(user.uid).delete().catchError((_) {});
                        
                        // Delete owner_request if exists (but NOT rink - only master can delete rinks)
                        await firestore.collection('owner_requests').doc(user.uid).delete().catchError((_) {});
                        
                        // Delete user's chat messages
                        final messagesQuery = await firestore
                            .collection('messages')
                            .where('authorId', isEqualTo: user.uid)
                            .get();
                        for (final doc in messagesQuery.docs) {
                          await doc.reference.delete().catchError((_) {});
                        }
                        
                        await user.delete();
                      }
                    } catch (e2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Re-authentication failed: $e2')),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: ${e.message}')),
                  );
                }
              } catch (e) {
                try { await auth.signOut(); } catch (_) {}
                appState.logOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete account: $e')),
                );
                context.go('/login');
              } finally {
                // Always ensure we end on the login screen.
                try { await auth.signOut(); } catch (_) {}
                appState.logOut();
                context.go('/login');
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Logout"),
            onTap: () async {
              try {
                await ref.read(firebaseAuthProvider).signOut();
                ref.read(appStateProvider.notifier).logOut();
                Navigator.pop(context);
                context.go('/login');
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to logout. Please try again.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Show blocked users dialog with unblock functionality
Future<void> _showBlockedUsersDialog(BuildContext context, WidgetRef ref) async {
  // Read providers BEFORE showing dialog to avoid using ref after widget disposal
  final firestore = ref.read(firestoreProvider);
  final currentUser = ref.read(currentUserProvider);
  
  if (currentUser == null) return;
  
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Blocked Users'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore
              .collection('blockedUsers')
              .where('blockerId', isEqualTo: currentUser.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            
            final docs = snapshot.data?.docs ?? [];
            
            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'No blocked users',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              );
            }
            
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final blockedUserName = data['blockedUserName'] as String? ?? 'Unknown User';
                final blockedUserId = data['blockedUserId'] as String? ?? '';
                
                return ListTile(
                  leading: const Icon(Icons.person_off, color: Colors.orange),
                  title: Text(blockedUserName),
                  subtitle: Text('Blocked'),
                  trailing: TextButton(
                    onPressed: () => _unblockUser(ctx, firestore, currentUser.uid, blockedUserId, blockedUserName),
                    child: const Text('Unblock', style: TextStyle(color: Colors.orange)),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Unblock a user using the same docId format as chat screen
Future<void> _unblockUser(BuildContext context, FirebaseFirestore firestore, String blockerId, String blockedUserId, String userName) async {
  try {
    // Use the same docId format as the chat screen: ${blockerId}_${blockedUserId}
    final docId = '${blockerId}_$blockedUserId';
    print('DEBUG: Attempting to unblock user $blockedUserId with docId: $docId');
    
    await firestore.collection('blockedUsers').doc(docId).delete();
    
    print('DEBUG: Successfully deleted document $docId');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$userName has been unblocked')),
      );
    }
  } catch (e) {
    print('DEBUG: Error during unblock: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unblock user: $e')),
      );
    }
  }
}