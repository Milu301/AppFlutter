import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/glass.dart';

class SubscriptionExpiredScreen extends ConsumerWidget {
  final String? message;
  const SubscriptionExpiredScreen({super.key, this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3), width: 2),
                    ),
                    child: const Icon(
                      Icons.lock_clock_outlined,
                      color: AppColors.warning,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Suscripción\nvencida',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message ?? 'Tu acceso ha expirado. Contacta al administrador para renovar la suscripción.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryGlassButton(
                      text: 'Volver al inicio',
                      icon: Icons.logout_rounded,
                      fullWidth: true,
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
