import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Product ID for Rink Owner Monthly Subscription (NON-CONSUMABLE)
const String kRinkOwnerMonthlyProductId = 'com.jbgods.skatingrink_owners_monthly';

/// SharedPreferences key for storing purchase timestamp
const String kRinkOwnerPurchaseTimestampKey = 'rink_owner_purchase_timestamp';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _productDetails;
  bool _isAvailable = false;
  bool _purchasePending = false;

  /// Initialize IAP service and fetch product details
  Future<void> initialize() async {
    // Check platform first
    if (!Platform.isIOS) {
      debugPrint('⚠️ IAP is only available on iOS');
      _isAvailable = false;
      return;
    }

    _isAvailable = await _iap.isAvailable();
    
    if (!_isAvailable) {
      debugPrint('⚠️ IAP not available on this device');
      debugPrint('   Make sure you are testing on a real iOS device (not simulator)');
      debugPrint('   Or ensure StoreKit configuration is set up in Xcode for simulator testing');
      return;
    }

    debugPrint('✅ IAP is available');

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('❌ Purchase stream error: $error'),
    );

    // Fetch product details
    await _loadProductDetails();
  }

  /// Load product details from App Store
  Future<void> _loadProductDetails() async {
    if (!_isAvailable) {
      debugPrint('⚠️ IAP not available, cannot load product details');
      return;
    }

    final Set<String> productIds = {kRinkOwnerMonthlyProductId};
    debugPrint('🔄 Loading product details for: $kRinkOwnerMonthlyProductId');
    
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('❌ Error loading products: ${response.error}');
        debugPrint('   Error code: ${response.error?.code}');
        debugPrint('   Error message: ${response.error?.message}');
        debugPrint('   Error details: ${response.error?.details}');
        
        // Provide helpful guidance based on error
        if (response.error?.code == 'storekit_no_response') {
          debugPrint('');
          debugPrint('⚠️ TROUBLESHOOTING GUIDE:');
          debugPrint('   1. Make sure you are testing on a REAL iOS device (not simulator)');
          debugPrint('   2. Sign out of your Apple ID in Settings > App Store');
          debugPrint('   3. Sign in with a SANDBOX TEST ACCOUNT when prompted');
          debugPrint('   4. Or set up StoreKit Configuration file in Xcode for simulator testing');
          debugPrint('   5. Ensure product "$kRinkOwnerMonthlyProductId" exists in App Store Connect');
        }
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint('⚠️ No products found for ID: $kRinkOwnerMonthlyProductId');
        debugPrint('   Make sure the product exists in App Store Connect and is approved');
        debugPrint('   Product should be type: Non-Consumable');
        return;
      }

      _productDetails = response.productDetails.first;
      debugPrint('✅ Product loaded: ${_productDetails?.id} - ${_productDetails?.price}');
      debugPrint('   Product title: ${_productDetails?.title}');
      debugPrint('   Product description: ${_productDetails?.description}');
    } catch (e) {
      debugPrint('❌ Exception while loading products: $e');
    }
  }

  /// Reload product details (public method)
  Future<void> reloadProductDetails() async {
    await _loadProductDetails();
  }

  /// Get product details (price, etc.)
  ProductDetails? get productDetails => _productDetails;

  /// Check if IAP is available
  bool get isAvailable => _isAvailable && Platform.isIOS;

  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
        debugPrint('⏳ Purchase pending: ${purchaseDetails.productID}');
      } else {
        _purchasePending = false;
        
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          _handleSuccessfulPurchase(purchaseDetails);
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.productID != kRinkOwnerMonthlyProductId) {
      debugPrint('⚠️ Unknown product ID: ${purchaseDetails.productID}');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ No user logged in');
      return;
    }

    try {
      // Save purchase timestamp to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final purchaseTimestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(kRinkOwnerPurchaseTimestampKey, purchaseTimestamp);
      debugPrint('✅ Purchase timestamp saved: $purchaseTimestamp');

      // Save to Firestore for server-side tracking
      final firestore = FirebaseFirestore.instance;
      final expiresAtDate = DateTime.now().add(const Duration(days: 30));
      final expiresAtTimestamp = Timestamp.fromDate(expiresAtDate);

      await firestore.collection('rink_owner_subscriptions').doc(user.uid).set({
        'userId': user.uid,
        'productId': kRinkOwnerMonthlyProductId,
        'purchaseId': purchaseDetails.purchaseID,
        'status': 'active',
        'subscriptionType': 'monthly',
        'subscriptionSource': 'iap', // Mark as IAP purchase
        'subscribedAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAtTimestamp,
        'purchasedAt': Timestamp.fromMillisecondsSinceEpoch(purchaseTimestamp),
      }, SetOptions(merge: true));

      debugPrint('✅ Purchase saved to Firestore');

      // Send confirmation email (if user has email in profile)
      try {
        final userDoc = await firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final userEmail = userData?['email'] ?? user.email;
        final userName = userData?['name'] ?? 
                        userData?['ownerName'] ?? 
                        userData?['username'] ?? 
                        'Rink Owner';

        if (userEmail != null && userEmail.isNotEmpty) {
          final functions = FirebaseFunctions.instance;
          await functions.httpsCallable('sendRinkOwnerSubscriptionEmail').call({
            'subscriptionId': user.uid,
            'email': userEmail,
            'fullName': userName,
            'subscriptionType': 'monthly',
            'expiresAt': expiresAtDate.toIso8601String(),
          });
          debugPrint('✅ Confirmation email sent to: $userEmail');
        }
      } catch (emailError) {
        debugPrint('❌ Failed to send email: $emailError');
      }
    } catch (e) {
      debugPrint('❌ Error handling purchase: $e');
    }
  }

  /// Initiate purchase
  Future<bool> buyProduct() async {
    // Check IAP availability
    if (!_isAvailable) {
      debugPrint('❌ IAP not available on this device');
      throw Exception('In-App Purchase is not available on this device. Please use an iOS device.');
    }

    // Check if product details are loaded
    if (_productDetails == null) {
      debugPrint('⚠️ Product details not loaded, attempting to reload...');
      await _loadProductDetails();
      
      if (_productDetails == null) {
        debugPrint('❌ Product details still not available after reload');
        throw Exception('Product not found. Please ensure the product ID "$kRinkOwnerMonthlyProductId" exists in App Store Connect.');
      }
    }

    if (_purchasePending) {
      debugPrint('⚠️ Purchase already in progress');
      throw Exception('A purchase is already in progress. Please wait for it to complete.');
    }

    try {
      debugPrint('🔄 Initiating purchase for product: ${_productDetails!.id}');
      
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: _productDetails!,
      );

      final bool success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (success) {
        debugPrint('✅ Purchase initiated successfully');
      } else {
        debugPrint('❌ buyNonConsumable returned false');
        throw Exception('Failed to initiate purchase. The purchase request was rejected.');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Error initiating purchase: $e');
      rethrow;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      debugPrint('⚠️ IAP not available');
      return;
    }

    try {
      await _iap.restorePurchases();
      debugPrint('✅ Restore purchases initiated');
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
    }
  }

  /// Check if user has active subscription (from SharedPreferences)
  Future<bool> hasActiveSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(kRinkOwnerPurchaseTimestampKey);
      
      if (timestamp == null) {
        return false;
      }

      final purchaseDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final expirationDate = purchaseDate.add(const Duration(days: 30));
      final now = DateTime.now();

      final isActive = expirationDate.isAfter(now);
      
      if (!isActive) {
        // Subscription expired, clear the timestamp
        await prefs.remove(kRinkOwnerPurchaseTimestampKey);
        debugPrint('⚠️ Subscription expired. Clearing timestamp.');
      }

      return isActive;
    } catch (e) {
      debugPrint('❌ Error checking subscription: $e');
      return false;
    }
  }

  /// Get subscription expiration date
  Future<DateTime?> getExpirationDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(kRinkOwnerPurchaseTimestampKey);
      
      if (timestamp == null) {
        return null;
      }

      final purchaseDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return purchaseDate.add(const Duration(days: 30));
    } catch (e) {
      debugPrint('❌ Error getting expiration date: $e');
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

