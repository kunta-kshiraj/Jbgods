import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/toast.dart';
import '../../app_state.dart';
import '../../utils/date_utils.dart';
import 'burger_menu.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appStateProvider.select((s) => s.profile));
    final adminReq = ref.watch(appStateProvider.select((s) => s.adminRequest));
    final theme = Theme.of(context);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                const HeaderLogo(),
                Positioned(
                  top: 35,
                  right: 0,
                  child: const BurgerMenuButton(),
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 4),
              ),
              padding: EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: theme.scaffoldBackgroundColor,
                backgroundImage: NetworkImage(profile.avatarUrl),
                child: profile.avatarUrl.isEmpty
                    ? Text("JB GODS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
            SizedBox(height: 20),
            Text("Username: ${profile.username}", style: theme.textTheme.bodyMedium?.copyWith(fontSize: 18)),
            SizedBox(height: 6),
            Text("Age: ${ageFromDob(profile.dob)}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 6),
            Text("Mail ID: ${profile.email}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 6),
            Text("Address: ${profile.address}", style: theme.textTheme.bodyMedium),
            SizedBox(height: 24),
            JBButton(
              label: adminReq == AdminRequest.pending
                  ? "Request Pending"
                  : "Request to Become Admin",
              onPressed: adminReq == AdminRequest.pending
                  ? () {}
                  : () {
                      ref.read(appStateProvider.notifier).requestAdmin();
                      showJBToast(context, "Request sent");
                    },
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}