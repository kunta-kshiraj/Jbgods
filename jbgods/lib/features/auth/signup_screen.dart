import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
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
                      label: "Sign Up",
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        ref.read(appStateProvider.notifier).signUp(Profile(
                          username: usernameCtrl.text,
                          email: emailCtrl.text,
                          dob: dobCtrl.text,
                          address: addressCtrl.text,
                          avatarUrl: logoUrl,
                        ));
                        context.go('/shell/home');
                      },
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