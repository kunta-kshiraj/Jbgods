import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/auth_providers.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';

class AddRinkListingScreen extends ConsumerStatefulWidget {
  const AddRinkListingScreen({super.key});

  @override
  ConsumerState<AddRinkListingScreen> createState() => _AddRinkListingScreenState();
}

class _AddRinkListingScreenState extends ConsumerState<AddRinkListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final state = _stateController.text.trim();
    final country = _countryController.text.trim();
    if (name.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRole = ref.read(userRoleProvider);
    final isMaster = userRole == 'master';
    final status = isMaster ? 'approved' : 'pending';

    setState(() => _submitting = true);

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('rink_listings').add({
        'name': name,
        'city': city,
        'state': state,
        'country': country,
        'addedBy': user.uid,
        'addedByRole': isMaster ? 'master' : 'admin',
        'status': status,
        'likeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      if (isMaster) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skating rink added to the list'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submitted for master approval. It will appear in the list once approved.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      // Pop Add screen so master is back on the list (new rink will show in list)
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userRole = ref.watch(userRoleProvider);
    final isMaster = userRole == 'master';
    final isAdminOrMaster = userRole == 'admin' || userRole == 'master';

    if (!isAdminOrMaster) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/shell/rinks');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add skating rink'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the skating rink details. ${isMaster ? "It will appear in the list immediately." : "A master must approve it before it appears in the list."}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              JBInput(
                controller: _nameController,
                label: 'Name of skating rink',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              JBInput(
                controller: _cityController,
                label: 'City',
              ),
              const SizedBox(height: 16),
              JBInput(
                controller: _stateController,
                label: 'State',
              ),
              const SizedBox(height: 16),
              JBInput(
                controller: _countryController,
                label: 'Country',
              ),
              const SizedBox(height: 32),
              JBButton(
                label: _submitting ? 'Submitting...' : 'Submit',
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
