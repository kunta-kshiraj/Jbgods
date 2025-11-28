import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/stripe_service.dart';
import '../../data/auth_providers.dart';

class EnrollScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EnrollScreen({super.key, required this.event});

  @override
  ConsumerState<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends ConsumerState<EnrollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _agree = false;
  bool _showPayment = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  double get _eventCost {
    final cost = widget.event['cost'];
    if (cost == null) return 0.0;
    if (cost is double) return cost;
    if (cost is int) return cost.toDouble();
    if (cost is String) return double.tryParse(cost) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cost = _eventCost;

    return Scaffold(
      appBar: AppBar(
        title: Text(event['title'] ?? 'Event Registration'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Register for ${event['title'] ?? 'the event'}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),

                if (!_showPayment) ...[
                  // Name and Email Form
                  TextFormField(
                    controller: _nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Email ID',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.grey,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Checkbox(
                        value: _agree,
                        onChanged: (v) => setState(() => _agree = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'I agree to the Terms & Conditions',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          overflow: TextOverflow.clip,
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
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Continue'),
                  ),
                ] else ...[
                  // Payment Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registration Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Name', _nameCtrl.text.trim(), isDark),
                        const SizedBox(height: 8),
                        _buildDetailRow('Email', _emailCtrl.text.trim(), isDark),
                        const SizedBox(height: 16),
                        Divider(color: isDark ? Colors.white24 : Colors.grey[300]),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              '\$${cost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (cost <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid event cost'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      try {
                        final stripeService = ref.read(stripePaymentServiceProvider);
                        final themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

                        // Initialize payment sheet with event cost
                        await stripeService.initializePaymentSheet(
                          amount: cost,
                          currency: 'USD',
                          merchantName: 'JB Gods',
                          style: themeMode,
                        );

                        // Dismiss loading indicator
                        if (mounted) Navigator.pop(context);

                        // Present payment sheet
                        await stripeService.presentPaymentSheet();

                        // Payment successful - register user for event
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please log in to continue'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }

                        // Check if already registered
                        final firestore = FirebaseFirestore.instance;
                        final existing = await firestore
                            .collection('registrations')
                            .where('eventId', isEqualTo: widget.event['id'])
                            .where('userId', isEqualTo: user.uid)
                            .limit(1)
                            .get();

                        if (existing.docs.isNotEmpty) {
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Already Registered'),
                                content: const Text(
                                    'You have already registered for this event.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return;
                        }

                        // Register user
                        final registrationData = {
                          'eventId': widget.event['id'],
                          'eventTitle': widget.event['title'],
                          'userId': user.uid,
                          'fullName': _nameCtrl.text.trim(),
                          'email': _emailCtrl.text.trim(),
                          'agreedToTerms': _agree,
                          'amountPaid': cost,
                          'paymentStatus': 'completed',
                          'emailSent': false, // Track if email was sent
                          'createdAt': FieldValue.serverTimestamp(),
                        };
                        
                        final registrationRef = await firestore.collection('registrations').add(registrationData);

                        // Trigger email sending via Cloud Function
                        try {
                          final functions = ref.read(firebaseFunctionsProvider);
                          // Format date properly for Cloud Function
                          String? eventDateStr;
                          final eventDate = widget.event['date'];
                          if (eventDate != null) {
                            if (eventDate is Timestamp) {
                              // Convert Firestore Timestamp to ISO string
                              eventDateStr = eventDate.toDate().toIso8601String();
                            } else if (eventDate is DateTime) {
                              eventDateStr = eventDate.toIso8601String();
                            } else {
                              eventDateStr = eventDate.toString();
                            }
                          }
                          
                          await functions.httpsCallable('sendEventRegistrationEmail').call({
                            'registrationId': registrationRef.id,
                            'email': _emailCtrl.text.trim(),
                            'fullName': _nameCtrl.text.trim(),
                            'eventTitle': widget.event['title'],
                            'eventDate': eventDateStr,
                            'eventLocation': widget.event['location'],
                            'amountPaid': cost,
                          });
                        } catch (emailError) {
                          // Log error but don't fail the registration
                          debugPrint('Failed to send email: $emailError');
                          // Update registration to indicate email failed
                          await registrationRef.update({'emailSent': false, 'emailError': emailError.toString()});
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Payment successful! You are now enrolled. Confirmation email sent.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context, true); // Return true to indicate successful enrollment
                        }
                      } catch (e) {
                        // Dismiss loading indicator if still showing
                        if (mounted) Navigator.pop(context);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment failed: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: Text('Click to Pay \$${cost.toStringAsFixed(2)}'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _showPayment = false),
                    child: Text(
                      '← Back to Edit Details',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
          width: 80,
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
