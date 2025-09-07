import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/header_logo.dart';
import '../../app_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(appStateProvider.select((s) => s.events));
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const HeaderLogo(),
              SizedBox(height: 16),
              Text("Upcoming Events", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
              SizedBox(height: 16),
              ...events.map((evt) => Card(
                margin: EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(evt.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 6),
                      Text("Date: ${evt.dateTime}"),
                      Text("Location: ${evt.location}"),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Chip(
                          label: Text("Details"),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ))
            ],
          ),
        ),
      ),
    );
  }
}