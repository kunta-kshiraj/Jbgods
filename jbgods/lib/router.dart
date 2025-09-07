import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/home/home_screen.dart';
import 'features/map/map_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/profile/profile_screen.dart';
import 'widgets/tab_scaffold.dart';

class LoginStateNotifier extends ChangeNotifier {
  LoginStateNotifier(this._ref) {
    _ref.listen(appStateProvider.select((s) => s.isLoggedIn), (previous, next) {
      if (previous != next) {
        notifyListeners();
      }
    });
  }

  final Ref _ref;

}

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.toString();
    switch (location) {
      case '/shell/home':
        _currentIndex = 0;
        break;
      case '/shell/map':
        _currentIndex = 1;
        break;
      case '/shell/chat':
        _currentIndex = 2;
        break;
      case '/shell/profile':
        _currentIndex = 3;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabScaffold(
      currentIndex: _currentIndex,
      onTabSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
        switch (index) {
          case 0:
            context.go('/shell/home');
            break;
          case 1:
            context.go('/shell/map');
            break;
          case 2:
            context.go('/shell/chat');
            break;
          case 3:
            context.go('/shell/profile');
            break;
        }
      },
      children: const [
        HomeScreen(),
        MapScreen(),
        ChatScreen(),
        ProfileScreen(),
      ],
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: LoginStateNotifier(ref),
    redirect: (ctx, state) {
      final isLoggedIn = ref.read(appStateProvider).isLoggedIn;
      if (!isLoggedIn && state.uri.toString().startsWith('/shell')) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, _) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (ctx, _) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (ctx, _) => const SignUpScreen(),
      ),
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/shell/home',
            builder: (ctx, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/shell/map',
            builder: (ctx, _) => const MapScreen(),
          ),
          GoRoute(
            path: '/shell/chat',
            builder: (ctx, _) => const ChatScreen(),
          ),
          GoRoute(
            path: '/shell/profile',
            builder: (ctx, _) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});