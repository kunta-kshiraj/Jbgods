import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jbgods/widgets/profile_picture_widget.dart';

import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/toast.dart';
import '../../data/auth_providers.dart';
import '../../data/firestore_streams.dart';
import '../../utils/date_utils.dart';
import '../../widgets/profile_picture_widget.dart';
import 'burger_menu.dart';
import 'edit_profile_sheet.dart';
import '../events/participants_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isRequesting = false;

  Future<void> _requestMembership() async {
    setState(() => _isRequesting = true);
    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // Using merge keeps the doc and lets rules treat it as update as well.
      await firestore.collection('requests').doc(user.uid).set({
        'status': 'pending',
        'byUid': user.uid,
        'requestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) showJBToast(context, "Request sent successfully!");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _requestOwnerApproval() async {
    setState(() => _isRequesting = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final firestore = ref.read(firestoreProvider);

      // Get owner data from users collection (stored during signup)
      final doc = await firestore.collection('users').doc(user.uid).get();
      final data = doc.data();

      // Also check owner_requests collection for existing data
      final ownerRequestDoc = await firestore.collection('owner_requests').doc(user.uid).get();
      final ownerRequestData = ownerRequestDoc.data();

      await firestore.collection('owner_requests').doc(user.uid).set({
        'rinkName': data?['rinkName'] ?? ownerRequestData?['rinkName'] ?? '',
        'address': data?['address'] ?? ownerRequestData?['address'] ?? '',
        'ownerName': data?['ownerName'] ?? ownerRequestData?['ownerName'] ?? '',
        'email': data?['email'] ?? user.email ?? '',
        'latitude': data?['latitude'] ?? ownerRequestData?['latitude'],
        'longitude': data?['longitude'] ?? ownerRequestData?['longitude'],
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        showJBToast(context, "Request sent to master admin!");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Widget _buildOwnerRequestButton(
    Map<String, dynamic> userProfile,
    AsyncValue<DocumentSnapshot<Map<String, dynamic>>?> hasPendingRequest,
  ) {
    if (_isRequesting) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: const JBButton(label: "Sending Request...", onPressed: null, outline: true),
      );
    }

    return hasPendingRequest.when(
      data: (requestDoc) {
        final status = requestDoc?.data()?['status'];
        final isPending = requestDoc?.exists == true && status == 'pending';
        final isRejected = requestDoc?.exists == true && status == 'rejected';

        if (isPending) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber, width: 1),
            ),
            child: const JBButton(label: "Pending Owner Request", onPressed: null, outline: true),
          );
        }

        if (isRejected) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: JBButton(
              label: "Request Rejected - Try Again",
              onPressed: _requestOwnerApproval,
              outline: true,
            ),
          );
        }

        return JBButton(
          label: "Request to List Skating Rink",
          onPressed: _requestOwnerApproval,
        );
      },
      loading: () => const SizedBox(height: 44, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => JBButton(
        label: "Request to List Skating Rink",
        onPressed: _requestOwnerApproval,
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Widget _buildRequestButton(
    Map<String, dynamic> userProfile,
    AsyncValue<DocumentSnapshot<Map<String, dynamic>>?> hasPendingRequest,
  ) {
    final rejectCount = userProfile['rejectCount'] ?? 0;

    if (_isRequesting) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: const JBButton(label: "Sending Request...", onPressed: null, outline: true),
      );
    }

    return hasPendingRequest.when(
      data: (requestDoc) {
        final status = requestDoc?.data()?['status'];
        final isPending = requestDoc?.exists == true && status == 'pending';
        final isRejected = requestDoc?.exists == true && status == 'rejected';

        if (rejectCount >= 3) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: const JBButton(label: "Request limit reached", onPressed: null, outline: true),
          );
        }

        if (isPending) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.25),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber, width: 1),
            ),
            child: const JBButton(label: "Pending member request", onPressed: null, outline: true),
          );
        }

        // first_time or rejected (<3) -> can request
        return JBButton(
          label: "Request to Become Member",
          onPressed: _requestMembership,
          outline: isRejected, // just a small visual hint
        );
      },
      loading: () => const SizedBox(height: 44, child: Center(child: CircularProgressIndicator())),
      error: (_, __) {
        if (rejectCount >= 3) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: const JBButton(label: "Request limit reached", onPressed: null, outline: true),
          );
        }
        return JBButton(label: "Request to Become Member", onPressed: _requestMembership);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final userRole = ref.watch(userRoleProvider); // 'first_time' | 'member' | 'admin' | 'master' | 'owner'
    final isAdmin = ref.watch(isAdminProvider);
    final isMaster = userRole == 'master';
    final isOwner = userRole == 'owner';
    final theme = Theme.of(context);

    // Pending request streams
    final hasPendingRequest = ref.watch(pendingRequestProvider);
    final hasPendingOwnerRequest = ref.watch(pendingOwnerRequestProvider);

    // Community count label (only compute/watch for master to avoid rule errors)
    String communityLabel = '';
    if (isMaster) {
      final countAsync = ref.watch(communityCountProvider);
      communityLabel = countAsync.maybeWhen(
        data: (n) => 'Community ($n)',
        orElse: () => 'Community (...)',
      );
    }

    // Show loading only if we're actually loading, not if there's no profile
    final userDocAsync = ref.watch(userDocProvider);
    if (userDocAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    // If no profile data, show a message with logout option
    if (userProfile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Account Not Found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account may have been deleted or there was an error loading your profile.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout and Sign In Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _logout,
                  child: const Text('Or try logging out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: const [
                HeaderLogo(),
                Positioned(top: 35, right: 0, child: BurgerMenuButton()),
              ],
            ),
            const SizedBox(height: 24),
            // Container(
            //   decoration: BoxDecoration(
            //     shape: BoxShape.circle,
            //     border: Border.all(color: theme.colorScheme.primary, width: 4),
            //   ),
            //   padding: const EdgeInsets.all(4),
            //   child: ProfilePictureWidget(
            //     photoProfilePictureWidget(
            //     avatarUrl: userProfile['avatarUrl'],
            //   ),
            // ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 4),
              ),
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: theme.scaffoldBackgroundColor,
                backgroundImage: (userProfile['avatarUrl'] != null && 
                                 (userProfile['avatarUrl'] as String).isNotEmpty)
                    ? NetworkImage(userProfile['avatarUrl'] as String)
                    : null,
                child: (userProfile['avatarUrl'] == null || 
                       (userProfile['avatarUrl'] as String).isEmpty)
                    ? const Text("JB GODS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            Text("Username: ${userProfile['username'] ?? 'N/A'}", style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text("Email: ${userProfile['email'] ?? 'N/A'}", style: theme.textTheme.bodyMedium),
            // Show owner-specific details
            if (userRole == 'first_time_owner' || userRole == 'owner') ...[
              if (userProfile['rinkName'] != null) ...[
                const SizedBox(height: 6),
                Text("Rink Name: ${userProfile['rinkName']}", style: theme.textTheme.bodyMedium),
              ],
              if (userProfile['address'] != null) ...[
                const SizedBox(height: 6),
                Text("Address: ${userProfile['address']}", style: theme.textTheme.bodyMedium),
              ],
              if (userProfile['ownerName'] != null) ...[
                const SizedBox(height: 6),
                Text("Owner Name: ${userProfile['ownerName']}", style: theme.textTheme.bodyMedium),
              ],
            ],
            const SizedBox(height: 6),
            Text(
              "Role: ${userRole.toUpperCase()}",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // first-time users see the request button and message
            if (userRole == 'first_time') ...[
              _buildRequestButton(userProfile, hasPendingRequest),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Become a member to get access for the app",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // First-time owners see the request button
            if (userRole == 'first_time_owner') ...[
              _buildOwnerRequestButton(userProfile, hasPendingOwnerRequest),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Request approval from master admin to list your skating rink and get full access",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Only admins/master can access Admin Requests (NOT owners)
            if (isAdmin && !isOwner) ...[
              JBButton(
                label: "Admin Requests",
                onPressed: () => context.go('/admin/requests'),
              ),
            ],

            // Master-only Community button with count
            if (isMaster) ...[
              const SizedBox(height: 12),
              JBButton(
                label: communityLabel,
                onPressed: () => context.go('/admin/community'),
              ),
              const SizedBox(height: 12),
              JBButton(
                label: "Reports",
                onPressed: () => context.go('/admin/reports'),
              ),
            ],

            // Show "Event Participants" for master and admins (rink owners)
            if (isMaster || isAdmin) ...[
              const SizedBox(height: 12),
              JBButton(
                label: "Event Participants",
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventParticipantsScreen(creatorId: user.uid),
                    ),
                  );
                },
              ),
            ],


            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
