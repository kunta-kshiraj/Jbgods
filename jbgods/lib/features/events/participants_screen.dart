import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventParticipantsScreen extends StatefulWidget {
  final String creatorId; // current user's UID
  const EventParticipantsScreen({super.key, required this.creatorId});

  @override
  State<EventParticipantsScreen> createState() =>
      _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends State<EventParticipantsScreen> {
  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Participants'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder(
        stream: firestore
            .collection('events')
            .where('createdBy', isEqualTo: widget.creatorId)
            .snapshots(),
        builder: (context, eventSnap) {
          if (eventSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!eventSnap.hasData || eventSnap.data!.docs.isEmpty) {
            return const Center(child: Text('No events created yet.'));
          }

          final events = eventSnap.data!.docs;

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, i) {
              final event = events[i];
              final eventData = event.data();

              return ExpansionTile(
                title: Text(eventData['title'] ?? 'Untitled Event'),
                subtitle: Text(DateFormat('MMM d, yyyy')
                    .format((eventData['date'] as Timestamp).toDate())),
                children: [
                  StreamBuilder(
                    stream: firestore
                        .collection('registrations')
                        .where('eventId', isEqualTo: event.id)
                        .snapshots(),
                    builder: (context, regSnap) {
                      if (regSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!regSnap.hasData || regSnap.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No participants yet.'),
                        );
                      }

                      final regs = regSnap.data!.docs;

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: regs.length,
                        itemBuilder: (context, j) {
                          final r = regs[j].data();
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(r['fullName'] ?? ''),
                            subtitle: Text(r['email'] ?? ''),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
