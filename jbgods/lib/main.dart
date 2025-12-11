import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'router.dart';
import 'app_state.dart';
import 'core/secret/stripe_keys.dart';
import 'services/iap_service.dart';

// Future<void> renameCollection() async {
//   final firestore = FirebaseFirestore.instance;
//   final oldCollection = firestore.collection('events');
//   final newCollection = firestore.collection('updates');

//   final snapshot = await oldCollection.get();
//   for (var doc in snapshot.docs) {
//     await newCollection.doc(doc.id).set(doc.data());
//   }
//   print('✅ Copied ${snapshot.docs.length} documents from events → updates');
// }


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print("✅ Connected to Firebase project: ${Firebase.app().options.projectId}");
  // await renameCollection();

  
  // Setup emulators if enabled
  const useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: false);
  if (useEmulator) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  
  // Initialize Stripe with publishable key
  Stripe.publishableKey = StripeKeys.publishableKey;
  
  // Warn if Stripe keys are not configured
  if (StripeKeys.publishableKey == 'YOUR_PUBLISHABLE_KEY' || 
      StripeKeys.secretKey == 'YOUR_SECRET_KEY') {
    print('⚠️ WARNING: Stripe keys not configured!');
    print('Please update lib/core/secret/stripe_keys.dart with your Stripe API keys.');
  }
  
  // Initialize IAP service
  await IAPService().initialize();
  
  await AppStateNotifier.ensurePrefsInitialized();
  runApp(const ProviderScope(child: JBGodsApp()));
}

class JBGodsApp extends ConsumerWidget {
  const JBGodsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appStateProvider.select((s) => s.themeMode));
    final router = ref.read(routerProvider);
    return MaterialApp.router(
      title: 'JB GODS',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}