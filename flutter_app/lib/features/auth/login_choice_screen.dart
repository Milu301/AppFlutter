import 'package:flutter/material.dart';

import '../../ui/widgets/glass.dart';
import 'admin_login_screen.dart';
import 'vendor_login_screen.dart';

class LoginChoiceScreen extends StatelessWidget {
  const LoginChoiceScreen({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return GlassScaffold(
      // ✅ Sin AppBar para que se vea más “app pro”
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ Logo / icon serio
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet_outlined, size: 34),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'CobrosApp',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Inicia sesión para continuar',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.72)),
                ),
                const SizedBox(height: 18),

                GlassCard(
                  onTap: () => _go(context, const AdminLoginScreen()),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.admin_panel_settings_outlined),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              'Gestiona vendedores, clientes, rutas y reportes',
                              style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.55)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                GlassCard(
                  onTap: () => _go(context, const VendorLoginScreen()),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.18),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.badge_outlined),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vendedor', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              'Ruta del día, cobros y caja',
                              style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.55)),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  '© ${DateTime.now().year} CobrosApp',
                  style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
