import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EnrollScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const EnrollScreen({super.key, required this.event});

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _agree = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      appBar: AppBar(
        title: Text(event['title'] ?? 'Event Registration'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Register for ${event['title'] ?? 'the event'}",
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email ID',
                  border: OutlineInputBorder(),
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
                  const Expanded(
                    child: Text(
                      'I agree to the Terms & Conditions',
                      overflow: TextOverflow.clip,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    if (!_agree) {
                        ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please agree to the terms first')),
                        );
                        return;
                    }

                    try {
                        final firestore = FirebaseFirestore.instance;
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;

                        // 🔍 Check if the user already registered for this event
                        final existing = await firestore
                            .collection('registrations')
                            .where('eventId', isEqualTo: widget.event['id'])
                            .where('userId', isEqualTo: user.uid)
                            .limit(1)
                            .get();

                        if (existing.docs.isNotEmpty) {
                        // ⚠️ Already registered — show popup
                        if (context.mounted) {
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

                        // ✅ Register if not already enrolled
                        await firestore.collection('registrations').add({
                        'eventId': widget.event['id'],
                        'eventTitle': widget.event['title'],
                        'userId': user.uid,
                        'fullName': _nameCtrl.text.trim(),
                        'email': _emailCtrl.text.trim(),
                        'agreedToTerms': _agree,
                        'createdAt': FieldValue.serverTimestamp(),
                        });

                        if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Registered successfully!')),
                        );
                        Navigator.pop(context);
                        }
                    } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ Failed to register: $e')),
                        );
                    }
                    },

                // onPressed: () async {
                //     if (!_formKey.currentState!.validate()) return;
                //     if (!_agree) {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //         const SnackBar(content: Text('Please agree to the terms first')),
                //     );
                //     return;
                //     }

                //     try {
                //     final firestore = FirebaseFirestore.instance;
                //     final user = FirebaseAuth.instance.currentUser;

                //     await firestore.collection('registrations').add({
                //         'eventId': widget.event['id'],
                //         'eventTitle': widget.event['title'],
                //         'userId': user?.uid,
                //         'fullName': _nameCtrl.text.trim(),
                //         'email': _emailCtrl.text.trim(),
                //         'agreedToTerms': _agree,
                //         'createdAt': FieldValue.serverTimestamp(),
                //     });

                //     if (context.mounted) {
                //         ScaffoldMessenger.of(context).showSnackBar(
                //         const SnackBar(content: Text('✅ Registered successfully!')),
                //         );
                //         Navigator.pop(context);
                //     }
                //     } catch (e) {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //         SnackBar(content: Text('❌ Failed to register: $e')),
                //     );
                //     }
                // },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Proceed to Payment'),
                ),

            ],
          ),
        ),
      ),
    );
  }
}
