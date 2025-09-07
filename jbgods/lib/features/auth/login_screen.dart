import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
import '../../app_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailCtrl = TextEditingController();
  final pwdCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

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
                      label: "Log In",
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        ref.read(appStateProvider.notifier).logIn();
                        context.go('/shell/home');
                      },
                    ),
                    SizedBox(height: 16),
                    // Demo login button
                    JBButton(
                      label: "Demo Login (Admin)",
                      outline: true,
                      onPressed: () {
                        ref.read(appStateProvider.notifier).logIn(isAdmin: true);
                        context.go('/shell/home');
                      },
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Demo Credentials:\nEmail: admin@jbgods.com\nPassword: admin123",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
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