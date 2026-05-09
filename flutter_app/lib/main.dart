import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'core/auth/auth_controller.dart';
import 'features/auth/vendor_login_screen.dart';
import 'features/blocked/device_mismatch_screen.dart';
import 'features/blocked/subscription_expired_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/vendor/vendor_home.dart';
import 'ui/theme/app_theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: CobrosApp()));
}

class CobrosApp extends ConsumerWidget {
  const CobrosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      final prevStatus = prev?.status;
      final nextStatus = next.status;
      if (prevStatus == nextStatus) return;

      if (nextStatus == AuthStatus.unauthenticated ||
          nextStatus == AuthStatus.subscriptionExpired ||
          nextStatus == AuthStatus.deviceMismatch) {
        rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
      }
    });

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'COBROSAPP',
      theme: AppTheme.dark(),
      navigatorKey: rootNavigatorKey,
      routes: {
        '/': (_) => const RootGate(),
        '/login': (_) => const VendorLoginScreen(),
      },
    );
  }
}

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider);

    switch (s.status) {
      case AuthStatus.unknown:
        return const SplashScreen();

      case AuthStatus.unauthenticated:
      case AuthStatus.admin: // admin sessions redirect to vendor login
        return const VendorLoginScreen();

      case AuthStatus.subscriptionExpired:
        return SubscriptionExpiredScreen(message: s.message);

      case AuthStatus.deviceMismatch:
        return DeviceMismatchScreen(message: s.message);

      case AuthStatus.vendor:
        return const VendorHome();
    }
  }
}
