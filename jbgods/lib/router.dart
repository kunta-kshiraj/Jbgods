import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';
import 'data/auth_providers.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/home/home_screen.dart';
import 'features/map/map_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/admin/requests_screen.dart';
import 'widgets/tab_scaffold.dart';

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._ref) {
    _ref.listen(authStateChangesProvider, (previous, next) {
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
    refreshListenable: AuthStateNotifier(ref),
    redirect: (ctx, state) {
      final auth = ref.read(authStateChangesProvider); // AsyncValue<User?>
      final path = state.uri.toString();

      // 1) While Firebase auth is still initializing -> do nothing
      if (auth.isLoading) return null;

      final user = auth.value;

      // 2) Not logged in: block shell + land on login even from '/'
      if (user == null) {
        if (path.startsWith('/shell') || path == '/') return '/login';
        return null;
      }

      // 3) Logged in: keep them out of auth pages & '/' goes to home
      if (path == '/' || path == '/login' || path == '/signup') {
        return '/shell/home';
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
      GoRoute(
        path: '/admin/requests',
        redirect: (ctx, state) {
          final auth = ref.read(authStateChangesProvider);
          if (auth.isLoading) return null; // wait for Firebase to initialize

          final user = auth.value;
          if (user == null) return '/login';

          final roleAsync = ref.read(currentUserRoleProvider);
          if (roleAsync.isLoading) return null;  // wait for Firestore user doc

          final role = roleAsync.value ?? 'first_time'; // 'admin'|'master'|...
          if (role != 'admin' && role != 'master') return '/shell/home';

          return null;
        },
        builder: (ctx, _) => const AdminRequestsScreen(),
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