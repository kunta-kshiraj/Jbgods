// lib/features/admin/reports_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_providers.dart';
import '../../widgets/header_logo.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firestore = ref.watch(firestoreProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/shell/profile'),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('reports')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          
          final reports = snapshot.data?.docs ?? [];
          
          // Sort reports by createdAt in descending order (newest first)
          reports.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });
          
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending reports',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All reports have been reviewed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final data = report.data();
              
              return _ReportCard(
                reportId: report.id,
                reporterId: data['reporterId'] ?? '',
                reportedUserId: data['reportedUserId'] ?? '',
                reportedUserName: data['reportedUserName'] ?? 'Unknown User',
                messageId: data['messageId'] ?? '',
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                onAccept: () => _handleReport(ref, report.id, 'accepted'),
                onIgnore: () => _handleReport(ref, report.id, 'ignored'),
              );
            },
          );
        },
      ),
    );
  }
  
  Future<void> _handleReport(WidgetRef ref, String reportId, String status) async {
    final firestore = ref.read(firestoreProvider);
    
    try {
      if (status == 'accepted') {
        // Get the report data first
        final reportDoc = await firestore.collection('reports').doc(reportId).get();
        final reportData = reportDoc.data();
        
        if (reportData != null) {
          final reportedUserId = reportData['reportedUserId'] as String?;
          
          if (reportedUserId != null) {
            // Remove the user as member (set role to 'first_time')
            await firestore.collection('users').doc(reportedUserId).update({
              'role': 'first_time',
            });
          }
        }
      }
      
      // Update report status
      await firestore.collection('reports').doc(reportId).update({
        'status': status,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      // Handle error - you might want to show a snackbar here
      print('Error handling report: $e');
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.reportId,
    required this.reporterId,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.messageId,
    required this.createdAt,
    required this.onAccept,
    required this.onIgnore,
  });

  final String reportId;
  final String reporterId;
  final String reportedUserId;
  final String reportedUserName;
  final String messageId;
  final DateTime createdAt;
  final VoidCallback onAccept;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Report #${reportId.substring(0, 8)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Report details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reported User: $reportedUserName',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Message ID: ${messageId.substring(0, 8)}...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onIgnore,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Ignore'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Remove User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
