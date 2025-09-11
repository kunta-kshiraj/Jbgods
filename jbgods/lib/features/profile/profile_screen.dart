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

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  
  Future<void> _requestMembership(WidgetRef ref, BuildContext context) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserProvider);
      
      if (user == null) return;
      
      await firestore.collection('requests').doc(user.uid).set({
        'status': 'pending',
        'byUid': user.uid,
        'requestedAt': FieldValue.serverTimestamp(),
      });
      
      if (context.mounted) {
        showJBToast(context, "Request sent successfully!");
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request. Please try again.')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text("Address: ${userProfile['address']}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 6),
            Text("Role: ${userRole.toUpperCase()}", style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 24),
            
            // Show different buttons based on user role and request status
            if (userRole == 'first_time') ...[
              hasPendingRequest.when(
                data: (requestDoc) => JBButton(
                  label: requestDoc?.exists == true && requestDoc?.data()?['status'] == 'pending'
                      ? "Request Pending"
                      : "Request to Become Member",
                  onPressed: requestDoc?.exists == true && requestDoc?.data()?['status'] == 'pending'
                      ? null
                      : () => _requestMembership(ref, context),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => JBButton(
                  label: "Request to Become Member",
                  onPressed: () => _requestMembership(ref, context),
                ),
              ),
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