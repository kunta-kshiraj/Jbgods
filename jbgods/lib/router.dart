import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_state.dart';
import 'data/auth_providers.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/home/home_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/events/events_page.dart';
import 'features/rinks/rinks_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/privacy_policy_screen.dart';
import 'features/auth/terms_privacy_screen.dart';
import 'features/admin/requests_screen.dart';
import 'features/admin/reports_screen.dart';
import 'features/community/community_screen.dart';
import 'features/auth/signup_choice_screen.dart';
import 'features/auth/signup_owner_screen.dart';
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

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider);
    
    // First-time users and first-time owners ONLY see the profile page - no navigation
    if (userRole == 'first_time' || userRole == 'first_time_owner') {
      return const ProfileScreen();
    }
    
    // Members, admins, and approved owners get the full navigation
    return _MainShellWithNavigation(child: child);
  }
}

class _MainShellWithNavigation extends ConsumerStatefulWidget {
  final Widget child;
  const _MainShellWithNavigation({required this.child});

  @override
  ConsumerState<_MainShellWithNavigation> createState() => _MainShellWithNavigationState();
}

class _MainShellWithNavigationState extends ConsumerState<_MainShellWithNavigation> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.toString();
    
    switch (location) {
      case '/shell/home':
        _currentIndex = 0;
        break;
      case '/shell/chat':
        _currentIndex = 1;
        break;
      case '/shell/events':
        _currentIndex = 2;
        break;
      case '/shell/rinks':
        _currentIndex = 3;
        break;
      case '/shell/profile':
        _currentIndex = 4;
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
            context.go('/shell/chat');
            break;
          case 2:
            context.go('/shell/events');
            break;
          case 3:
            context.go('/shell/rinks');
            break;
          case 4:
            context.go('/shell/profile');
            break;
        }
      },
      children: const [
        HomeScreen(),
        ChatScreen(),
        EventsPage(),
        RinksScreen(),
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

      // 3) Logged in: check email verification first
      if (user.emailVerified == false) {
        // If email not verified, redirect to verify email page
        if (path != '/verify-email') {
          return '/verify-email';
        }
        return null; // Stay on verify email page
      }

      // 4) Email verified: redirect from auth pages
      if (path == '/' || path == '/login' || path == '/signup' || path == '/verify-email') {
        // Use userRoleProvider which has a fallback
        final role = ref.read(userRoleProvider);
        if (role == 'first_time' || role == 'first_time_owner') {
          return '/shell/profile'; // First-time users and owners only see profile
        }
        return '/shell/home'; // Members, admins, and approved owners go to home
      }

      // 4) First-time users and first-time owners can only access profile page (allow Privacy Policy)
      final role = ref.read(userRoleProvider);
      if ((role == 'first_time' || role == 'first_time_owner') && !(path.startsWith('/shell/profile') || path == '/privacy-policy' || path == '/terms-privacy')) {
        return '/shell/profile'; // Redirect first-time users and owners to profile
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
        path: '/signup-choice',
        builder: (ctx, _) => const SignupChoiceScreen(),
      ),
      GoRoute(
        path: '/signup/member',
        builder: (ctx, _) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/signup/owner',
        builder: (ctx, _) => const SignUpOwnerScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (ctx, _) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (ctx, _) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (ctx, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/terms-privacy',
        builder: (ctx, _) => const TermsPrivacyScreen(),
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
      GoRoute(
        path: '/admin/community',
        redirect: (ctx, state) {
          final auth = ref.read(authStateChangesProvider);
          if (auth.isLoading) return null;
          final user = auth.value;
          if (user == null) return '/login';

          final roleAsync = ref.read(currentUserRoleProvider);
          if (roleAsync.isLoading) return null;
          final role = roleAsync.value ?? 'first_time';
          if (role != 'master') return '/shell/home';
          return null;
        },
        builder: (ctx, _) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        redirect: (ctx, state) {
          final auth = ref.read(authStateChangesProvider);
          if (auth.isLoading) return null;
          final user = auth.value;
          if (user == null) return '/login';

          final roleAsync = ref.read(currentUserRoleProvider);
          if (roleAsync.isLoading) return null;
          final role = roleAsync.value ?? 'first_time';
          if (role != 'master') return '/shell/home';
          return null;
        },
        builder: (ctx, _) => const ReportsScreen(),
      ),
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/shell/home',
            builder: (ctx, _) => const HomeScreen(),
          ),
          GoRoute(
            path: '/shell/chat',
            builder: (ctx, _) => const ChatScreen(),
          ),
          GoRoute(
            path: '/shell/profile',
            builder: (ctx, _) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/shell/events',
            builder: (ctx, _) => const EventsPage(),
          ),
          GoRoute(
            path: '/shell/rinks',
            builder: (ctx, _) => const RinksScreen(),
          ),
        ],
      ),
    ],
  );
});