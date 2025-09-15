import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../data/auth_providers.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>  with WidgetsBindingObserver{
  bool _isEmailVerified = false;
  Timer? _timer;
  bool _canResendEmail = true;
  DateTime? _lastEmailSent;
  int _resendAttempts = 0;
  int _countdownSeconds = 0;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkEmailVerified();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkEmailVerified();
    });
  }
   @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerified();
    }
  }
Future<void> _checkEmailVerified() async {
  if (_isChecking) return;
  _isChecking = true;
  try {
    // Force refresh from server and refresh ID token
    await FirebaseAuth.instance.currentUser?.reload();
    await FirebaseAuth.instance.currentUser?.getIdToken(true);

    final fresh = FirebaseAuth.instance.currentUser;
    final isVerified = fresh?.emailVerified ?? false;

    if (!mounted) return;

    if (isVerified) {
      _timer?.cancel();

      // Optional toast/snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Email verified! Please log in.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Sign out so user logs in cleanly
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      // Go to login page
      context.go('/login');
      return;
    }

    // Not verified yet → stay on this screen
    setState(() {}); // update any UI if needed
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error checking verification: $e')),
    );
  } finally {
    _isChecking = false;
  }
}


  Future<void> _sendVerificationEmail() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // Check rate limiting
      final now = DateTime.now();
      if (_lastEmailSent != null) {
        final timeSinceLastEmail = now.difference(_lastEmailSent!);
        if (timeSinceLastEmail.inSeconds < 60) {
          final remainingTime = 60 - timeSinceLastEmail.inSeconds;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait ${remainingTime}s before sending another email'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Check if too many attempts
      if (_resendAttempts >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too many attempts. Please wait 5 minutes before trying again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('Sending verification email to: ${user.email}');
      await user.sendEmailVerification();
      print('Verification email sent successfully');
      
      if (mounted) {
        setState(() {
          _canResendEmail = false;
          _lastEmailSent = now;
          _resendAttempts++;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to ${user.email}! Please check your inbox and spam folder.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // Start countdown timer
        _countdownSeconds = 60;
        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _countdownSeconds--;
            });
            
            if (_countdownSeconds <= 0) {
              timer.cancel();
              setState(() {
                _canResendEmail = true;
              });
            }
          } else {
            timer.cancel();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send verification email';
        
        if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many requests. Please wait 5 minutes before trying again.';
          setState(() {
            _canResendEmail = false;
          });
          
          // Re-enable after 5 minutes
          Timer(const Duration(minutes: 5), () {
            if (mounted) {
              setState(() {
                _canResendEmail = true;
                _resendAttempts = 0;
              });
            }
          });
        } else if (e.toString().contains('network-request-failed')) {
          errorMessage = 'Network error. Please check your internet connection.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelVerification() async {
    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification cancelled. Please sign up again.'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? 'your email';

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              
              // Logo
              const HeaderLogo(),
              
              const SizedBox(height: 48),
              
              // Verification Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Verify Your Email',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Description
              Text(
                'A verification email has been sent to:',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Email
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  email,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Instructions Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Next Steps:',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Check your email inbox (and spam folder)\n'
                      '2. Click the verification link in the email\n'
                      '3. Return to this app - you\'ll be redirected automatically\n'
                      '4. If you don\'t see the email, click "Resend" below',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Resend Email Button
              SizedBox(
                width: double.infinity,
                child: JBButton(
                  label: _canResendEmail 
                    ? 'Resend Verification Email' 
                    : 'Please wait ${_countdownSeconds}s',
                  onPressed: _canResendEmail ? _sendVerificationEmail : null,
                  outline: true,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Cancel Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _cancelVerification,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}