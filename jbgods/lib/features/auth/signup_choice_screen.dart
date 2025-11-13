import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';

class SignupChoiceScreen extends StatelessWidget {
  const SignupChoiceScreen({super.key});

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
                "Join the Community",
                style: theme.textTheme.headlineMedium?.copyWith(fontSize: 24),
              ),
              SizedBox(height: 24),
              JBButton(
                label: "Sign-up as Member",
                onPressed: () => context.go('/signup/member'),
              ),
              SizedBox(height: 12),
              JBButton(
                label: "Sign-up as Skating Rink Owner",
                onPressed: () => context.go('/signup/owner'),
                outline: true,
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
      ),
    );
  }
}
