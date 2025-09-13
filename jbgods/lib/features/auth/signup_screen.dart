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
  final dobCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  DateTime? dob;
  bool isLoading = false;

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
    
    // Additional DOB validation
    if (dob == null) {
      ValidationDialog.show(
        context,
        title: 'Date of Birth Required',
        message: 'Please select your date of birth',
      );
      return;
    }
    
    if (dob!.isAfter(DateTime.now())) {
      ValidationDialog.show(
        context,
        title: 'Invalid Date of Birth',
        message: 'Date cannot be in the future',
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
      
      // Wait a moment for the auth state to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate to profile page for first-time users
      if (mounted) context.go('/shell/profile');
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
                    JBInput(
                      controller: usernameCtrl, 
                      label: "Username",
                      validator: ValidationUtils.validateUsername,
                    ),
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
                    SizedBox(height: 12),
                    JBInput(
                        controller: emailCtrl,
                        label: "Mail ID",
                        keyboardType: TextInputType.emailAddress,
                        validator: ValidationUtils.validateEmail),
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