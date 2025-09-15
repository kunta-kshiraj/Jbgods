import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../app_state.dart';
import '../../data/auth_providers.dart';
import 'edit_profile_sheet.dart';
import 'package:go_router/go_router.dart';

class BurgerMenuButton extends ConsumerWidget {
  const BurgerMenuButton({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(Icons.menu, size: 32),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => const BurgerMenuSheet(),
        );
      },
    );
  }
}

class BurgerMenuSheet extends ConsumerWidget {
  const BurgerMenuSheet({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit),
            title: Text("Edit Profile"),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => const EditProfileSheet(),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.brightness_6),
            title: Text("Theme"),
            onTap: () {
              ref.read(appStateProvider.notifier).toggleTheme();
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text("Logout"),
            onTap: () async {
              try {
                await ref.read(firebaseAuthProvider).signOut();
                ref.read(appStateProvider.notifier).logOut();
                Navigator.pop(context);
                context.go('/login');
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to logout. Please try again.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}