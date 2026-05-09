import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/api/api_error.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';
import '../../admin/clients/client_form_sheet.dart';
import '../../common/client_detail_screen.dart';

class VendorClientsTab extends ConsumerStatefulWidget {
  final String vendorId;
  const VendorClientsTab({super.key, required this.vendorId});

  @override
  ConsumerState<VendorClientsTab> createState() => _VendorClientsTabState();
}

class _VendorClientsTabState extends ConsumerState<VendorClientsTab> {
  final _qCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  bool _loading = true;
  ApiError? _error;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all'; // 'all' | 'active' | 'inactive'

  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(_onSearch);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtrl.removeListener(_onSearch);
    _qCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await ref.read(apiProvider).getVendorClients(
            widget.vendorId,
            q: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
            limit: 100,
            offset: 0,
          );

      setState(() {
        _items = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      final msg = e is DioException
          ? (e.response?.data?.toString() ?? e.message ?? 'Error')
          : e.toString();
      setState(() {
        _error = ApiError(code: 'INTERNAL_ERROR', message: 'No se pudo cargar clientes: $msg');
        _loading = false;
      });
    }
  }

  Future<void> _createClient() async {
    final payload = await showClientFormSheet(context, title: 'Nuevo cliente');
    if (payload == null) return;

    try {
      final api = ref.read(apiProvider);
      final body = await api.createVendorClient(widget.vendorId, payload);
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cliente creado exitosamente')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? (e.response?.data?.toString() ?? 'Error') : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear: $msg')));
    }
  }

  Future<void> _open(Map<String, dynamic> c) async {
    final id = (c['id'] ?? c['client_id'] ?? c['clientId'] ?? '').toString();
    final name = (c['name'] ?? c['client_name'] ?? 'Cliente').toString();
    if (id.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(
          title: name,
          clientId: id,
          allowCreditCreate: true,
          allowPayments: true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((c) {
      final s = (c['status'] ?? 'active').toString();
      return s == _filter;
    }).toList();
  }

  int get _activeCount => _items.where((c) => (c['status'] ?? 'active') == 'active').length;
  int get _inactiveCount => _items.where((c) => (c['status'] ?? 'active') == 'inactive').length;

  @override
  Widget build(BuildContext context) {
    final displayed = _filtered;

    return Column(
      children: [
        const SizedBox(height: 8),

        // ─── Search + Add ───
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _qCtrl,
                  focusNode: _searchFocus,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                    hintText: 'Buscar por nombre, teléfono...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    filled: false,
                    suffixIcon: _qCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textMuted),
                            onPressed: () {
                              _qCtrl.clear();
                              _load();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _createClient,
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ─── Filter chips ───
        if (!_loading && _error == null && _items.isNotEmpty)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(label: 'Todos (${_items.length})', value: 'all', current: _filter, onSelect: (v) => setState(() => _filter = v)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Activos (${ _activeCount})', value: 'active', current: _filter, onSelect: (v) => setState(() => _filter = v)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Inactivos ($_inactiveCount)', value: 'inactive', current: _filter, onSelect: (v) => setState(() => _filter = v)),
              ],
            ),
          ),

        if (!_loading && _error == null && _items.isNotEmpty) const SizedBox(height: 10),

        // ─── List ───
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(title: 'Error', subtitle: _error!.message, onRetry: _load)
                  : displayed.isEmpty
                      ? EmptyView(
                          title: _qCtrl.text.isEmpty ? 'Sin clientes' : 'Sin resultados',
                          subtitle: _qCtrl.text.isEmpty
                              ? 'Agrega tu primer cliente con el botón +'
                              : 'Intenta con otro nombre o teléfono',
                          onRetry: _qCtrl.text.isEmpty ? _load : null,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceCard,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: displayed.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final c = displayed[i];
                              return _ClientTile(client: c, onTap: () => _open(c));
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onSelect;
  const _FilterChip({required this.label, required this.value, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;

  const _ClientTile({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (client['name'] ?? client['client_name'] ?? 'Cliente').toString();
    final phone = (client['phone'] ?? '').toString();
    final docId = (client['doc_id'] ?? '').toString();
    final address = (client['address'] ?? '').toString();
    final status = (client['status'] ?? 'active').toString();
    final isActive = status == 'active';

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Stack(
            children: [
              ClientAvatar(name: name, size: 44),
              if (!isActive)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceCard, width: 2),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceCard, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      const Icon(Icons.phone_rounded, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 10),
                    ],
                    if (docId.isNotEmpty && phone.isEmpty) ...[
                      const Icon(Icons.badge_rounded, size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(docId, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(width: 10),
                    ],
                    if (address.isNotEmpty)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 11, color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted.withValues(alpha: 0.6),
            size: 18,
          ),
        ],
      ),
    );
  }
}
