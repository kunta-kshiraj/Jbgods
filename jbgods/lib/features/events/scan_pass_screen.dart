import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/auth_providers.dart';

class ScanPassScreen extends ConsumerStatefulWidget {
  final String eventId;
  const ScanPassScreen({super.key, required this.eventId});

  @override
  ConsumerState<ScanPassScreen> createState() => _ScanPassScreenState();
}

class _ScanPassScreenState extends ConsumerState<ScanPassScreen> {
  bool _scanned = false;
  String? _resultMessage;
  bool? _resultSuccess;

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _scanned = true);

    try {
      final payload = jsonDecode(code) as Map<String, dynamic>?;
      final rid = payload?['rid'] as String?;
      final passCode = payload?['code'] as String?;
      if (rid == null || passCode == null) {
        setState(() {
          _resultSuccess = false;
          _resultMessage = 'Invalid QR code';
        });
        return;
      }

      final functions = ref.read(firebaseFunctionsProvider);
      final result = await functions.httpsCallable('checkInEventPass').call({
        'rid': rid,
        'code': passCode,
      });

      final data = result.data as Map<String, dynamic>?;
      if (data != null && data['ok'] == true) {
        final name = data['userName'] as String? ?? 'Attendee';
        final at = data['checkedInAt'];
        String timeStr = '';
        if (at != null && at is Map && at['_seconds'] != null) {
          final ts = Timestamp.fromMillisecondsSinceEpoch((at['_seconds'] as int) * 1000);
          timeStr = ' at ${ts.toDate().toLocal().toString().substring(11, 16)}';
        }
        setState(() {
          _resultSuccess = true;
          _resultMessage = '$name checked in$timeStr';
        });
      } else {
        setState(() {
          _resultSuccess = false;
          _resultMessage = data?['message'] as String? ?? 'Check-in failed';
        });
      }
    } on Exception catch (e) {
      String msg = e.toString();
      if (msg.contains('already-checked-in')) {
        msg = 'Already checked in';
      } else if (msg.contains('invalid')) {
        msg = 'Invalid QR or pass';
      } else if (msg.contains('not-authorized')) {
        msg = 'Not authorized to check in for this event';
      }
      setState(() {
        _resultSuccess = false;
        _resultMessage = msg;
      });
    }

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _scanned = false;
        _resultMessage = null;
        _resultSuccess = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Pass'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                onDetect: _onDetect,
                controller: MobileScannerController(
                  detectionSpeed: DetectionSpeed.normal,
                  facing: CameraFacing.back,
                ),
              ),
            ),
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _resultSuccess == true
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _resultSuccess == true ? Icons.check_circle : Icons.error,
                    color: _resultSuccess == true ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _resultMessage!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _resultSuccess == true ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Position the QR code within the frame',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
