import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/header_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool routed = false;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!routed && mounted) {
        routed = true;
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HeaderLogo(),
            SizedBox(height: 32),
            Text(
              "Welcome to JB GODS",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
            ),
          ],
        ),
      ),
    );
  }
}