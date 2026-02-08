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
          .collection('updates')
          .orderBy('createdAt', descending: true)
          .snapshots();
    },
    loading: () => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
    error: (_, __) => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
  );
});



/// Notifications for the current user (newest first)
final notificationsQueryProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(authStateChangesProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots();
    },
    loading: () => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
    error: (_, __) => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
  );
});

/// Unread notifications count
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final snap = ref.watch(notificationsQueryProvider);
  return snap.when(
    data: (query) => query.docs.where((d) => d.data()['read'] != true).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Calendar events (for Events tab badge)
final calendarEventsQueryProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(authStateChangesProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      }
      return firestore.collection('events').snapshots();
    },
    loading: () => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
    error: (_, __) => const Stream<QuerySnapshot<Map<String, dynamic>>>.empty(),
  );
});

/// Chat unread count: messages with createdAt > user's chatLastReadAt
final chatUnreadCountProvider = Provider<int>((ref) {
  final messagesAsync = ref.watch(messagesQueryProvider);
  final userDocAsync = ref.watch(userDocProvider);
  return messagesAsync.when(
    data: (messagesSnap) {
      return userDocAsync.when(
        data: (userDoc) {
          final lastRead = userDoc?.data()?['chatLastReadAt'] as Timestamp?;
          if (lastRead == null) return messagesSnap.docs.length;
          final cutoff = lastRead.millisecondsSinceEpoch;
          return messagesSnap.docs.where((d) {
            final t = d.data()['createdAt'] as Timestamp?;
            return t != null && t.millisecondsSinceEpoch > cutoff;
          }).length;
        },
        loading: () => 0,
        error: (_, __) => 0,
      );
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Events unviewed count: events whose id is not in user's viewedEventIds
final eventsUnviewedCountProvider = Provider<int>((ref) {
  final eventsAsync = ref.watch(calendarEventsQueryProvider);
  final userDocAsync = ref.watch(userDocProvider);
  return eventsAsync.when(
    data: (eventsSnap) {
      return userDocAsync.when(
        data: (userDoc) {
          final viewed = List<String>.from(
            (userDoc?.data()?['viewedEventIds'] as List<dynamic>?)?.map((e) => e.toString()) ?? [],
          );
          final viewedSet = viewed.toSet();
          return eventsSnap.docs.where((d) => !viewedSet.contains(d.id)).length;
        },
        loading: () => 0,
        error: (_, __) => 0,
      );
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Set of userIds that the current user has blocked
final blockedUsersSetProvider = StreamProvider<Set<String>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(authStateChangesProvider);
  return auth.when(
    data: (user) {
      if (user == null) {
        return const Stream<Set<String>>.empty();
      }
      return firestore
          .collection('blockedUsers')
          .where('blockerId', isEqualTo: user.uid)
          .snapshots()
          .map((snap) {
        final blocked = <String>{};
        for (final d in snap.docs) {
          final data = d.data();
          final id = data['blockedUserId'] as String?;
          if (id != null && id.isNotEmpty) blocked.add(id);
        }
        return blocked;
      });
    },
    loading: () => const Stream<Set<String>>.empty(),
    error: (_, __) => const Stream<Set<String>>.empty(),
  );
});

