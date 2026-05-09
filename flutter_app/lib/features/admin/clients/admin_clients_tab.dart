import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/api/api_error.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';
import '../../common/client_detail_screen.dart';
import 'client_form_sheet.dart';

class AdminClientsTab extends ConsumerStatefulWidget {
  final String adminId;
  const AdminClientsTab({super.key, required this.adminId});

  @override
  ConsumerState<AdminClientsTab> createState() => _AdminClientsTabState();
}

class _AdminClientsTabState extends ConsumerState<AdminClientsTab> {
  final qCtrl = TextEditingController();
  Timer? debounce;

  String status = '';
  bool loading = true;
  ApiError? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    qCtrl.addListener(_onSearch);
    _load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    qCtrl.removeListener(_onSearch);
    qCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final list = await ref.read(apiProvider).getAdminClients(
            widget.adminId,
            q: qCtrl.text.trim().isEmpty ? null : qCtrl.text.trim(),
            status: status.isEmpty ? null : status,
          );

      setState(() {
        items = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        loading = false;
      });
    } catch (e) {
      final msg = e is DioException ? (e.response?.data?.toString() ?? e.message ?? 'Error') : e.toString();
      setState(() {
        error = ApiError(code: 'INTERNAL_ERROR', message: 'No se pudo cargar clientes: $msg');
        loading = false;
      });
    }
  }

  Future<void> _create() async {
    final payload = await showClientFormSheet(context, title: 'Crear cliente');
    if (payload == null) return;

    try {
      final api = ref.read(apiProvider);
      final body = await api.createAdminClient(widget.adminId, payload);
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente creado ✅')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? (e.response?.data?.toString() ?? 'Error') : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear: $msg')));
    }
  }

  Future<void> _edit(Map<String, dynamic> c) async {
    final payload = await showClientFormSheet(context, title: 'Editar cliente', initial: c);
    if (payload == null) return;

    final id = (c['id'] ?? '').toString();
    if (id.isEmpty) return;

    try {
      final api = ref.read(apiProvider);
      final body = await api.updateClient(id, payload);
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente actualizado ✅')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? (e.response?.data?.toString() ?? 'Error') : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $msg')));
    }
  }

  Future<void> _toggle(Map<String, dynamic> c) async {
    final id = (c['id'] ?? '').toString();
    if (id.isEmpty) return;

    final current = (c['status'] ?? 'active').toString();
    final next = current == 'active' ? 'inactive' : 'active';

    try {
      final api = ref.read(apiProvider);
      final body = await api.updateClient(id, {'status': next});
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estado: $next ✅')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo: $e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final id = (c['id'] ?? '').toString();
    if (id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: const Text('Soft delete: quedará inactivo (deleted_at). ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final api = ref.read(apiProvider);
      final body = await api.deleteClient(id);
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente eliminado ✅')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  Future<void> _openDetail(Map<String, dynamic> c) async {
    final id = (c['id'] ?? '').toString();
    if (id.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(
          title: 'Cliente',
          clientId: id,
          allowCreditCreate: true,
          allowPayments: true,
        ),
      ),
    );

    if (mounted) await _load();
  }

  Future<void> _actions(Map<String, dynamic> c) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(14),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Acciones', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Ver detalle'),
                onTap: () => Navigator.pop(context, 'detail'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.power_settings_new),
                title: const Text('Activar/Desactivar'),
                onTap: () => Navigator.pop(context, 'toggle'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Eliminar'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    if (selected == 'detail') _openDetail(c);
    if (selected == 'edit') _edit(c);
    if (selected == 'toggle') _toggle(c);
    if (selected == 'delete') _delete(c);
  }

  Widget _topBar() {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Text('Clientes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton(onPressed: _load, child: const Text('Refrescar')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _create, child: const Text('Crear')),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: qCtrl,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar cliente'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  selected: status == '',
                  label: const Text('Todos'),
                  onSelected: (_) {
                    setState(() => status = '');
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  selected: status == 'active',
                  label: const Text('Activos'),
                  onSelected: (_) {
                    setState(() => status = 'active');
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  selected: status == 'inactive',
                  label: const Text('Inactivos'),
                  onSelected: (_) {
                    setState(() => status = 'inactive');
                    _load();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _topBar(),
        const SizedBox(height: 12),
        Expanded(
          child: loading
              ? const LoadingView()
              : (error != null)
                  ? ErrorView(title: 'Error', subtitle: error!.message, onRetry: _load)
                  : (items.isEmpty)
                      ? EmptyView(title: 'Sin clientes', subtitle: 'Crea tu primer cliente.', onRetry: _load)
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final c = items[i];
                            final name = (c['name'] ?? 'Cliente').toString();
                            final st = (c['status'] ?? 'active').toString();
                            final phone = (c['phone'] ?? '').toString();

                            return InkWell(
                              onTap: () => _openDetail(c),
                              onLongPress: () => _actions(c),
                              borderRadius: BorderRadius.circular(22),
                              child: GlassCard(
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_outline),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                                          if (phone.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(phone, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70))),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: Colors.white.withValues(alpha: 0.08),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      child: Text(st),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.more_horiz, color: Colors.white.withValues(alpha: 0.65)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
