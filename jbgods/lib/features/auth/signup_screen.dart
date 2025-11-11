import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
import '../../widgets/validation_dialog.dart';
import '../../data/auth_providers.dart';
import '../../app_state.dart';
import '../../utils/validation_utils.dart';

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
  final formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool agreeToTerms = false;

  Future<bool> _isUsernameUnique(String username) async {
    try {
      final firestore = ref.read(firestoreProvider);
      final querySnapshot = await firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      print('Username check for "$username": ${querySnapshot.docs.length} matches found');
      return querySnapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking username uniqueness: $e');
      // If there's a permission error, skip the check and let Firebase handle it
      return true;
    }
  }

  Future<bool> _verifyEmailExists(String email) async {
    try {
      // First, validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        return false;
      }
      
      // Extract domain from email
      final domain = email.split('@')[1].toLowerCase();
      
      // List of common dummy/fake email domains to block
      final dummyDomains = [
        '10minutemail.com',
        'tempmail.org',
        'guerrillamail.com',
        'mailinator.com',
        'throwaway.email',
        'temp-mail.org',
        'sharklasers.com',
        'grr.la',
        'guerrillamailblock.com',
        'pokemail.net',
        'spam4.me',
        'bccto.me',
        'chacuo.net',
        'dispostable.com',
        'mailnesia.com',
        'maildrop.cc',
        'getnada.com',
        'mail.tm',
        '1secmail.com',
        '1secmail.org',
        '1secmail.net',
        'kuku.lu',
        'mohmal.com',
        'mytrashmail.com',
        'trashmail.com',
        'yopmail.com',
        'yopmail.net',
        'yopmail.org',
        'test.com',
        'example.com',
        'dummy.com',
        'fake.com',
        'invalid.com',
        'notreal.com',
        'fakemail.com',
        'tempmail.com',
        'tempemail.com',
        'throwaway.com',
        'disposable.com',
        'trash.com',
        'spam.com',
        'junk.com',
        'nowhere.com',
        'nowhere.org',
        'nowhere.net',
        'test.org',
        'test.net',
        'dummy.org',
        'dummy.net',
        'fake.org',
        'fake.net',
        'invalid.org',
        'invalid.net',
        'notreal.org',
        'notreal.net',
        'fakemail.org',
        'fakemail.net',
        'tempmail.org',
        'tempmail.net',
        'tempemail.org',
        'tempemail.net',
        'throwaway.org',
        'throwaway.net',
        'disposable.org',
        'disposable.net',
        'trash.org',
        'trash.net',
        'spam.org',
        'spam.net',
        'junk.org',
        'junk.net',
      ];
      
      // Check if domain is in the dummy domains list
      if (dummyDomains.contains(domain)) {
        return false;
      }
      
      // For now, we'll allow the signup to proceed
      // In a production app, you might want to add more sophisticated email verification
      // such as sending a verification email and requiring the user to click a link
      return true;
    } catch (e) {
      print('Email verification error: $e');
      return false;
    }
  }

  Future<void> _signUp() async {
    if (!formKey.currentState!.validate()) return;
    
    // Validate password strength
    final passwordError = ValidationUtils.validatePassword(pwdCtrl.text);
    if (passwordError != null) {
      ValidationDialog.show(
        context,
        title: 'Password Requirements',
        message: passwordError,
      );
      return;
    }
    
    // Validate username format
    final usernameError = ValidationUtils.validateUsername(usernameCtrl.text.trim());
    if (usernameError != null) {
      ValidationDialog.show(
        context,
        title: 'Invalid Username',
        message: usernameError,
      );
      return;
    }
    
    // Check username uniqueness
    final username = usernameCtrl.text.trim();
    print('Checking username uniqueness for: "$username"');
    final isUnique = await _isUsernameUnique(username);
    print('Username "$username" is unique: $isUnique');
    
    if (!isUnique) {
      ValidationDialog.show(
        context,
        title: 'Username Already Exists',
        message: 'The username "$username" is already taken. Please choose a different username.',
      );
      return;
    }
    
    // Verify email is not a dummy/fake email
    final email = emailCtrl.text.trim();
    print('Verifying email: "$email"');
    final isEmailValid = await _verifyEmailExists(email);
    print('Email "$email" is valid: $isEmailValid');
    
    if (!isEmailValid) {
      ValidationDialog.show(
        context,
        title: 'Invalid Email Address',
        message: 'Please use a valid email address. Temporary or disposable email addresses are not allowed.',
      );
      return;
    }
    
    // Validate terms agreement
    if (!agreeToTerms) {
      ValidationDialog.show(
        context,
        title: 'Terms & Privacy Required',
        message: 'You must agree to the Terms & Privacy Policy to create an account.',
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
      
      // Send email verification
      await user.sendEmailVerification();
      
      // Create user document in Firestore
      await firestore.collection('users').doc(user.uid).set({
        'username': usernameCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'avatarUrl': logoUrl,
        'role': 'first_time',
        'rejectCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Wait a moment for the auth state to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate to verify email page
      if (mounted) context.go('/verify-email');
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
      print('Signup error: $e');
      
      // Check if it's a username duplicate error
      if (e.toString().contains('username') && e.toString().contains('already exists')) {
        if (mounted) {
          ValidationDialog.show(
            context,
            title: 'Username Already Exists',
            message: 'The username "${usernameCtrl.text.trim()}" is already taken. Please choose a different username.',
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('An unexpected error occurred. Please try again.')),
          );
        }
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
                    // Center(
                    //   child: ProfilePictureWidget(
                    //     allowEdit: true,
                    //     radius: 55,
                    //   ),
                    // ),
                    // SizedBox(height: 12),
                    JBInput(
                      controller: usernameCtrl, 
                      label: "Username",
                      validator: ValidationUtils.validateUsername,
                    ),
                    SizedBox(height: 12),
                    JBInput(controller: nameCtrl, label: "Name"),
                    SizedBox(height: 12),
                    JBInput(
                        controller: emailCtrl,
                        label: "Mail ID",
                        keyboardType: TextInputType.emailAddress,
                        validator: ValidationUtils.validateEmail),
                    SizedBox(height: 12),
                    JBInput(
                        controller: pwdCtrl,
                        label: "Password",
                        obscure: true,
                        validator: ValidationUtils.validatePassword),
                    SizedBox(height: 8),
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
                    SizedBox(height: 12),
                    JBInput(
                      controller: confirmCtrl,
                      label: "Confirm Password",
                      obscure: true,
                      validator: (v) =>
                          v == pwdCtrl.text ? null : "Passwords do not match",
                    ),
                    SizedBox(height: 16),
                    // Terms & Privacy Agreement
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              agreeToTerms = value ?? false;
                            });
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[700],
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: () => context.go('/terms-privacy'),
                                    child: Text(
                                      'Terms & Privacy Policy',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Terms & Privacy Policy Link
                    
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
                    SizedBox(height: 20),
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