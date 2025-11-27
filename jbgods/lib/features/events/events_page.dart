import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'enroll_screen.dart';
import '../../widgets/jb_input.dart';
import '../../widgets/jb_button.dart';
import '../../data/auth_providers.dart';

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
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

  String _currentUserRole = 'first_time';
  
  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final role = doc.data()?['role'] ?? 'first_time';
    setState(() {
      _currentUserRole = role;
      _isAdminOrMaster = role == 'admin' || role == 'master' || role == 'owner';
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

  /// Check if the three dots menu (edit/delete actions) should be shown
  /// Returns true if: no registrations exist OR event date has passed
  /// Returns false if: registrations exist AND event date hasn't passed
  Future<bool> _canShowEventActions(String eventId, Timestamp? eventDate) async {
    try {
      // Check if there are any registrations
      final registrationsSnapshot = await FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();
      
      final hasRegistrations = registrationsSnapshot.docs.isNotEmpty;
      
      // If no registrations, always allow actions
      if (!hasRegistrations) {
        return true;
      }
      
      // If registrations exist, check if event date has passed
      if (eventDate == null) {
        // If event date is null and there are registrations, don't show actions
        return false;
      }
      
      final now = DateTime.now();
      final eventDateTime = eventDate.toDate();
      // Compare dates only (ignore time) - event date is considered passed if it's before today
      final today = DateTime(now.year, now.month, now.day);
      final eventDay = DateTime(eventDateTime.year, eventDateTime.month, eventDateTime.day);
      
      // Event date has passed if eventDay is before today (i.e., event was yesterday or earlier)
      final eventDatePassed = eventDay.isBefore(today);
      
      return eventDatePassed;
    } catch (e) {
      // On error, default to showing actions (safer fallback)
      return true;
    }
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Events Calendar"),
        centerTitle: true,
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
              markerDecoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              weekendTextStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              outsideTextStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              disabledTextStyle: TextStyle(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: isDark ? Colors.white : Colors.black87,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              weekendStyle: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          Divider(color: isDark ? Colors.white24 : Colors.black12),
          Expanded(
            child: eventsToday.isEmpty
                ? Center(
                    child: Text(
                      "No events for this day",
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  )
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.colorScheme.primary;
    
    // Match home page card colors - increase opacity in dark theme for better visibility
    final headColor = isDark 
        ? base.withValues(alpha: 0.30) 
        : base.withValues(alpha: 0.20);
    final bodyColor = isDark 
        ? base.withValues(alpha: 0.22) 
        : base.withValues(alpha: 0.12);
    final footColor = isDark 
        ? base.withValues(alpha: 0.18) 
        : base.withValues(alpha: 0.10);
    
    // Use full white in dark theme for better contrast
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;
    
    // Check if current user is the creator or master
    final currentUser = ref.read(currentUserProvider);
    final userRole = ref.read(userRoleProvider);
    final isMaster = userRole == 'master';
    final eventCreatorId = e['createdBy'] as String?;
    final isCreator = currentUser != null && eventCreatorId == currentUser.uid;
    final canEditOrDelete = isCreator || isMaster;
    
    // Get event date and ID for checking registrations
    final eventId = e['id'] as String;
    final eventDate = e['date'] as Timestamp?;
    
    return FutureBuilder<bool>(
      future: _canShowEventActions(eventId, eventDate),
      builder: (context, actionsSnapshot) {
        // While loading, don't show actions (safer default)
        final canShowActions = actionsSnapshot.hasData ? (actionsSnapshot.data ?? false) : false;
        final actionsAllowed = canEditOrDelete && canShowActions;
        
        return GestureDetector(
          onLongPress: actionsAllowed
              ? () => _showEventActions(context, e)
              : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Title with actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                color: headColor,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      e['title'] ?? 'Untitled Event',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // Show three dots only if user can edit/delete AND actions are allowed
                  if (canEditOrDelete && actionsAllowed)
                    IconButton(
                      icon: Icon(Icons.more_vert, color: textColor),
                      onPressed: () => _showEventActions(context, e),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            // Body: Event details
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: bodyColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e['date'] != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: iconColor),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEEE, MMM d, yyyy')
                              .format((e['date'] as Timestamp).toDate()),
                          style: TextStyle(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (e['time'] != null && (e['time'] as String).isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: iconColor),
                        const SizedBox(width: 6),
                        Text(
                          e['time'] ?? '',
                          style: TextStyle(color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (e['location'] != null && (e['location'] as String).isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.place, size: 16, color: iconColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e['location'] ?? '',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (e['description'] != null && (e['description'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      e['description'] ?? '',
                      style: TextStyle(
                        color: isDark ? Colors.white : textColor.withOpacity(0.8), 
                        height: 1.26,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Footer: Enrollment button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                color: footColor,
              ),
              child: !_isAdminOrMaster
                  ? FutureBuilder<bool>(
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
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("Click to Enroll"),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
        );
      },
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
                
                // Check if event can be deleted
                try {
                  final eventId = e['id'] as String;
                  final eventDate = e['date'] as Timestamp?;
                  
                  // Check if there are any registrations
                  final registrationsSnapshot = await FirebaseFirestore.instance
                      .collection('registrations')
                      .where('eventId', isEqualTo: eventId)
                      .limit(1)
                      .get();
                  
                  final hasRegistrations = registrationsSnapshot.docs.isNotEmpty;
                  
                  // Check if event date has passed
                  final now = DateTime.now();
                  final eventDateTime = eventDate?.toDate();
                  final eventDatePassed = eventDateTime != null && eventDateTime.isBefore(now);
                  
                  // Cannot delete if there are registrations AND (event date is null OR event date hasn't passed)
                  if (hasRegistrations) {
                    if (eventDate == null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Cannot delete event: Users have enrolled and event date is not set. Please set an event date first.'),
                          backgroundColor: Colors.orange,
                          duration: Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                    
                    if (!eventDatePassed) {
                      if (!mounted) return;
                      final eventDateStr = DateFormat('MMM d, yyyy').format(eventDateTime!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Cannot delete event: Users have enrolled. Event can only be deleted after the event date ($eventDateStr) has passed.'),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      return;
                    }
                  }
                  
                  // Show confirmation dialog
                  final confirmDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Event'),
                      content: Text(
                        hasRegistrations
                            ? 'This event has enrolled participants. Are you sure you want to delete it? (Event date has passed)'
                            : 'Are you sure you want to delete this event?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmDelete != true) return;
                  
                  // Delete the event
                  await FirebaseFirestore.instance
                      .collection('events')
                      .doc(eventId)
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
                  if (!mounted) return;
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
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
                    left: 24,
                    right: 24,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: StatefulBuilder(
                    builder: (context, setState) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Title
                        Text(
                          event == null ? 'Create Event' : 'Edit Event',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        JBInput(
                            controller: titleCtrl,
                            label: 'Event Name',
                        ),
                        const SizedBox(height: 16),
                        JBInput(
                            controller: costCtrl,
                            label: 'Cost',
                            keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        JBInput(
                            controller: locCtrl,
                            label: 'Location',
                        ),
                        const SizedBox(height: 16),
                        // Date Picker
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedDate == null
                                      ? 'Pick Date'
                                      : DateFormat.yMMMd().format(selectedDate!),
                                  style: TextStyle(
                                    color: selectedDate == null
                                        ? (isDark ? Colors.white54 : Colors.grey)
                                        : (isDark ? Colors.white : Colors.black87),
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
                                child: Text(
                                  'Select',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Time Picker
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 20,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedTime == null
                                      ? 'Pick Time'
                                      : selectedTime!.format(context),
                                  style: TextStyle(
                                    color: selectedTime == null
                                        ? (isDark ? Colors.white54 : Colors.grey)
                                        : (isDark ? Colors.white : Colors.black87),
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
                                child: Text(
                                  'Select',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Description field (multiline, expandable)
                        TextFormField(
                          controller: descCtrl,
                          maxLines: null, // Allows unlimited lines
                          minLines: 3, // Starts with 3 lines
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey[300]!,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: JBButton(
                            label: event == null ? 'Create Event' : 'Save Changes',
                            onPressed: () async {
                              if (titleCtrl.text.trim().isEmpty ||
                                  locCtrl.text.trim().isEmpty ||
                                  costCtrl.text.trim().isEmpty ||
                                  selectedDate == null ||
                                  selectedTime == null) {
                                showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                    title: Text(
                                      'Missing Details',
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                    ),
                                    content: Text(
                                        'Please fill in all required fields: Event Name, Location, Cost, Date, and Time.',
                                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                                    ),
                                    backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
                                    actions: [
                                        TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(
                                          'OK',
                                          style: TextStyle(color: theme.colorScheme.primary),
                                        ),
                                        ),
                                    ],
                                    ),
                                );
                                return;
                              }

                              final user = FirebaseAuth.instance.currentUser;
                              final data = <String, dynamic>{
                              'title': titleCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'cost': double.tryParse(costCtrl.text) ?? 0.0,
                              'location': locCtrl.text.trim(),
                              'date': Timestamp.fromDate(selectedDate!),
                              'time': selectedTime!.format(context),
                              'updatedAt': FieldValue.serverTimestamp(),
                              };

                              try {
                              if (event == null) {
                                  // For new events, check if user is master
                                  final isMaster = _currentUserRole == 'master';
                                  
                                  data['createdBy'] = user?.uid;
                                  data['createdAt'] = FieldValue.serverTimestamp();
                                  
                                  if (isMaster) {
                                    // Master can create events directly
                                    await FirebaseFirestore.instance
                                        .collection('events')
                                        .add(data);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Event created and published'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    // Admin/Owner: save as pending request
                                    data['status'] = 'pending';
                                    data['requestedAt'] = FieldValue.serverTimestamp();
                                    
                                    // Get creator name for display
                                    final userDoc = await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user?.uid)
                                        .get();
                                    final creatorName = userDoc.data()?['name'] ?? 
                                                       userDoc.data()?['ownerName'] ?? 
                                                       userDoc.data()?['username'] ?? 
                                                       'Unknown';
                                    final creatorRole = userDoc.data()?['role'] ?? 'unknown';
                                    
                                    data['creatorName'] = creatorName;
                                    data['creatorRole'] = creatorRole;
                                    
                                    await FirebaseFirestore.instance
                                        .collection('event_requests')
                                        .add(data);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Event request submitted! Waiting for master approval.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 4),
                                      ),
                                    );
                                  }
                              } else {
                                  // For updates, don't modify createdBy (preserve original creator)
                                  await FirebaseFirestore.instance
                                      .collection('events')
                                      .doc(event['id'])
                                      .update(data);
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
                          ),
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
