import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventParticipantsScreen extends StatefulWidget {
  final String creatorId; // current user's UID
  final bool isMaster; // whether the user is master
  const EventParticipantsScreen({
    super.key,
    required this.creatorId,
    this.isMaster = false,
  });

  @override
  State<EventParticipantsScreen> createState() =>
      _EventParticipantsScreenState();
}

class _EventParticipantsScreenState extends State<EventParticipantsScreen> {
  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    // If master, show all events. Otherwise, show only events created by this user
    final eventsQuery = widget.isMaster
        ? firestore.collection('events').snapshots()
        : firestore
            .collection('events')
            .where('createdBy', isEqualTo: widget.creatorId)
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isMaster
            ? 'All Event Participants'
            : 'Event Participants'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder(
        stream: eventsQuery,
        builder: (context, eventSnap) {
          if (eventSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!eventSnap.hasData || eventSnap.data!.docs.isEmpty) {
            return Center(
              child: Text(
                widget.isMaster
                    ? 'No events found.'
                    : 'No events created yet.',
              ),
            );
          }

          final events = eventSnap.data!.docs;

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, i) {
              final event = events[i];
              final eventData = event.data();

              // Get creator info for master view
              final createdBy = eventData['createdBy'] ?? '';
              
              return ExpansionTile(
                title: Text(eventData['title'] ?? 'Untitled Event'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventData['date'] != null
                          ? DateFormat('MMM d, yyyy')
                              .format((eventData['date'] as Timestamp).toDate())
                          : 'Date not set',
                    ),
                    if (widget.isMaster && createdBy.isNotEmpty)
                      FutureBuilder<DocumentSnapshot>(
                        future: firestore.collection('users').doc(createdBy).get(),
                        builder: (context, creatorSnap) {
                          if (creatorSnap.connectionState == ConnectionState.waiting) {
                            return const SizedBox.shrink();
                          }
                          final creatorData = creatorSnap.data?.data() as Map<String, dynamic>?;
                          // Prioritize 'name', then 'ownerName' (for owners), then 'username'
                          final name = creatorData?['name'] as String?;
                          final ownerName = creatorData?['ownerName'] as String?;
                          final username = creatorData?['username'] as String?;
                          final creatorName = (name != null && name.isNotEmpty) 
                              ? name 
                              : (ownerName != null && ownerName.isNotEmpty)
                                  ? ownerName
                                  : (username != null && username.isNotEmpty) 
                                      ? username 
                                      : 'Unknown';
                          final creatorRole = creatorData?['role'] ?? 'unknown';
                          return Text(
                            'Created by: $creatorName (${creatorRole.toUpperCase()})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                  ],
                ),
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
