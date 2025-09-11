import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
import '../../data/auth_providers.dart';
import '../../app_state.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final usernameCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final dobCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  DateTime? dob;
  bool isLoading = false;

  Future<void> _signUp() async {
    if (!formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      final auth = ref.read(firebaseAuthProvider);
      final firestore = ref.read(firestoreProvider);
      
      // Create user with email and password
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: pwdCtrl.text,
      );
      
      final user = userCredential.user!;
      
      // Create user document in Firestore
      await firestore.collection('users').doc(user.uid).set({
        'username': usernameCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'dob': dobCtrl.text,
        'address': addressCtrl.text.trim(),
        'avatarUrl': logoUrl,
        'role': 'first_time',
        'rejectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Navigation will be handled by router redirect
    } on FirebaseAuthException catch (e) {
      String message = 'Sign up failed. Please try again.';
      switch (e.code) {
        case 'weak-password':
          message = 'Password is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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
              SizedBox(height: 24),
              Text("Sign Up", style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24)),
              SizedBox(height: 16),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    JBInput(controller: usernameCtrl, label: "Username"),
                    SizedBox(height: 12),
                    JBInput(
                        controller: pwdCtrl,
                        label: "Password",
                        obscure: true,
                        validator: (v) =>
                            v != null && v.length >= 8 ? null : "Min 8 chars"),
                    SizedBox(height: 12),
                    JBInput(
                      controller: confirmCtrl,
                      label: "Confirm Password",
                      obscure: true,
                      validator: (v) =>
                          v == pwdCtrl.text ? null : "Passwords do not match",
                    ),
                    SizedBox(height: 12),
                    JBInput(
                        controller: emailCtrl,
                        label: "Mail ID",
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v != null && v.contains('@') ? null : "Invalid email"),
                    SizedBox(height: 12),
                    JBInput(controller: nameCtrl, label: "Name"),
                    SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(1990, 1, 1),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          dob = picked;
                          dobCtrl.text =
                              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        }
                      },
                      child: AbsorbPointer(
                        child: JBInput(
                            controller: dobCtrl,
                            label: "Date of Birth",
                            keyboardType: TextInputType.datetime,
                            validator: (v) =>
                                v != null && v.length == 10 ? null : "Pick DOB"),
                      ),
                    ),
                    SizedBox(height: 12),
                    JBInput(controller: addressCtrl, label: "Address"),
                    SizedBox(height: 24),
                    JBButton(
                      label: isLoading ? "Creating Account..." : "Sign Up",
                      onPressed: isLoading ? null : () => _signUp(),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}