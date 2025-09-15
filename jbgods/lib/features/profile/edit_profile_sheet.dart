import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/jb_input.dart';
import '../../widgets/jb_button.dart';
import '../../data/auth_providers.dart';
import '../../utils/validation_utils.dart';

class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});
  
  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late TextEditingController usernameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController stateCtrl;
  late TextEditingController countryCtrl;
  final formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with empty values, will be populated from Firebase data
    usernameCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    stateCtrl = TextEditingController();
    countryCtrl = TextEditingController();
    
    // Load user profile data from Firebase
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final userProfile = ref.read(userProfileProvider);
    if (mounted && userProfile != null) {
      setState(() {
        usernameCtrl.text = userProfile['username'] ?? '';
        emailCtrl.text = userProfile['email'] ?? '';
        stateCtrl.text = userProfile['state'] ?? '';
        countryCtrl.text = userProfile['country'] ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      // Update the user document in Firestore
      await firestore.collection('users').doc(user.uid).update({
        'username': usernameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'country': countryCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh the user profile data
      ref.invalidate(userProfileProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
            Text(
              'Edit Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            JBInput(
              controller: usernameCtrl, 
              label: "Username",
              validator: ValidationUtils.validateUsername,
            ),
            const SizedBox(height: 16),
            JBInput(
              controller: emailCtrl,
              label: "Email",
              keyboardType: TextInputType.emailAddress,
              validator: ValidationUtils.validateEmail,
            ),
            const SizedBox(height: 16),
            JBInput(
              controller: stateCtrl, 
              label: "State",
            ),
            const SizedBox(height: 16),
            JBInput(
              controller: countryCtrl, 
              label: "Country",
            ),
            const SizedBox(height: 24),
            JBButton(
              label: _isLoading ? "Saving..." : "Save Changes",
              onPressed: _isLoading ? null : _saveProfile,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}


