import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_providers.dart';

/// Streams common Firestore queries used across the app

/// Messages query: newest first, limit 100
final messagesQueryProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(authStateChangesProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return firestore
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots();
    },
    loading: () => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
    error: (_, __) => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
  );
});

/// Events query: order by createdAt desc (no index required)
final eventsQueryProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(authStateChangesProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .snapshots();
    },
    loading: () => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
    error: (_, __) => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
  );
});



