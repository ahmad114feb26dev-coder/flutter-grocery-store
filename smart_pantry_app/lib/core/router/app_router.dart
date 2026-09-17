import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/presentation/screens/main_shell.dart';
import '../../features/inventory/presentation/screens/add_edit_ingredient_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../providers/core_providers.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
    _ref.listen(sessionExpirySignalProvider, (_, __) {
      _ref.read(authControllerProvider.notifier).handleSessionExpired();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    // Do not redirect while on the splash screen so splash animations can play smoothly
    if (state.matchedLocation == '/splash') {
      return null;
    }

    final authState = _ref.read(authControllerProvider);

    // Hold redirection while initial auth state is loading
    if (authState.isLoading && !authState.hasValue) {
      return null;
    }

    final isAuth = authState.valueOrNull != null;
    final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    // If NOT authenticated and attempting to access any protected route (like /dashboard):
    if (!isAuth && !isLoggingIn) {
      return '/login';
    }

    // If already authenticated and on login or register screen:
    if (isAuth && isLoggingIn) {
      return '/dashboard';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/inventory/add',
        builder: (context, state) => const AddEditIngredientScreen(),
      ),
      GoRoute(
        path: '/inventory/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddEditIngredientScreen(ingredientId: id);
        },
      ),
    ],
  );
});
