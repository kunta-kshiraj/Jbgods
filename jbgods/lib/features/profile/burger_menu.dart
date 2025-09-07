import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_state.dart';
import 'edit_profile_sheet.dart';

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
            onTap: () {
              ref.read(appStateProvider.notifier).logOut();
              Navigator.pop(context);
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
            },
          ),
        ],
      ),
    );
  }
}