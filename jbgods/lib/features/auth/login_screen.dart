import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
import '../../data/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> _signIn() async {
    if (!formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: pwdCtrl.text,
      );
      // Navigation will be handled by router redirect
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
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
              SizedBox(height: 32),
              Text("Login", style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24)),
              SizedBox(height: 24),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    JBInput(
                      controller: emailCtrl,
                      label: "Email",
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v != null && v.contains('@') ? null : "Invalid email",
                    ),
                    SizedBox(height: 16),
                    JBInput(
                      controller: pwdCtrl,
                      label: "Password",
                      obscure: true,
                      validator: (v) =>
                          v != null && v.length >= 8 ? null : "At least 8 chars",
                    ),
                    SizedBox(height: 32),
                    JBButton(
                      label: isLoading ? "Signing In..." : "Log In",
                      onPressed: isLoading ? null : () => _signIn(),
                    ),
                    SizedBox(height: 16),
                    // Demo login button (for testing)
                    // JBButton(
                    //   label: "Demo Login (Admin)",
                    //   outline: true,
                    //   onPressed: isLoading ? null : () async {
                    //     setState(() => isLoading = true);
                    //     try {
                    //       final auth = ref.read(firebaseAuthProvider);
                    //       await auth.signInWithEmailAndPassword(
                    //         email: 'admin@jbgods.com',
                    //         password: 'admin123',
                    //       );
                    //     } catch (e) {
                    //       if (mounted) {
                    //         ScaffoldMessenger.of(context).showSnackBar(
                    //           const SnackBar(content: Text('Demo login failed. Please sign up first.')),
                    //         );
                    //       }
                    //     } finally {
                    //       if (mounted) {
                    //         setState(() => isLoading = false);
                    //       }
                    //     }
                    //   },
                    // ),
                    // SizedBox(height: 8),
                    // Text(
                    //   "Demo Credentials:\nEmail: admin@jbgods.com\nPassword: admin123",
                    //   style: theme.textTheme.bodySmall?.copyWith(
                    //     color: Colors.grey[600],
                    //     fontSize: 12,
                    //   ),
                    //   textAlign: TextAlign.center,
                    // ),
                    SizedBox(height: 16),
                    JBButton(
                      label: "Sign Up",
                      outline: true,
                      onPressed: () => context.go('/signup'),
                    )
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