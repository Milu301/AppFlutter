import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  final String adminId;
  final Map<String, dynamic> route;

  const RouteDetailScreen({super.key, required this.adminId, required this.route});

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> routeClients = [];
  List<Map<String, dynamic>> allClients = [];

  String get routeId => _pickId(widget.route);

  String _pickId(Map<String, dynamic> m) {
    final candidates = [m['id'], m['route_id'], m['routeId'], m['routeID']];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  bool _looksLikeUuid(String s) {
    final r = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return r.hasMatch(s.trim());
  }

  String _idOf(Map<String, dynamic> c) => (c['id'] ?? c['client_id'] ?? c['clientId'] ?? '').toString();
  String _nameOf(Map<String, dynamic> c) =>
      (c['name'] ?? c['client_name'] ?? c['clientName'] ?? 'Cliente').toString();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    final rid = routeId.trim();
    if (rid.isEmpty) {
      setState(() {
        loading = false;
        error = 'Ruta inválida: falta id.';
      });
      return;
    }

    final idWarning = _looksLikeUuid(rid) ? null : 'Ruta inválida. Contacta al administrador.';

    final prevRouteClients = List<Map<String, dynamic>>.from(routeClients);
    final prevAllClients = List<Map<String, dynamic>>.from(allClients);

    try {
      final api = ref.read(apiProvider);

      List<dynamic> rc = const [];
      List<dynamic> ac = const [];

      bool rcOk = false;
      bool acOk = false;

      String? rcErr;
      String? acErr;

      try {
        rc = await api.getRouteClients(rid);
        rcOk = true;
      } catch (e) {
        rcErr = _dioMsg(e);
      }

      try {
        ac = await api.getAdminClients(widget.adminId, limit: 100);
        acOk = true;
      } catch (e) {
        acErr = _dioMsg(e);
      }

      String? combined;
      final parts = <String>[];
      if (idWarning != null) parts.add(idWarning);
      if (rcErr != null) parts.add('Clientes de ruta: $rcErr');
      if (acErr != null) parts.add('Clientes (admin): $acErr');
      if (parts.isNotEmpty) combined = parts.join('\n');

      setState(() {
        routeClients = rcOk ? rc.map((e) => (e as Map).cast<String, dynamic>()).toList() : prevRouteClients;
        allClients = acOk ? ac.map((e) => (e as Map).cast<String, dynamic>()).toList() : prevAllClients;
        error = combined;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = _dioMsg(e);
        routeClients = prevRouteClients;
        allClients = prevAllClients;
        loading = false;
      });
    }
  }

  String _dioMsg(Object e) {
    if (e is DioException) {
      return (e.response?.data?.toString() ?? e.message ?? 'Error');
    }
    return e.toString();
  }

  bool _inRoute(String clientId) => routeClients.any((c) => _idOf(c) == clientId);

  Future<void> _saveSetClients() async {
    final api = ref.read(apiProvider);

    final payload = <Map<String, dynamic>>[];
    for (int i = 0; i < routeClients.length; i++) {
      payload.add({
        'client_id': _idOf(routeClients[i]),
        'visit_order': i + 1,
      });
    }

    final body = await api.setRouteClients(routeId, payload);
    final err = api.extractError(body);
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clientes guardados ✅')));
    await _loadAll();
  }

  Future<void> _saveReorder() async {
    final api = ref.read(apiProvider);

    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < routeClients.length; i++) {
      items.add({
        'client_id': _idOf(routeClients[i]),
        'visit_order': i + 1,
      });
    }

    final body = await api.reorderRouteClients(routeId, items);
    final err = api.extractError(body);
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden actualizado ✅')));
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.route['name'] ?? 'Ruta').toString();
    final hasAnyData = routeClients.isNotEmpty || allClients.isNotEmpty;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          TextButton(onPressed: _loadAll, child: const Text('Refrescar')),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const LoadingView(title: 'Cargando ruta...')
          : (!hasAnyData && error != null)
              ? ErrorView(title: 'Error', subtitle: error!, onRetry: _loadAll)
              : Column(
                  children: [
                    if (error != null) ...[
                      GlassCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline),
                            const SizedBox(width: 10),
                            Expanded(child: Text(error!)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.swap_vert),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Arrastra para reordenar. Luego "Guardar orden".',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.80)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    GlassCard(
                      child: Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: _saveSetClients, child: const Text('Guardar lista'))),
                          const SizedBox(width: 10),
                          Expanded(child: FilledButton(onPressed: _saveReorder, child: const Text('Guardar orden'))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Disponibles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: allClients.length,
                                      itemBuilder: (context, i) {
                                        final c = allClients[i];
                                        final id = _idOf(c);
                                        final cname = _nameOf(c);
                                        final disabled = _inRoute(id);

                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: OutlinedButton(
                                            onPressed: disabled
                                                ? null
                                                : () {
                                                    setState(() {
                                                      routeClients.add(c);
                                                      routeClients = List<Map<String, dynamic>>.from(routeClients);
                                                    });
                                                  },
                                            child: Align(alignment: Alignment.centerLeft, child: Text(cname)),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlassCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('En la ruta', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    child: ReorderableListView.builder(
                                      itemCount: routeClients.length,
                                      onReorder: (oldIndex, newIndex) {
                                        setState(() {
                                          if (newIndex > oldIndex) newIndex -= 1;
                                          final item = routeClients.removeAt(oldIndex);
                                          routeClients.insert(newIndex, item);
                                        });
                                      },
                                      itemBuilder: (context, i) {
                                        final c = routeClients[i];
                                        final id = _idOf(c);
                                        final cname = _nameOf(c);

                                        return ListTile(
                                          key: ValueKey('rc_$id'),
                                          title: Text(
                                            cname,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                                          ),
                                          subtitle: Text('Orden: ${i + 1}', style: Theme.of(context).textTheme.bodySmall),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              setState(() {
                                                routeClients.removeAt(i);
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
