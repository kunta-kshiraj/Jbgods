import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase instances
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Auth state stream (null when signed out)
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// Current Firebase user (null while loading/if signed out)
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.when(
    data: (user) => user,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Firestore user document stream (users/{uid})
final userDocProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);

  if (user == null) {
    // Emit nothing instead of a single null event
    return const Stream<DocumentSnapshot<Map<String, dynamic>>?>.empty();
  }
  return firestore.collection('users').doc(user.uid).snapshots();
});

/// Role as a stream (null until the doc with 'role' exists)
final currentUserRoleProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);

  if (user == null) {
    return const Stream<String?>.empty();
  }

  return firestore
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['role'] as String?);
});

/// Role with fallback for widgets that just need a string
final userRoleProvider = Provider<String>((ref) {
  final roleAsync = ref.watch(currentUserRoleProvider);
  // Fallback order: loaded value -> 'first_time'
  return roleAsync.maybeWhen(
    data: (r) => r ?? 'first_time',
    orElse: () => 'first_time',
  );
});

/// Raw profile map (null while loading/missing)
final userProfileProvider = Provider<Map<String, dynamic>?>((ref) {
  final docAsync = ref.watch(userDocProvider);
  return docAsync.when(
    data: (doc) => doc?.data(),
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Is admin (admin or master)
final isAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == 'admin' || role == 'master';
});

/// Is member (anything except first_time)
final isMemberProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role != 'first_time';
});

/// Current user's pending request doc (requests/{uid})
final pendingRequestProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final user = ref.watch(currentUserProvider);
  final firestore = ref.watch(firestoreProvider);

  if (user == null) {
    return const Stream<DocumentSnapshot<Map<String, dynamic>>?>.empty();
  }
  return firestore.collection('requests').doc(user.uid).snapshots();
});
