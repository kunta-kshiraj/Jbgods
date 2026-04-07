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

    final red = theme.colorScheme.primary;
    final cardBg = isDark ? theme.colorScheme.surface : Colors.red.shade50;
    final cardBorder = red.withValues(alpha: isDark ? 0.5 : 0.3);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checked in users'),
        backgroundColor: red,
        foregroundColor: Colors.white,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Unable to load events', style: TextStyle(color: textColor)),
                  ],
                ),
              ),
            );
          }
          if (!eventsSnap.hasData) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }
          final eventDocs = eventsSnap.data!.docs;
          if (eventDocs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                    const SizedBox(height: 16),
                    Text(
                      'You have no events. Check-ins will appear here for events you create.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor.withValues(alpha: 0.8), fontSize: 15),
                    ),
                  ],
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
                accentColor: red,
                cardBg: cardBg,
                cardBorder: cardBorder,
              );
            },
          );
        },
      ),
    );
  }
}

class _EventCheckedInSection extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final Color textColor;
  final Color accentColor;
  final Color cardBg;
  final Color cardBorder;

  const _EventCheckedInSection({
    required this.eventId,
    required this.eventTitle,
    required this.textColor,
    required this.accentColor,
    required this.cardBg,
    required this.cardBorder,
  });

  @override
  State<_EventCheckedInSection> createState() => _EventCheckedInSectionState();
}

class _EventCheckedInSectionState extends State<_EventCheckedInSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final eventTitle = widget.eventTitle;
    final eventId = widget.eventId;
    final textColor = widget.textColor;
    final accentColor = widget.accentColor;
    final cardBg = widget.cardBg;
    final cardBorder = widget.cardBorder;

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
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cardBorder, width: 1.5)),
            elevation: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(eventTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        ),
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: accentColor, size: 28),
                      ],
                    ),
                  ),
                ),
                if (_expanded) ...[
                  Divider(height: 1, color: cardBorder),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Unable to load check-ins: $errStr', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                  ),
                ],
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cardBorder, width: 1.5)),
            elevation: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(eventTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                        ),
                        Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: accentColor, size: 28),
                      ],
                    ),
                  ),
                ),
                if (_expanded)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)),
                  ),
              ],
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
        final count = docs.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cardBorder, width: 1.5)),
          elevation: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          eventTitle,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '$count checked in',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accentColor),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: accentColor,
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded) ...[
                Divider(height: 1, color: cardBorder),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: docs.isEmpty
                      ? Text(
                          'No check-ins yet',
                          style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.7)),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: docs.map((doc) {
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
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          }).toList(),
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
