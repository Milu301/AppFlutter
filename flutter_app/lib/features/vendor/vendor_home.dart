import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/lazy_indexed_stack.dart';
import '../../ui/widgets/states.dart';
import 'cash/vendor_cash_tab.dart';
import 'clients/vendor_clients_tab.dart';
import 'dashboard/vendor_dashboard_tab.dart';
import 'payments/vendor_payments_tab.dart';
import 'profile/vendor_profile_tab.dart';
import 'route_day/vendor_route_day_tab.dart';

class VendorHome extends ConsumerStatefulWidget {
  const VendorHome({super.key});

  @override
  ConsumerState<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends ConsumerState<VendorHome> {
  int _index = 0;

  static const _tabs = [
    _TabInfo(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _TabInfo(icon: Icons.route_rounded, label: 'Ruta'),
    _TabInfo(icon: Icons.people_rounded, label: 'Clientes'),
    _TabInfo(icon: Icons.payments_rounded, label: 'Cobros'),
    _TabInfo(icon: Icons.account_balance_wallet_rounded, label: 'Caja'),
    _TabInfo(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).session;
    if (session == null || session.vendorId == null) {
      return const GlassScaffold(body: LoadingView());
    }

    final vendorId = session.vendorId!;

    final builders = <WidgetBuilder>[
      (_) => VendorDashboardTab(vendorId: vendorId, onNavigate: (i) => setState(() => _index = i)),
      (_) => VendorRouteDayTab(vendorId: vendorId),
      (_) => VendorClientsTab(vendorId: vendorId),
      (_) => VendorPaymentsTab(vendorId: vendorId),
      (_) => VendorCashTab(vendorId: vendorId),
      (_) => VendorProfileTab(vendorId: vendorId),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PremiumBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _AppHeader(
                index: _index,
                vendorName: session.vendorName ?? session.vendorEmail?.split('@').first ?? 'Vendedor',
                onLogout: () => ref.read(authProvider.notifier).logout(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LazyIndexedStack(index: _index, builders: builders),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        tabs: _tabs,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String label;
  const _TabInfo({required this.icon, required this.label});
}

// ─────────────────────────────────────────────
// App Header
// ─────────────────────────────────────────────
class _AppHeader extends StatelessWidget {
  final int index;
  final String vendorName;
  final VoidCallback onLogout;

  static const _titles = ['Inicio', 'Mi Ruta', 'Clientes', 'Cobros', 'Mi Caja', 'Perfil'];

  const _AppHeader({
    required this.index,
    required this.vendorName,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titles[index],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Avatar + logout
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    vendorName.isNotEmpty ? vendorName[0].toUpperCase() : 'V',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: onLogout,
                padding: const EdgeInsets.all(8),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────
class _BottomNav extends ConsumerWidget {
  final int index;
  final List<_TabInfo> tabs;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdueCount = ref.watch(overdueCountProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == index;
              final showBadge = i == 3 && overdueCount > 0;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 220),
                              child: Icon(
                                tab.icon,
                                size: 22,
                                color: selected ? AppColors.primary : AppColors.textMuted,
                              ),
                            ),
                            if (showBadge)
                              Positioned(
                                top: -4,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                  child: Text(
                                    overdueCount > 9 ? '9+' : '$overdueCount',
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.primary : AppColors.textMuted,
                          letterSpacing: 0.2,
                        ),
                        child: Text(tab.label),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
