import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../data/auth_providers.dart';

class CheckedInUsersScreen extends ConsumerWidget {
  const CheckedInUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checked in users')),
        body: const Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checked in users'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('createdBy', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, eventsSnap) {
          if (eventsSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to load events', style: TextStyle(color: textColor)),
              ),
            );
          }
          if (!eventsSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final eventDocs = eventsSnap.data!.docs;
          if (eventDocs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You have no events. Check-ins will appear here for events you create.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor.withValues(alpha: 0.8)),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: eventDocs.length,
            itemBuilder: (context, index) {
              final eventDoc = eventDocs[index];
              final eventId = eventDoc.id;
              final eventData = eventDoc.data() as Map<String, dynamic>;
              final eventTitle = (eventData['title'] as String?) ?? 'Event';
              return _EventCheckedInSection(
                eventId: eventId,
                eventTitle: eventTitle,
                textColor: textColor,
              );
            },
          );
        },
      ),
    );
  }
}

class _EventCheckedInSection extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  final Color textColor;

  const _EventCheckedInSection({
    required this.eventId,
    required this.eventTitle,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('event_registrations')
          .where('eventId', isEqualTo: eventId)
          .where('checkedIn', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          final err = snap.error;
          final errStr = err is Exception ? err.toString().replaceFirst('Exception: ', '') : err.toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eventTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  const SizedBox(height: 8),
                  Text('Unable to load check-ins: $errStr', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eventTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  const SizedBox(height: 8),
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          );
        }
        var docs = snap.data!.docs;
        docs = List.from(docs)
          ..sort((a, b) {
            final atA = (a.data() as Map<String, dynamic>)['checkedInAt'] as Timestamp?;
            final atB = (b.data() as Map<String, dynamic>)['checkedInAt'] as Timestamp?;
            if (atA == null && atB == null) return 0;
            if (atA == null) return 1;
            if (atB == null) return -1;
            return atB.toDate().compareTo(atA.toDate());
          });
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  Text(
                    'No check-ins yet',
                    style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
                  )
                else
                  ...docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name = (d['userName'] as String?)?.trim().isNotEmpty == true
                        ? (d['userName'] as String).trim()
                        : (d['fullName'] as String?)?.trim().isNotEmpty == true
                            ? (d['fullName'] as String).trim()
                            : (d['userEmail'] as String?)?.trim().isNotEmpty == true
                                ? (d['userEmail'] as String).trim()
                                : 'Attendee';
                    final email = (d['userEmail'] as String?)?.trim() ?? '';
                    final at = d['checkedInAt'] as Timestamp?;
                    final timeStr = at != null
                        ? DateFormat('MMM d, h:mm a').format(at.toDate().toLocal())
                        : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                                if (email.isNotEmpty)
                                  Text(email, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8))),
                                if (timeStr.isNotEmpty)
                                  Text(timeStr, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
