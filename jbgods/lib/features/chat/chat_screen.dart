// lib/features/chat/chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
import '../../data/auth_providers.dart';
import '../../data/firestore_streams.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final msgCtrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isNearBottom {
    if (!_scroll.hasClients) return true;
    final pos = _scroll.position;
    return (pos.maxScrollExtent - pos.pixels) < 120; // ~120px from bottom
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    if (msgCtrl.text.trim().isEmpty) return;
    try {
      final firestore = ref.read(firestoreProvider);
      final user = ref.read(currentUserProvider);
      final profile = ref.read(userProfileProvider);
      if (user == null || profile == null) return;

      await firestore.collection('messages').add({
        'text': msgCtrl.text.trim(),
        'authorId': user.uid,
        'authorName': profile['username'] ?? 'Unknown',
        'createdAt': FieldValue.serverTimestamp(),
      });
      msgCtrl.clear();

      if (_isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  Future<void> _editMessage(String id, String text) async {
    final controller = TextEditingController(text: text);
    final firestore = ref.read(firestoreProvider);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await firestore.collection('messages').doc(id).update({
                  'text': controller.text.trim(),
                });
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to edit: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String id) async {
    try {
      final firestore = ref.read(firestoreProvider);
      await firestore.collection('messages').doc(id).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _showMessageActions({
    required String id,
    required String currentText,
    required bool canEdit,
    required bool canDelete,
  }) async {
    if (!canEdit && !canDelete) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(id, currentText);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete message?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await _deleteMessage(id);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = ref.watch(messagesQueryProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const HeaderLogo(),
            const SizedBox(height: 8),
            Text(
              "Announcements",
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: messagesStream.when(
                data: (snap) {
                  final docs = snap.docs;

                  // Build a render list that includes date headers.
                  // We keep the query's existing order (likely newest first),
                  // and because the ListView is reverse:true, we append the date
                  // header *after* the last message of that date so it appears
                  // visually on top of that day's messages.
                  final List<_RowItem> items = [];
                  for (var i = 0; i < docs.length; i++) {
                    final d = docs[i];
                    final data = d.data();
                    final ts = (data['createdAt'] as Timestamp?)?.toDate();
                    final local = ts?.toLocal() ?? DateTime.now();

                    final dateKey = DateFormat('yyyy-MM-dd').format(local);
                    final dateLabel = DateFormat('MM/dd/yyyy').format(local);

                    items.add(_MessageItem(
                      id: d.id,
                      text: (data['text'] as String?) ?? '',
                      authorId: (data['authorId'] as String?) ?? '',
                      authorName: (data['authorName'] as String?) ?? 'Unknown',
                      createdAt: local,
                      dateKey: dateKey,
                    ));

                    // decide if a header should follow this message (so it renders above when reversed)
                    final nextLocal = (i + 1 < docs.length)
                        ? ((docs[i + 1].data()['createdAt'] as Timestamp?)?.toDate()?.toLocal() ??
                            DateTime.now())
                        : null;
                    final nextKey = nextLocal == null ? null : DateFormat('yyyy-MM-dd').format(nextLocal);

                    final isGroupTail = (i == docs.length - 1) || (nextKey != dateKey);
                    if (isGroupTail) {
                      items.add(_HeaderItem(dateKey: dateKey, dateLabel: dateLabel));
                    }
                  }

                  // auto-scroll if near bottom
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_isNearBottom) _jumpToBottom();
                  });

                  return ListView.builder(
                    controller: _scroll,
                    reverse: true, // newest appears near visual bottom
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      if (it is _HeaderItem) {
                        return _DateDivider(label: it.dateLabel);
                      } else if (it is _MessageItem) {
                        final me = ref.read(currentUserProvider);
                        final isMaster = ref.read(userRoleProvider) == 'master';
                        final canEdit = it.authorId == me?.uid;
                        final canDelete = canEdit || isMaster;

                        return GestureDetector(
                          onLongPress: () => _showMessageActions(
                            id: it.id,
                            currentText: it.text,
                            canEdit: canEdit,
                            canDelete: canDelete,
                          ),
                          child: _MessageTile(
                            name: it.authorName,
                            time: DateFormat('h:mm a').format(it.createdAt),
                            message: it.text,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),

            const SizedBox(height: 12),
            if (!isAdmin)
              const Text(
                "Only admins can post here.",
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),

            if (isAdmin)
              Row(
                children: [
                  Expanded(
                    child: JBInput(
                      controller: msgCtrl,
                      label: "Type announcement...",
                    ),
                  ),
                  const SizedBox(width: 8),
                  JBButton(
                    label: "Send",
                    dense: true,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/* ---------- Render items (message or date header) ---------- */

abstract class _RowItem {}

class _HeaderItem extends _RowItem {
  _HeaderItem({required this.dateKey, required this.dateLabel});
  final String dateKey;
  final String dateLabel;
}

class _MessageItem extends _RowItem {
  _MessageItem({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.dateKey,
  });

  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final String dateKey;
}

/* ---------- UI pieces ---------- */

/// Centered date divider used once per day.
class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.primary;
    final chipBg = base.withOpacity(0.12);
    final line = base.withOpacity(0.25);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: line)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: line),
            ),
            child: Text(
              label, // e.g. 09/11/2025
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(.75),
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: line)),
        ],
      ),
    );
  }
}

/// Message tile styled like events (primary-tinted card),
/// First row: Name ..... Time
/// Second row: Message
class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.name,
    required this.time,
    required this.message,
  });

  final String name;
  final String time;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base   = theme.colorScheme.primary;
    final bg     = base.withOpacity(0.10);
    final border = base.withOpacity(0.25);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name ..... Time
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time, // e.g. 8:13 PM
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(.65),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Message
          Text(
            message,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(.95),
              height: 1.26,
            ),
          ),
        ],
      ),
    );
  }
}
