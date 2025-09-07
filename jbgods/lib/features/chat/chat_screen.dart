import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/jb_input.dart';
import '../../app_state.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final msgCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(appStateProvider.select((s) => s.messages));
    final isAdmin = ref.watch(appStateProvider.select((s) => s.isAdmin));
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const HeaderLogo(),
            SizedBox(height: 8),
            Text("Announcements", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg.senderName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(msg.text, style: TextStyle(color: Colors.white)),
                          SizedBox(height: 4),
                          Text(
                            "${msg.sentAt}",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12),
            if (!isAdmin)
              Text(
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
                  SizedBox(width: 8),
                  JBButton(
                    label: "Send",
                    dense: true,
                    onPressed: () {
                      if (msgCtrl.text.trim().isEmpty) return;
                      ref.read(appStateProvider.notifier).postAdminMessage(msgCtrl.text.trim());
                      msgCtrl.clear();
                    },
                  ),
                ],
              ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}