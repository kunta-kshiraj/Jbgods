import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'enroll_screen.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _events = [];
  bool _isAdminOrMaster = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadEvents();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'] ?? 'first_time';
    setState(() {
      _isAdminOrMaster = role == 'admin' || role == 'master';
    });
  }

    Future<bool> _isUserEnrolled(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final query = await FirebaseFirestore.instance
        .collection('registrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
    }


  Future<void> _loadEvents() async {
    final snapshot = await FirebaseFirestore.instance.collection('events').get();
    setState(() {
      _events = snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
    });
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events
        .where((e) {
          final eventDate = (e['date'] as Timestamp?)?.toDate();
          return eventDate != null &&
              eventDate.year == day.year &&
              eventDate.month == day.month &&
              eventDate.day == day.day;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final eventsToday = _getEventsForDay(_selectedDay ?? _focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Events Calendar"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.red.shade300,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(),
          Expanded(
            child: eventsToday.isEmpty
                ? const Center(child: Text("No events for this day"))
                : ListView.builder(
                    itemCount: eventsToday.length,
                    itemBuilder: (context, index) {
                      final e = eventsToday[index];
                      return _buildEventCard(context, e);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _isAdminOrMaster
          ? FloatingActionButton(
              onPressed: () => _showCreateOrEditSheet(context),
              backgroundColor: Colors.red,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> e) {
    return GestureDetector(
      onLongPress: _isAdminOrMaster
          ? () => _showEventActions(context, e)
          : null,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_isAdminOrMaster)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showEventActions(context, e),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy')
                        .format((e['date'] as Timestamp).toDate()),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 6),
                  Text(e['time'] ?? ''),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e['location'] ?? '')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                e['description'] ?? '',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (!_isAdminOrMaster)
                FutureBuilder<bool>(
                    future: _isUserEnrolled(e['id']),
                    builder: (context, snapshot) {
                    final enrolled = snapshot.data ?? false;

                    if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                        );
                    }

                    if (enrolled) {
                        return ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            ),
                        ),
                        child: const Text("Enrolled"),
                        );
                    }

                    return ElevatedButton(
                        onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                            builder: (_) => EnrollScreen(event: e),
                            ),
                        );
                        },
                        style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                        ),
                        ),
                        child: const Text("Click to Enroll"),
                    );
                    },
                ),


            ],
          ),
        ),
      ),
    );
  }

  void _showEventActions(BuildContext context, Map<String, dynamic> e) async {
    await showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
        child: Wrap(
            children: [
            ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                Navigator.pop(context);
                _showCreateOrEditSheet(context, event: e);
                },
            ),
            ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () async {
                Navigator.pop(context);
                try {
                    await FirebaseFirestore.instance
                        .collection('events')
                        .doc(e['id'])
                        .delete();

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ Event deleted successfully'),
                        backgroundColor: Colors.redAccent,
                    ),
                    );

                    await _loadEvents(); // refresh list
                } catch (err) {
                    ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('❌ Failed to delete event: $err'),
                        backgroundColor: Colors.red,
                    ),
                    );
                }
                },
            ),
            ],
        ),
        ),
    );
    }


  void _showCreateOrEditSheet(BuildContext context, {Map<String, dynamic>? event}) {
    final titleCtrl = TextEditingController(text: event?['title'] ?? '');
    final descCtrl = TextEditingController(text: event?['description'] ?? '');
    final costCtrl = TextEditingController(
        text: event?['cost']?.toString() ?? '');
    final locCtrl = TextEditingController(text: event?['location'] ?? '');
    DateTime? selectedDate =
        (event?['date'] as Timestamp?)?.toDate();
    TimeOfDay? selectedTime = event?['time'] != null && event!['time'] != ''
        ? _parseTime(event['time'])
        : null;

    showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        context: context,
        builder: (context) {
            return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
                return SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: StatefulBuilder(
                    builder: (context, setState) => Column(
                    children: [
                        TextField(
                            controller: titleCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Event Name')),
                        TextField(
                            controller: descCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Description')),
                        TextField(
                            controller: costCtrl,
                            decoration: const InputDecoration(labelText: 'Cost')),
                        TextField(
                            controller: locCtrl,
                            decoration: const InputDecoration(labelText: 'Location')),
                        const SizedBox(height: 10),
                        Row(
                        children: [
                            Expanded(
                            child: Text(
                                selectedDate == null
                                    ? 'Pick Date'
                                    : DateFormat.yMMMd().format(selectedDate!),
                                style: TextStyle(
                                color: selectedDate == null
                                    ? Colors.grey
                                    : Colors.black,
                                ),
                            ),
                            ),
                            TextButton(
                            onPressed: () async {
                                final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                );
                                if (picked != null) setState(() => selectedDate = picked);
                            },
                            child: const Text('Select'),
                            ),
                        ],
                        ),
                        Row(
                        children: [
                            Expanded(
                            child: Text(
                                selectedTime == null
                                    ? 'Pick Time'
                                    : selectedTime!.format(context),
                                style: TextStyle(
                                color: selectedTime == null
                                    ? Colors.grey
                                    : Colors.black,
                                ),
                            ),
                            ),
                            TextButton(
                            onPressed: () async {
                                final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                                );
                                if (time != null) setState(() => selectedTime = time);
                            },
                            child: const Text('Select'),
                            ),
                        ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                        onPressed: () async {
                            if (titleCtrl.text.trim().isEmpty ||
                                locCtrl.text.trim().isEmpty ||
                                costCtrl.text.trim().isEmpty ||
                                selectedDate == null ||
                                selectedTime == null) {
                            showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                title: const Text('Missing Details'),
                                content: const Text(
                                    'Please fill in all required fields: Event Name, Location, Cost, Date, and Time.'),
                                actions: [
                                    TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                    ),
                                ],
                                ),
                            );
                            return;
                            }

                            final user = FirebaseAuth.instance.currentUser;
                            final data = {
                            'title': titleCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'cost': double.tryParse(costCtrl.text) ?? 0.0,
                            'location': locCtrl.text.trim(),
                            'date': Timestamp.fromDate(selectedDate!),
                            'time': selectedTime!.format(context),
                            'updatedAt': FieldValue.serverTimestamp(),
                            'createdBy': user?.uid,
                            };

                            final col =
                                FirebaseFirestore.instance.collection('events');

                            try {
                            if (event == null) {
                                data['createdAt'] = FieldValue.serverTimestamp();
                                await col.add(data);
                                ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Event created')),
                                );
                            } else {
                                await col.doc(event['id']).update(data);
                                ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('✅ Event updated')),
                                );
                            }

                            if (mounted) Navigator.pop(context);
                            await _loadEvents();
                            } catch (err) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ Error saving: $err')),
                            );
                            }
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 48),
                        ),
                        child:
                            Text(event == null ? 'Create Event' : 'Save Changes'),
                        ),
                    ],
                    ),
                ),
                );
            },
            );
        },
        );
    }


  TimeOfDay _parseTime(String timeStr) {
    try {
        // Clean up any invisible Unicode spaces (common from iOS keyboards)
        final clean = timeStr
            .replaceAll('\u202F', ' ') // non-breaking narrow space
            .replaceAll('\u00A0', ' ') // non-breaking standard space
            .trim();

        final format = DateFormat.jm(); // matches "5:30 PM"
        final dt = format.parse(clean);
        return TimeOfDay.fromDateTime(dt);
    } catch (e) {
        debugPrint('⚠️ Failed to parse time "$timeStr": $e');
        return TimeOfDay.now(); // fallback to current time
    }
    }

}
