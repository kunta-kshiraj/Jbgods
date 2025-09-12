import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/toast.dart';
import '../../data/auth_providers.dart';
import '../../utils/date_utils.dart';
import 'burger_menu.dart';

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
      
      // Use set with merge: true to avoid create permission issues
      await firestore.collection('requests').doc(user.uid).set({
        'status': 'pending',
        'byUid': user.uid,
        'requestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        showJBToast(context, "Request sent successfully!");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }
  
  Widget _buildRequestButton(
    Map<String, dynamic> userProfile,
    AsyncValue<DocumentSnapshot<Map<String, dynamic>>?> hasPendingRequest,
    ThemeData theme,
  ) {
    final rejectCount = userProfile['rejectCount'] ?? 0;
    
    // Show loading state if currently requesting
    if (_isRequesting) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange, width: 1),
        ),
        child: JBButton(
          label: "Sending Request...",
          onPressed: null,
          outline: true,
        ),
      );
    }
    
    return hasPendingRequest.when(
      data: (requestDoc) {
        final isPending = requestDoc?.exists == true && requestDoc?.data()?['status'] == 'pending';
        final isRejected = requestDoc?.exists == true && requestDoc?.data()?['status'] == 'rejected';
        
        // Rule: After 3 rejects, button becomes disabled
        if (rejectCount >= 3) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: JBButton(
              label: "Request limit reached",
              onPressed: null,
              outline: true,
            ),
          );
        }
        
        // Rule: While pending, button is disabled and shows "Pending member request" in yellow
        if (isPending) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: JBButton(
              label: "Pending member request",
              onPressed: null,
              outline: true,
            ),
          );
        }
        
        // Rule: If rejected and rejectCount < 3, user can re-request
        if (isRejected) {
          return JBButton(
            label: "Request to Become Member",
            onPressed: _requestMembership,
            outline: true,
          );
        }
        
        // Rule: First-time user can create a request
        return JBButton(
          label: "Request to Become Member",
          onPressed: _requestMembership,
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, __) {
        if (rejectCount >= 3) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: JBButton(
              label: "Request limit reached",
              onPressed: null,
              outline: true,
            ),
          );
        }
        return JBButton(
          label: "Request to Become Member",
          onPressed: _requestMembership,
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final userRole = ref.watch(userRoleProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final theme = Theme.of(context);
    
    // Check if there's a pending request
    final hasPendingRequest = ref.watch(pendingRequestProvider);
    
    if (userProfile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                const HeaderLogo(),
                Positioned(
                  top: 35,
                  right: 0,
                  child: const BurgerMenuButton(),
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 4),
              ),
              padding: EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: theme.scaffoldBackgroundColor,
                backgroundImage: NetworkImage(userProfile['avatarUrl'] ?? ''),
                child: (userProfile['avatarUrl'] ?? '').isEmpty
                    ? Text("JB GODS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            SizedBox(height: 20),
            Text("Username: ${userProfile['username']}", style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18)),
            SizedBox(height: 6),
            Text("Age: ${ageFromDob(userProfile['dob'])}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 6),
            Text("Mail ID: ${userProfile['email']}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 6),
            Text("State: ${userProfile['state'] ?? 'Not provided'}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 6),
            Text("Country: ${userProfile['country'] ?? 'Not provided'}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 6),
            Text("Role: ${userRole.toUpperCase()}", style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 24),
            
            // Show different buttons based on user role and request status
            if (userRole == 'first_time') ...[
              _buildRequestButton(userProfile, hasPendingRequest, theme),
            ] else if (isAdmin) ...[
              JBButton(
                label: "Admin Requests",
                onPressed: () => context.go('/admin/requests'),
              ),
            ],
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}