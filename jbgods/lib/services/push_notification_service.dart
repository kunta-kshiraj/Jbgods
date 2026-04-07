import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Handles FCM token and push notification tap navigation.
/// Call [init] from main() after Firebase. Call [setRouter] from router provider.
class PushNotificationService {
  PushNotificationService._();

  static GoRouter? _router;
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Set by router provider when GoRouter is created so we can navigate on notification tap.
  static void setRouter(GoRouter router) {
    _router = router;
  }

  /// Call from main() after Firebase.initializeApp().
  /// Requests permission, gets token, saves to Firestore; sets up foreground and tap handlers.
  static Future<void> init() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      ).timeout(const Duration(seconds: 10));
      if (kDebugMode) {
        print('FCM permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) print('FCM permission error: $e');
    }

    // Token will be saved when user is logged in (see saveTokenForCurrentUser)
    _messaging.getToken().then((token) {
      if (token != null && FirebaseAuth.instance.currentUser != null) {
        _saveTokenToFirestore(FirebaseAuth.instance.currentUser!.uid, token);
      }
    });

    _messaging.onTokenRefresh.listen((token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _saveTokenToFirestore(user.uid, token);
    });

    // Foreground: show no system notification; app can show in-app UI if needed
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('FCM onMessage: ${message.notification?.title}');
      }
    });

    // User tapped notification (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // App opened from terminated state via notification (don't await so we don't block startup)
    Future.microtask(() async {
      try {
        final initial = await _messaging.getInitialMessage();
        if (initial != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _handleNotificationTap(initial.data);
          });
        }
      } catch (_) {}
    });
  }

  static void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null || type.isEmpty) return;
    final router = _router;
    if (router == null) return;

    switch (type) {
      case 'event':
        final eventId = data['eventId'] as String?;
        if (eventId != null && eventId.isNotEmpty) {
          router.go('/shell/events');
        }
        break;
      case 'update':
        router.go('/shell/home');
        break;
      case 'chat':
      case 'announcement':
        router.go('/shell/chat');
        break;
      default:
        router.go('/shell/home');
    }
  }

  static Future<void> _saveTokenToFirestore(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcmToken': token, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) print('Failed to save FCM token: $e');
    }
  }

  /// Call when user signs in so token is saved/refreshed for current user.
  static Future<void> saveTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token != null) await _saveTokenToFirestore(user.uid, token);
  }

  /// Call when user signs out - optional: clear token from server to stop sending to this device.
  static Future<void> clearTokenOnSignOut(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
    } catch (_) {}
  }
}
