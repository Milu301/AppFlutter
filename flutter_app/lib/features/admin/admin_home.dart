import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/lazy_indexed_stack.dart';
import '../../ui/widgets/states.dart';
import 'cash/admin_cash_tab.dart';
import 'clients/admin_clients_tab.dart';
import 'reports/admin_reports_tab.dart';
import 'routes/admin_routes_tab.dart';
import 'settings/admin_settings_tab.dart';
import 'vendors/admin_vendors_tab.dart';

class AdminHome extends ConsumerStatefulWidget {
  const AdminHome({super.key});

  @override
  ConsumerState<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends ConsumerState<AdminHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).session;
    if (session == null) {
      return const GlassScaffold(body: LoadingView());
    }

    final adminId = session.adminId;

    final builders = <WidgetBuilder>[
      (_) => AdminVendorsTab(adminId: adminId),
      (_) => AdminClientsTab(adminId: adminId),
      (_) => AdminRoutesTab(adminId: adminId),
      (_) => AdminCashTab(adminId: adminId),
      (_) => AdminReportsTab(adminId: adminId),
      (_) => const AdminSettingsTab(),
    ];

    const titles = [
      'Vendedores',
      'Clientes',
      'Rutas',
      'Caja',
      'Reportes',
      'Ajustes',
    ];

    return GlassScaffold(
      appBar: AppBar(
        title: Text('Admin • ${titles[_index]}'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LazyIndexedStack(index: _index, builders: builders),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Vendors'),
          NavigationDestination(icon: Icon(Icons.person_pin_circle_outlined), label: 'Clientes'),
          NavigationDestination(icon: Icon(Icons.route_outlined), label: 'Rutas'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Caja'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Reportes'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ajustes'),
        ],
      ),
    );
  }
}
