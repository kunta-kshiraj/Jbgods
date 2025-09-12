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
  final stateCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  DateTime? dob;
  bool isLoading = false;

  Future<void> _signUp() async {
    if (!formKey.currentState!.validate()) return;
    
    // Additional DOB validation
    if (dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (dob!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid DOB: Date cannot be in the future'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
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
        'state': stateCtrl.text.trim(),
        'country': countryCtrl.text.trim(),
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
              SizedBox(height: 0),
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
                    JBInput(
                      controller: dobCtrl,
                      label: "Date of Birth (YYYY-MM-DD)",
                      keyboardType: TextInputType.datetime,
                      validator: (v) {
                        if (v == null || v.isEmpty) return "Please enter your date of birth";
                        if (v.length != 10) return "Please use YYYY-MM-DD format";
                        
                        // Try to parse the date
                        try {
                          final parts = v.split('-');
                          if (parts.length != 3) return "Please use YYYY-MM-DD format";
                          
                          final year = int.parse(parts[0]);
                          final month = int.parse(parts[1]);
                          final day = int.parse(parts[2]);
                          
                          final date = DateTime(year, month, day);
                          
                          // Check if date is valid
                          if (date.year != year || date.month != month || date.day != day) {
                            return "Invalid date";
                          }
                          
                          // Check if date is in the future
                          if (date.isAfter(DateTime.now())) {
                            return "Date cannot be in the future";
                          }
                          
                          // Check year range
                          if (year < 1950 || year > 2025) {
                            return "Year must be between 1950 and 2025";
                          }
                          
                          dob = date;
                          return null;
                        } catch (e) {
                          return "Please use YYYY-MM-DD format";
                        }
                      },
                      onChanged: (value) {
                        // Auto-format as user types
                        if (value.length == 4 && !value.contains('-')) {
                          dobCtrl.text = '$value-';
                          // Set cursor position after the dash
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (dobCtrl.text.length >= 5) {
                              dobCtrl.selection = TextSelection.collapsed(offset: 5);
                            }
                          });
                        } else if (value.length == 7 && value[6] != '-') {
                          dobCtrl.text = '${value.substring(0, 7)}-';
                          // Set cursor position after the second dash
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (dobCtrl.text.length >= 8) {
                              dobCtrl.selection = TextSelection.collapsed(offset: 8);
                            }
                          });
                        }
                      },
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: JBInput(controller: stateCtrl, label: "State"),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: JBInput(controller: countryCtrl, label: "Country"),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    JBButton(
                      label: isLoading ? "Creating Account..." : "Sign Up",
                      onPressed: isLoading ? null : () => _signUp(),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already a user? ",
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