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
import '../../services/stripe_service.dart';
import 'burger_menu.dart';
import 'edit_profile_sheet.dart';
import '../events/participants_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Annual subscription expiration: 1 year (365 days)
const Duration _SUBSCRIPTION_EXPIRATION_DURATION = Duration(days: 365);

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

  Future<void> _expireSubscription(String subscriptionId) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('rose_awards_subscriptions').doc(subscriptionId);
      
      // Check current status to avoid unnecessary updates
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['status'] == 'active') {
        await docRef.update({
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
        });
        // Force UI refresh
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      // Silently handle error - subscription might already be updated
    }
  }


  Future<void> _handleCancelSubscription() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please ensure you are logged in.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your Rose Awards voting membership? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final firestore = ref.read(firestoreProvider);
      
      // Mark subscription as cancelled in Firestore
      await firestore.collection('rose_awards_subscriptions').doc(user.uid).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Wait for next frame
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 300));

      // Dismiss loading indicator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Refresh UI
      if (mounted) {
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Subscription cancelled successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading indicator
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be dismissed
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel subscription: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleRoseAwardsPayment() async {
    final user = ref.read(currentUserProvider);
    if (user == null || user.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please ensure you are logged in with a valid email.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Store context before async operations
    final navigatorContext = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );

    try {
      final stripeService = ref.read(stripePaymentServiceProvider);
      final firestore = ref.read(firestoreProvider);
      final theme = Theme.of(context);
      final themeMode = theme.brightness == Brightness.dark 
          ? ThemeMode.dark 
          : ThemeMode.light;

      // Initialize payment sheet with Price ID and user email
      await stripeService.initializePaymentSheetWithPriceId(
        priceId: 'price_1ST7AJDgeZGoTF8LENWO7rYS',
        merchantName: 'JB Gods',
        style: themeMode,
        customerEmail: user.email,
      );

      // Dismiss loading indicator
      if (mounted && navigatorContext.canPop()) {
        navigatorContext.pop();
      }

      // Small delay to ensure dialog is fully dismissed
      await Future.delayed(const Duration(milliseconds: 200));

      // Present payment sheet
      await stripeService.presentPaymentSheet();

      // Wait for the next frame to ensure payment sheet is fully dismissed
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 500));

      // Payment successful - save subscription to Firestore
      final expiresAtDate = DateTime.now().add(_SUBSCRIPTION_EXPIRATION_DURATION);
      final expiresAtTimestamp = Timestamp.fromDate(expiresAtDate);
      
      try {
        await firestore.collection('rose_awards_subscriptions').doc(user.uid).set({
          'userId': user.uid,
          'email': user.email,
          'priceId': 'price_1ST7AJDgeZGoTF8LENWO7rYS',
          'amount': 500.00,
          'currency': 'USD',
          'status': 'active',
          'subscriptionType': 'annual',
          'subscribedAt': FieldValue.serverTimestamp(),
          'expiresAt': expiresAtTimestamp,
        }, SetOptions(merge: true));

        // Get user's name from profile
        final userProfile = ref.read(userProfileProvider);
        final fullName = userProfile?['name'] ?? userProfile?['username'] ?? 'Valued Member';

        // Trigger email sending via Cloud Function
        try {
          final functions = ref.read(firebaseFunctionsProvider);
          await functions.httpsCallable('sendRoseAwardsSubscriptionEmail').call({
            'subscriptionId': user.uid,
            'email': user.email,
            'fullName': fullName,
            'amountPaid': 500.00,
            'subscriptionType': 'annual',
            'expiresAt': expiresAtDate.toIso8601String(),
          });
        } catch (emailError) {
          // Log error but don't fail the subscription
          debugPrint('Failed to send Rose Awards subscription email: $emailError');
          // Update subscription to indicate email failed
          await firestore.collection('rose_awards_subscriptions').doc(user.uid).update({
            'emailSent': false,
            'emailError': emailError.toString(),
          });
        }
      } catch (firestoreError) {
        // Payment was successful but Firestore save failed
        // Still show success message since payment went through
        if (mounted) {
          await WidgetsBinding.instance.endOfFrame;
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('✅ Payment successful! However, there was an issue saving your subscription. Please contact support. Error: ${firestoreError.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return; // Exit early since we've handled the error
      }

      // Payment successful - show message and refresh UI
      if (mounted) {
        // Wait for next frame before updating UI
        await WidgetsBinding.instance.endOfFrame;
        
        // Force a rebuild to update the button state
        setState(() {});
        
        // Show success message using stored context
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('✅ Payment successful! You are now a voting member. Confirmation email sent.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading indicator if still showing
      if (mounted) {
        try {
          if (navigatorContext.canPop()) {
            navigatorContext.pop();
          }
        } catch (_) {
          // Dialog might already be dismissed
        }
      }

      // Wait for next frame
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
    final roseAwardsSubscription = ref.watch(roseAwardsSubscriptionProvider);

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
      body: SingleChildScrollView(
        child: Padding(
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
            // Show Rose Awards voting member status if subscribed
            if (!isMaster) ...[
              roseAwardsSubscription.when(
                data: (subscriptionDoc) {
                  if (subscriptionDoc?.exists == true) {
                    final data = subscriptionDoc!.data()!;
                    final status = data['status'] as String?;
                    final expiresAt = data['expiresAt'] as Timestamp?;
                    
                    // Check if subscription is active and not expired
                    final isExpired = expiresAt != null && 
                        expiresAt.toDate().isBefore(DateTime.now());
                    final hasActiveSubscription = status == 'active' && !isExpired;
                    
                    // Auto-expire subscription if it has passed expiration date
                    if (status == 'active' && isExpired) {
                      // Update subscription status to expired immediately
                      _expireSubscription(subscriptionDoc.id);
                    }
                    
                    if (hasActiveSubscription) {
                      return Column(
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            "You are now a Rose Awards voting member",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: 24),

            // Rose Awards section - shown to all users except master
            if (!isMaster) ...[
              roseAwardsSubscription.when(
                data: (subscriptionDoc) {
                  bool hasActiveSubscription = false;
                  
                  if (subscriptionDoc?.exists == true) {
                    final data = subscriptionDoc!.data()!;
                    final status = data['status'] as String?;
                    final expiresAt = data['expiresAt'] as Timestamp?;
                    
                    // Check if subscription is active and not expired
                    final isExpired = expiresAt != null && 
                        expiresAt.toDate().isBefore(DateTime.now());
                    hasActiveSubscription = status == 'active' && !isExpired;
                    
                    // Auto-expire subscription if it has passed expiration date
                    if (status == 'active' && isExpired) {
                      // Update subscription status to expired immediately
                      _expireSubscription(subscriptionDoc.id);
                    }
                  }
                  
                  if (hasActiveSubscription) {
                    // Show voting button
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: JBButton(
                        label: "Click to give your vote",
                        onPressed: () => context.go('/voting/rose-awards'),
                      ),
                    );
                  } else {
                    // Show payment button
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          JBButton(
                            label: "Vote for Rose Awards",
                            onPressed: _handleRoseAwardsPayment,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Become a voting member by paying an annual fee of 500.00 USD",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                },
                loading: () => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      JBButton(
                        label: "Vote for Rose Awards",
                        onPressed: _handleRoseAwardsPayment,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Become a voting member by paying a daily fee of 500.00 USD",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

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
                label: "Event Requests",
                onPressed: () => context.go('/admin/event-requests'),
              ),
              const SizedBox(height: 12),
              JBButton(
                label: "Reports",
                onPressed: () => context.go('/admin/reports'),
              ),
              const SizedBox(height: 12),
              JBButton(
                label: "Annual memberships",
                onPressed: () => context.go('/admin/annual-memberships'),
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
                      builder: (_) => EventParticipantsScreen(
                        creatorId: user.uid,
                        isMaster: isMaster,
                      ),
                    ),
                  );
                },
              ),
            ],


            const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
