import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/auth_providers.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';

class EditRinkListingScreen extends ConsumerStatefulWidget {
  final String listingId;
  final String initialName;
  final String initialCity;
  final String initialState;
  final String initialCountry;
  final bool initialClaimed;

  const EditRinkListingScreen({
    super.key,
    required this.listingId,
    required this.initialName,
    required this.initialCity,
    required this.initialState,
    required this.initialCountry,
    this.initialClaimed = false,
  });

  @override
  ConsumerState<EditRinkListingScreen> createState() => _EditRinkListingScreenState();
}

class _EditRinkListingScreenState extends ConsumerState<EditRinkListingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _countryController;
  bool _submitting = false;
  late bool _claimed;

  @override
  void initState() {
    super.initState();
    _claimed = widget.initialClaimed;
    _nameController = TextEditingController(text: widget.initialName);
    _cityController = TextEditingController(text: widget.initialCity);
    _stateController = TextEditingController(text: widget.initialState);
    _countryController = TextEditingController(text: widget.initialCountry);
  }

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

    setState(() => _submitting = true);

    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('rink_listings').doc(widget.listingId).update({
        'name': name,
        'city': city,
        'state': state,
        'country': country,
        'claimed': _claimed,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skating rink updated'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
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

    if (!isMaster) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit skating rink'),
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
                'Update the skating rink details below.',
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
              const SizedBox(height: 16),
              SwitchListTile(
                value: _claimed,
                onChanged: (v) => setState(() => _claimed = v),
                title: Text(
                  'Claimed',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'When on, users see a "Claimed" badge on this rink.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              JBButton(
                label: _submitting ? 'Saving...' : 'Save changes',
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
