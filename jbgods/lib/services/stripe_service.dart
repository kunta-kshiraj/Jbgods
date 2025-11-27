import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import '../core/secret/stripe_keys.dart';

// Create a single instance provider for StripePaymentService
final stripePaymentServiceProvider = Provider<StripePaymentService>((ref) {
  return StripePaymentService();
});

class StripePaymentService {
  // HTTP instance for making API requests
  final http.Client _httpClient = http.Client();

  // Initialize payment sheet with Stripe using direct amount
  Future<void> initializePaymentSheet({
    required double amount,
    required String currency,
    required String merchantName,
    ThemeMode style = ThemeMode.light,
  }) async {
    try {
      // Validate publishable key
      if (Stripe.publishableKey == null || 
          Stripe.publishableKey == 'YOUR_PUBLISHABLE_KEY' ||
          Stripe.publishableKey!.isEmpty) {
        throw Exception(
          'Stripe Publishable Key not configured. Please add your Stripe keys in lib/core/secret/stripe_keys.dart and initialize Stripe in main.dart'
        );
      }

      // Create payment intent on server
      final paymentIntent = await _createPaymentIntent(
        amount: amount,
        currency: currency,
      );
      // Initialize Stripe payment sheet
      final clientSecret = paymentIntent['client_secret'] as String;
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantName,
          style: style,
        ),
      );
    } catch (e) {
      throw Exception('Failed to initialize payment sheet: $e');
    }
  }

  // Initialize payment sheet with Stripe using Price ID
  Future<void> initializePaymentSheetWithPriceId({
    required String priceId,
    required String merchantName,
    ThemeMode style = ThemeMode.light,
    String? customerEmail,
  }) async {
    try {
      // Create payment intent on server using price ID
      final paymentIntent = await _createPaymentIntentWithPriceId(
        priceId: priceId,
        customerEmail: customerEmail,
      );
      // Initialize Stripe payment sheet
      final clientSecret = paymentIntent['client_secret'] as String;
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantName,
          style: style,
        ),
      );
    } catch (e) {
      throw Exception('Failed to initialize payment sheet: $e');
    }
  }

  // Create payment intent with direct amount
  Future<Map<String, dynamic>> _createPaymentIntent({
    required double amount,
    required String currency,
  }) async {
    // Validate Stripe keys
    if (StripeKeys.secretKey == 'YOUR_SECRET_KEY' || 
        StripeKeys.secretKey.isEmpty) {
      throw Exception(
        'Stripe Secret Key not configured. Please add your Stripe keys in lib/core/secret/stripe_keys.dart'
      );
    }

    if (amount <= 0) {
      throw Exception('Invalid amount: Amount must be greater than 0');
    }

    // Prepare request body for Stripe API
    final amountInCents = (amount * 100).toInt();
    final body = {
      'amount': amountInCents.toString(),
      'currency': currency.toLowerCase(),
      'payment_method_types[]': 'card',
    };

    // Make POST request to Stripe payment intent endpoint
    final response = await _httpClient.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      body: body,
      headers: {
        'Authorization': 'Bearer ${StripeKeys.secretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      if (responseData['client_secret'] == null) {
        throw Exception('No client_secret in response');
      }
      return responseData;
    } else {
      // Parse error message for better user feedback
      try {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        final error = errorData['error'] as Map<String, dynamic>?;
        final errorMessage = error?['message'] as String? ?? response.body;
        throw Exception('Stripe API Error: $errorMessage');
      } catch (e) {
        throw Exception('Failed to create payment intent: ${response.statusCode} - ${response.body}');
      }
    }
  }

  // Create payment intent with Price ID
  Future<Map<String, dynamic>> _createPaymentIntentWithPriceId({
    required String priceId,
    String? customerEmail,
  }) async {
    // First, retrieve the price to get amount and currency
    final priceResponse = await _httpClient.get(
      Uri.parse('https://api.stripe.com/v1/prices/$priceId'),
      headers: {
        'Authorization': 'Bearer ${StripeKeys.secretKey}',
      },
    );

    if (priceResponse.statusCode != 200) {
      throw Exception('Failed to retrieve price: ${priceResponse.statusCode} - ${priceResponse.body}');
    }

    final priceData = json.decode(priceResponse.body) as Map<String, dynamic>;
    final amount = priceData['unit_amount'] as int;
    final currency = priceData['currency'] as String;

    // Now create payment intent with the price details and metadata
    final body = <String, String>{
      'amount': amount.toString(),
      'currency': currency,
      'payment_method_types[]': 'card',
    };

    // Add email to receipt_email so it appears in Stripe dashboard
    if (customerEmail != null && customerEmail.isNotEmpty) {
      body['receipt_email'] = customerEmail;
      // Also add to metadata for tracking
      body['metadata[user_email]'] = customerEmail;
    }

    final response = await _httpClient.post(
      Uri.parse('https://api.stripe.com/v1/payment_intents'),
      body: body,
      headers: {
        'Authorization': 'Bearer ${StripeKeys.secretKey}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      if (responseData['client_secret'] == null) {
        throw Exception('No client_secret in response');
      }
      return responseData;
    } else {
      throw Exception('Failed to create payment intent: ${response.statusCode} - ${response.body}');
    }
  }

  // Present payment sheet
  Future<void> presentPaymentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
    } catch (e) {
      throw Exception('Payment failed: $e');
    }
  }
}

