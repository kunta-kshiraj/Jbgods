import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../../widgets/jb_input.dart';
import '../../data/auth_providers.dart';
import '../../services/iap_service.dart';
import '../../widgets/terms_conditions_dialog.dart';

class RinkOwnerPaymentScreen extends ConsumerStatefulWidget {
  const RinkOwnerPaymentScreen({super.key});

  @override
  ConsumerState<RinkOwnerPaymentScreen> createState() => _RinkOwnerPaymentScreenState();
}

class _RinkOwnerPaymentScreenState extends ConsumerState<RinkOwnerPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _agree = false;
  bool _showPayment = false;
  bool _isLoading = false;
  String? _productPrice;

  final IAPService _iapService = IAPService();

  @override
  void initState() {
    super.initState();
    // Pre-fill email and name from profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProfile = ref.read(userProfileProvider);
      final user = ref.read(currentUserProvider);
      
      if (userProfile != null) {
        _emailCtrl.text = userProfile['email'] ?? user?.email ?? '';
        _nameCtrl.text = userProfile['name'] ?? 
                        userProfile['ownerName'] ?? 
                        userProfile['username'] ?? '';
      } else if (user?.email != null) {
        _emailCtrl.text = user?.email ?? '';
      }

      // Load product price
      _loadProductPrice();
    });
  }

  Future<void> _loadProductPrice() async {
    if (Platform.isIOS && _iapService.isAvailable) {
      final product = _iapService.productDetails;
      if (product != null && mounted) {
        setState(() {
          _productPrice = product.price;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_iapService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('In-App Purchase is not available on this device. Please use an iOS device.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if product is loaded, reload if needed
    if (_iapService.productDetails == null) {
      setState(() => _isLoading = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading product information...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      // Try to reload product details
      await _iapService.reloadProductDetails();
      await Future.delayed(const Duration(seconds: 1));
      
      if (_iapService.productDetails == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product not found. Please ensure the product ID "com.jbgods.skatingrink_owners_monthly" is configured in App Store Connect and approved.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final success = await _iapService.buyProduct();
      
      if (!mounted) return;

      if (success) {
        // Purchase initiated - wait for purchase stream to handle completion
        // Show a message that purchase is processing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing purchase...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Wait longer for purchase to complete (IAP can take a few seconds)
        await Future.delayed(const Duration(seconds: 3));
        
        // Check if purchase was successful
        final hasActive = await _iapService.hasActiveSubscription();
        
        if (hasActive) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Purchase successful! You now have access to all rink owner features.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          // Purchase might still be processing or user cancelled
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase is being processed. Please wait or check your subscription status.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initiate purchase. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rink Owner Monthly Subscription'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_showPayment) ...[
                // Step 1: Enter email and name
                Text(
                  'Enter Your Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                JBInput(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  validator: (v) => v == null || v.trim().isEmpty 
                      ? 'Name is required' 
                      : null,
                ),
                const SizedBox(height: 16),
                JBInput(
                  controller: _emailCtrl,
                  label: 'Email Address',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Checkbox(
                      value: _agree,
                      onChanged: (val) => setState(() => _agree = val ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => TermsConditionsDialog(),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'I agree to the ',
                            style: TextStyle(color: textColor),
                            children: [
                              TextSpan(
                                text: 'terms and conditions',
                                style: TextStyle(
                                  color: Colors.red,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    if (!_agree) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please agree to the terms first')),
                      );
                      return;
                    }
                    setState(() => _showPayment = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Proceed to Payment'),
                ),
              ] else ...[
                // Step 2: Payment confirmation
                Text(
                  "Confirm Monthly Subscription Payment",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildDetailRow('Name', _nameCtrl.text.trim(), isDark),
                const SizedBox(height: 8),
                _buildDetailRow('Email', _emailCtrl.text.trim(), isDark),
                const SizedBox(height: 8),
                _buildDetailRow('Subscription Type', 'Monthly Membership', isDark),
                const SizedBox(height: 8),
                _buildDetailRow('Duration', '30 days', isDark),
                if (_productPrice != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Price', _productPrice!, isDark),
                ],
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _handlePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_productPrice != null 
                        ? 'Purchase for $_productPrice' 
                        : 'Purchase Subscription'),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : () => setState(() => _showPayment = false),
                  child: const Text('← Back to Edit Details'),
                ),
                if (!Platform.isIOS) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'In-App Purchase is only available on iOS devices.',
                            style: TextStyle(color: Colors.orange.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
