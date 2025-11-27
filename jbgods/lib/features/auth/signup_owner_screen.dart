import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
import '../../widgets/validation_dialog.dart';
import '../../data/auth_providers.dart';
import '../../utils/validation_utils.dart';

class SignUpOwnerScreen extends ConsumerStatefulWidget {
  const SignUpOwnerScreen({super.key});

  @override
  ConsumerState<SignUpOwnerScreen> createState() => _SignUpOwnerScreenState();
}

class _SignUpOwnerScreenState extends ConsumerState<SignUpOwnerScreen> {
  final rinkNameCtrl = TextEditingController();
  final address1Ctrl = TextEditingController();
  final address2Ctrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final ownerNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void dispose() {
    rinkNameCtrl.dispose();
    address1Ctrl.dispose();
    address2Ctrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    ownerNameCtrl.dispose();
    emailCtrl.dispose();
    pwdCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  String _buildFullAddress() {
    final parts = <String>[];
    if (address1Ctrl.text.trim().isNotEmpty) parts.add(address1Ctrl.text.trim());
    if (address2Ctrl.text.trim().isNotEmpty) parts.add(address2Ctrl.text.trim());
    if (cityCtrl.text.trim().isNotEmpty) parts.add(cityCtrl.text.trim());
    if (stateCtrl.text.trim().isNotEmpty) parts.add(stateCtrl.text.trim());
    return parts.join(', ');
  }

  Future<void> _signUpOwner() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      // Build full address from components
      final fullAddress = _buildFullAddress();
      if (fullAddress.isEmpty) {
        ValidationDialog.show(
          context,
          title: 'Address Required',
          message: 'Please enter at least Address 1, City, and State.',
        );
        setState(() => isLoading = false);
        return;
      }

      // Convert address → coordinates internally
      double? latitude;
      double? longitude;

      try {
        final locations = await locationFromAddress(fullAddress);
        if (locations.isEmpty) {
          ValidationDialog.show(
            context,
            title: 'Invalid Address',
            message: 'Could not locate this address. Please recheck or be more specific.',
          );
          setState(() => isLoading = false);
          return;
        }
        latitude = locations.first.latitude;
        longitude = locations.first.longitude;
      } catch (e) {
        ValidationDialog.show(
          context,
          title: 'Address Not Found',
          message: 'We couldn\'t find that address. Try entering city/state or ZIP code too.',
        );
        setState(() => isLoading = false);
        return;
      }

      final auth = ref.read(firebaseAuthProvider);
      final firestore = ref.read(firestoreProvider);

      // Create new Firebase Auth user
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: pwdCtrl.text.trim(),
      );
      final user = userCredential.user!;
      await user.sendEmailVerification();

      // Save user record with owner details
      await firestore.collection('users').doc(user.uid).set({
        'email': emailCtrl.text.trim(),
        'role': 'first_time_owner',
        'rinkName': rinkNameCtrl.text.trim(),
        'address': fullAddress,
        'address1': address1Ctrl.text.trim(),
        'address2': address2Ctrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'ownerName': ownerNameCtrl.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Store owner request (waiting for master approval)
      await firestore.collection('owner_requests').doc(user.uid).set({
        'rinkName': rinkNameCtrl.text.trim(),
        'address': fullAddress,
        'address1': address1Ctrl.text.trim(),
        'address2': address2Ctrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'ownerName': ownerNameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Store rink data (so map can load once approved)
      await firestore.collection('rinks').doc(user.uid).set({
        'rinkName': rinkNameCtrl.text.trim(),
        'address': fullAddress,
        'address1': address1Ctrl.text.trim(),
        'address2': address2Ctrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'ownerName': ownerNameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Please verify before logging in.'),
          backgroundColor: Colors.green,
        ),
      );

      context.go('/verify-email');
    } on FirebaseAuthException catch (e) {
      String msg = 'Sign up failed. Please try again.';
      if (e.code == 'email-already-in-use') msg = 'Email already registered.';
      else if (e.code == 'weak-password') msg = 'Password is too weak.';
      else if (e.code == 'invalid-email') msg = 'Invalid email address.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const HeaderLogo(),
              SizedBox(height: 32),
              Text(
                "Sign Up as Skating Rink Owner",
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
              ),
              SizedBox(height: 24),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    JBInput(
                      controller: rinkNameCtrl,
                      label: "Rink Name",
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter rink name" : null,
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: address1Ctrl,
                      label: "Address 1",
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter address line 1" : null,
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: address2Ctrl,
                      label: "Address 2 (Optional)",
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: cityCtrl,
                      label: "City",
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter city" : null,
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: stateCtrl,
                      label: "State",
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter state" : null,
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: ownerNameCtrl,
                      label: "Owner Name",
                      validator: (v) =>
                          v == null || v.isEmpty ? "Enter owner name" : null,
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: emailCtrl,
                      label: "Email",
                      keyboardType: TextInputType.emailAddress,
                      validator: ValidationUtils.validateEmail,
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: pwdCtrl,
                      label: "Password",
                      obscure: true,
                      validator: ValidationUtils.validatePassword,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password Requirements:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Must be at least 8 characters with uppercase, lowercase, special character, and digit',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    JBInput(
                      controller: confirmCtrl,
                      label: "Confirm Password",
                      obscure: true,
                      validator: (v) =>
                          v == pwdCtrl.text ? null : "Passwords do not match",
                    ),
                    const SizedBox(height: 24),
                    JBButton(
                      label: isLoading ? "Creating..." : "Sign Up",
                      onPressed: isLoading ? null : _signUpOwner,
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text(
                              "Click here to login",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
