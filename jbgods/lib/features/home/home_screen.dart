// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:go_router/go_router.dart';

import '../../widgets/header_logo.dart';
import '../../data/auth_providers.dart';
import '../../data/firestore_streams.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsStream = ref.watch(eventsQueryProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final isMaster = ref.watch(userRoleProvider) == 'master';
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              heroTag:'eventsFab',
              onPressed: () => _showEventSheet(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Fixed header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(child: HeaderLogo()),
                    if (isMaster)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined),
                            onPressed: () => context.push('/notifications'),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  "Upcoming Events/Updates",
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 20),
                ),
              ],
            ),
          ),

          // Scrollable events area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: eventsStream.when(
                data: (snap) {
                  if (snap.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No events yet.'),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: snap.docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final d = snap.docs[index];
                      final data = d.data();

                      final title = (data['title'] as String?) ?? '';
                      final description = (data['description'] as String?) ?? '';
                      final ts = data['dateTime'] as Timestamp?;
                      final dt = ts?.toDate();

                      return GestureDetector(
                        onLongPress: isAdmin
                            ? () => _showEventActions(
                                  context: context,
                                  ref: ref,
                                  docId: d.id,
                                  currentData: data,
                                )
                            : null,
                        child: _EventCard(
                          title: title,
                          description: description,
                          dateTime: dt,
                          showHint: isAdmin,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Centered popup with Edit / Delete / Close
  Future<void> _showEventActions({
    required BuildContext context,
    required WidgetRef ref,
    required String docId,
    required Map<String, dynamic> currentData,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Event actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEventSheet(context, ref, docId: docId, initial: currentData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete this event?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await ref.read(firestoreProvider).collection('updates').doc(docId).delete();
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Update deleted')),
                    );
                  } catch (e) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // Bottom-sheet editor for create/update (unchanged)
  void _showEventSheet(BuildContext context, WidgetRef ref,
      {String? docId, Map<String, dynamic>? initial}) {
    final titleCtrl =
        TextEditingController(text: initial?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: initial?['description'] as String? ?? '');
    DateTime? dt = (initial?['dateTime'] as Timestamp?)?.toDate();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  JBInput(controller: titleCtrl, label: 'Title'),
                  const SizedBox(height: 12),
                  JBInput(controller: descCtrl, label: 'Description'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dt == null
                              ? 'No date selected'
                              : dt!.toLocal().toString().split('.').first,
                        ),
                      ),
                      JBButton(
                        label: 'Pick Date',
                        dense: true,
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dt ?? DateTime.now(),
                            firstDate: DateTime(1950),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            dt = picked;
                            Navigator.pop(context);
                            _showEventSheet(
                              context,
                              ref,
                              docId: docId,
                              initial: {
                                'title': titleCtrl.text,
                                'description': descCtrl.text,
                                'dateTime':
                                    dt == null ? null : Timestamp.fromDate(dt!),
                              },
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  JBButton(
                    label: docId == null ? 'Create' : 'Save',
                    onPressed: () async {
                      try {
                        final data = <String, dynamic>{
                          'title': titleCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'dateTime':
                              dt == null ? null : Timestamp.fromDate(dt!),
                          'createdAt': FieldValue.serverTimestamp(),
                          'updatedAt': FieldValue.serverTimestamp(),
                          'createdBy': ref.read(currentUserProvider)?.uid,
                        };
                        final col =
                            ref.read(firestoreProvider).collection('updates');
                        if (docId == null) {
                          await col.add(data);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Event created')),
                          );
                        } else {
                          await col.doc(docId).set(data, SetOptions(merge: true));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Event updated')),
                          );
                        }
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

  }
}

/// Event card styled like the chat bubble (three shaded sections)
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.title,
    required this.description,
    required this.dateTime,
    this.showHint = false,
  });

  final String title;
  final String description;
  final DateTime? dateTime;
  final bool showHint;

  String get _time =>
      dateTime == null ? '' : DateFormat('h:mm a').format(dateTime!.toLocal());
  String get _date =>
      dateTime == null ? '' : DateFormat('y-MM-dd').format(dateTime!.toLocal());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.primary;

    // match chat card shades
    final headColor = base.withValues(alpha: 0.20);
    final bodyColor = base.withValues(alpha: 0.12);
    final footColor = base.withValues(alpha: 0.10);

    final textColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black87;
    final maxW = MediaQuery.of(context).size.width * 0.90; // a bit wider

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
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
            // Header: Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ).copyWith(color: headColor),
              child: Text(
                title.isEmpty ? 'Untitled Event' : title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ),

            // Body: Description (optional)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: bodyColor,
              child: Text(
                description.isEmpty ? 'No description' : description,
                style: TextStyle(color: textColor, height: 1.26),
              ),
            ),

            // Footer: time then date (like chat)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ).copyWith(color: footColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_time.isNotEmpty)
                    Text(_time,
                        style: TextStyle(
                            fontSize: 12, color: textColor.withOpacity(0.75))),
                  if (_date.isNotEmpty)
                    Text(_date,
                        style: TextStyle(
                            fontSize: 12, color: textColor.withOpacity(0.55))),
                  if (showHint)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Long-press for actions',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
