import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/jb_input.dart';
import '../../widgets/jb_button.dart';
import '../../app_state.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});
  
  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late TextEditingController usernameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController addressCtrl;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(appStateProvider).profile;
    usernameCtrl = TextEditingController(text: profile.username);
    emailCtrl = TextEditingController(text: profile.email);
    addressCtrl = TextEditingController(text: profile.address);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JBInput(controller: usernameCtrl, label: "Username"),
            SizedBox(height: 12),
            JBInput(
              controller: emailCtrl,
              label: "Email",
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v != null && v.contains('@') ? null : "Invalid email",
            ),
            SizedBox(height: 12),
            JBInput(controller: addressCtrl, label: "Address"),
            SizedBox(height: 20),
            JBButton(
              label: "Save",
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                ref.read(appStateProvider.notifier).updateProfile(
                  Profile(
                    username: usernameCtrl.text,
                    email: emailCtrl.text,
                    address: addressCtrl.text,
                    dob: ref.read(appStateProvider).profile.dob,
                    avatarUrl: ref.read(appStateProvider).profile.avatarUrl,
                  ),
                );
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

