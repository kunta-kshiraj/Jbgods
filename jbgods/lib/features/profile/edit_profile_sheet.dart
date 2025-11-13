import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
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
  late TextEditingController rinkNameCtrl;
  late TextEditingController address1Ctrl;
  late TextEditingController address2Ctrl;
  late TextEditingController cityCtrl;
  late TextEditingController stateCtrl;
  late TextEditingController ownerNameCtrl;
  final formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    // Initialize with empty values, will be populated from Firebase data
    usernameCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    rinkNameCtrl = TextEditingController();
    address1Ctrl = TextEditingController();
    address2Ctrl = TextEditingController();
    cityCtrl = TextEditingController();
    stateCtrl = TextEditingController();
    ownerNameCtrl = TextEditingController();
    
    // Load user profile data from Firebase
    _loadUserProfile();
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    emailCtrl.dispose();
    rinkNameCtrl.dispose();
    address1Ctrl.dispose();
    address2Ctrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    ownerNameCtrl.dispose();
    super.dispose();
  }

  String _buildFullAddress() {
    final parts = <String>[];
    if (address1Ctrl.text.trim().isNotEmpty) parts.add(address1Ctrl.text.trim());
    if (address2Ctrl.text.trim().isNotEmpty) parts.add(address2Ctrl.text.trim());
    if (cityCtrl.text.trim().isNotEmpty) parts.add(cityCtrl.text.trim());
    if (stateCtrl.text.trim().isNotEmpty) parts.add(stateCtrl.text.trim());
    return parts.join(', ');
  }

  Future<void> _loadUserProfile() async {
    final userProfile = ref.read(userProfileProvider);
    final userRole = ref.read(userRoleProvider);
    if (mounted && userProfile != null) {
      setState(() {
        usernameCtrl.text = userProfile['username'] ?? '';
        emailCtrl.text = userProfile['email'] ?? '';
        rinkNameCtrl.text = userProfile['rinkName'] ?? '';
        // Load individual address fields if available, otherwise parse from full address
        address1Ctrl.text = userProfile['address1'] ?? '';
        address2Ctrl.text = userProfile['address2'] ?? '';
        cityCtrl.text = userProfile['city'] ?? '';
        stateCtrl.text = userProfile['state'] ?? '';
        // If individual fields are empty but full address exists, try to parse it
        if (address1Ctrl.text.isEmpty && cityCtrl.text.isEmpty && stateCtrl.text.isEmpty) {
          final fullAddress = userProfile['address'] ?? '';
          if (fullAddress.isNotEmpty) {
            // Simple parsing: assume format is "address1, address2, city, state"
            final parts = fullAddress.split(',').map((e) => e.trim()).toList();
            if (parts.length >= 1) address1Ctrl.text = parts[0];
            if (parts.length >= 2) address2Ctrl.text = parts[1];
            if (parts.length >= 3) cityCtrl.text = parts[2];
            if (parts.length >= 4) stateCtrl.text = parts[3];
          }
        }
        ownerNameCtrl.text = userProfile['ownerName'] ?? '';
        _isOwner = userRole == 'owner' || userRole == 'first_time_owner';
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

      // Build update map
      final updateData = <String, dynamic>{
        'username': usernameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // For owners: geocode address once and reuse coordinates for all collections
      double? newLatitude;
      double? newLongitude;
      
      if (_isOwner) {
        // Build full address from components
        final fullAddress = _buildFullAddress();
        
        updateData['rinkName'] = rinkNameCtrl.text.trim();
        updateData['address'] = fullAddress;
        updateData['address1'] = address1Ctrl.text.trim();
        updateData['address2'] = address2Ctrl.text.trim();
        updateData['city'] = cityCtrl.text.trim();
        updateData['state'] = stateCtrl.text.trim();
        updateData['ownerName'] = ownerNameCtrl.text.trim();
        
        // Check if address changed and geocode if needed
        final userProfile = ref.read(userProfileProvider);
        final oldAddress = userProfile?['address'] ?? '';
        
        if (fullAddress != oldAddress && fullAddress.isNotEmpty) {
          debugPrint('Address changed from "$oldAddress" to "$fullAddress" - geocoding...');
          try {
            final locations = await locationFromAddress(fullAddress);
            if (locations.isNotEmpty) {
              newLatitude = locations.first.latitude;
              newLongitude = locations.first.longitude;
              updateData['latitude'] = newLatitude;
              updateData['longitude'] = newLongitude;
              debugPrint('Geocoding successful: lat=$newLatitude, lng=$newLongitude');
            } else {
              debugPrint('Geocoding returned empty results');
              // Keep existing coordinates if geocoding fails
              newLatitude = userProfile?['latitude'];
              newLongitude = userProfile?['longitude'];
              if (newLatitude != null) updateData['latitude'] = newLatitude;
              if (newLongitude != null) updateData['longitude'] = newLongitude;
            }
          } catch (e) {
            debugPrint('Failed to geocode address: $e');
            // Keep existing coordinates if geocoding fails
            newLatitude = userProfile?['latitude'];
            newLongitude = userProfile?['longitude'];
            if (newLatitude != null) updateData['latitude'] = newLatitude;
            if (newLongitude != null) updateData['longitude'] = newLongitude;
          }
        } else {
          // Keep existing coordinates if address didn't change
          newLatitude = userProfile?['latitude'];
          newLongitude = userProfile?['longitude'];
          if (newLatitude != null) updateData['latitude'] = newLatitude;
          if (newLongitude != null) updateData['longitude'] = newLongitude;
          debugPrint('Address unchanged, keeping existing coordinates');
        }
      }

      // Update the user document in Firestore
      await firestore.collection('users').doc(user.uid).update(updateData);

      // If owner, also update owner_requests and rinks collections if they exist
      if (_isOwner) {
        final ownerRequestDoc = await firestore.collection('owner_requests').doc(user.uid).get();
        if (ownerRequestDoc.exists) {
          final fullAddress = _buildFullAddress();
          final updateOwnerRequestData = <String, dynamic>{
            'rinkName': rinkNameCtrl.text.trim(),
            'address': fullAddress,
            'address1': address1Ctrl.text.trim(),
            'address2': address2Ctrl.text.trim(),
            'city': cityCtrl.text.trim(),
            'state': stateCtrl.text.trim(),
            'ownerName': ownerNameCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
          };
          
          // Add coordinates if we have them
          if (newLatitude != null) updateOwnerRequestData['latitude'] = newLatitude;
          if (newLongitude != null) updateOwnerRequestData['longitude'] = newLongitude;
          
          await firestore.collection('owner_requests').doc(user.uid).update(updateOwnerRequestData);
        }

        final rinkDoc = await firestore.collection('rinks').doc(user.uid).get();
        if (rinkDoc.exists) {
          final rinkFullAddress = _buildFullAddress();
          final rinkUpdateData = <String, dynamic>{
            'rinkName': rinkNameCtrl.text.trim(),
            'address': rinkFullAddress,
            'address1': address1Ctrl.text.trim(),
            'address2': address2Ctrl.text.trim(),
            'city': cityCtrl.text.trim(),
            'state': stateCtrl.text.trim(),
            'ownerName': ownerNameCtrl.text.trim(),
            'email': emailCtrl.text.trim(),
          };
          
          // Always update coordinates - use new ones if available, otherwise keep existing
          if (newLatitude != null && newLongitude != null) {
            rinkUpdateData['latitude'] = newLatitude;
            rinkUpdateData['longitude'] = newLongitude;
            debugPrint('Updating rinks with NEW coordinates: lat=$newLatitude, lng=$newLongitude');
          } else {
            // If geocoding failed, use existing coordinates from rinkDoc
            final existingLat = rinkDoc.data()?['latitude'];
            final existingLng = rinkDoc.data()?['longitude'];
            if (existingLat != null) rinkUpdateData['latitude'] = existingLat;
            if (existingLng != null) rinkUpdateData['longitude'] = existingLng;
            debugPrint('Using existing coordinates: lat=$existingLat, lng=$existingLng');
          }
          
          debugPrint('Updating rinks collection for ${user.uid} with: $rinkUpdateData');
          await firestore.collection('rinks').doc(user.uid).update(rinkUpdateData);
          debugPrint('✅ Rinks collection updated successfully');
          
          // Verify the update
          final verifyDoc = await firestore.collection('rinks').doc(user.uid).get();
          final verifyData = verifyDoc.data();
          debugPrint('✅ Verified rinks update - lat=${verifyData?['latitude']}, lng=${verifyData?['longitude']}, address=${verifyData?['address']}');
        } else {
          debugPrint('⚠️ Rink document does not exist for user ${user.uid}');
        }
      }

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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
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
              // Owner-specific fields
              if (_isOwner) ...[
                const SizedBox(height: 16),
                JBInput(
                  controller: rinkNameCtrl,
                  label: "Rink Name",
                  validator: (v) => v == null || v.isEmpty ? "Enter rink name" : null,
                ),
                const SizedBox(height: 16),
                JBInput(
                  controller: address1Ctrl,
                  label: "Address 1",
                  validator: (v) => v == null || v.isEmpty ? "Enter address line 1" : null,
                ),
                const SizedBox(height: 16),
                JBInput(
                  controller: address2Ctrl,
                  label: "Address 2 (Optional)",
                ),
                const SizedBox(height: 16),
                JBInput(
                  controller: cityCtrl,
                  label: "City",
                  validator: (v) => v == null || v.isEmpty ? "Enter city" : null,
                ),
                const SizedBox(height: 16),
                JBInput(
                  controller: stateCtrl,
                  label: "State",
                  validator: (v) => v == null || v.isEmpty ? "Enter state" : null,
                ),
                const SizedBox(height: 16),
                JBInput(
                  controller: ownerNameCtrl,
                  label: "Owner Name",
                  validator: (v) => v == null || v.isEmpty ? "Enter owner name" : null,
                ),
              ],
              const SizedBox(height: 24),
              JBButton(
                label: _isLoading ? "Saving..." : "Save Changes",
                onPressed: _isLoading ? null : _saveProfile,
              ),
                      const SizedBox(height: 24), // Extra padding at bottom
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


