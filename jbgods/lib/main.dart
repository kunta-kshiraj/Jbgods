import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'router.dart';
import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStateNotifier.ensurePrefsInitialized();
  runApp(const ProviderScope(child: JBGodsApp()));
}

class JBGodsApp extends ConsumerWidget {
  const JBGodsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appStateProvider.select((s) => s.themeMode));
    final router = ref.read(routerProvider);
    return MaterialApp.router(
      title: 'JB GODS',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}