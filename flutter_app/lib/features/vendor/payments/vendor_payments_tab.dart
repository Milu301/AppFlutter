import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/api/api_error.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';
import '../../common/client_detail_screen.dart';

class VendorPaymentsTab extends ConsumerStatefulWidget {
  final String vendorId;
  const VendorPaymentsTab({super.key, required this.vendorId});

  @override
  ConsumerState<VendorPaymentsTab> createState() => _VendorPaymentsTabState();
}

class _VendorPaymentsTabState extends ConsumerState<VendorPaymentsTab> {
  final _qCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  ApiError? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _qCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qCtrl.removeListener(_onSearch);
    _qCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final q = _qCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _items = [];
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await ref.read(apiProvider).getVendorClients(
            widget.vendorId,
            q: q,
            limit: 50,
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
        _error = ApiError(code: 'INTERNAL_ERROR', message: msg);
        _loading = false;
      });
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
    if (mounted) await _search();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _qCtrl.text.trim().isNotEmpty;

    return Column(
      children: [
        const SizedBox(height: 8),

        // ─── Info banner ───
        GlassCard(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1440), Color(0xFF0E1528)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registrar cobro',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Busca el cliente y accede a su crédito para registrar el pago',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Search ───
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _qCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              prefixIcon:
                  const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
              hintText: 'Buscar por nombre, teléfono o documento...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              filled: false,
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.textMuted),
                      onPressed: () {
                        _qCtrl.clear();
                        setState(() => _items = []);
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ─── Results ───
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? ErrorView(title: 'Error', subtitle: _error!.message, onRetry: _search)
                  : !hasQuery
                      ? _EmptySearch()
                      : _items.isEmpty
                          ? const EmptyView(
                              title: 'Sin resultados',
                              subtitle: 'No se encontró ningún cliente con ese término.',
                            )
                          : ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final c = _items[i];
                                return _PaymentClientTile(
                                  client: c,
                                  onTap: () => _open(c),
                                );
                              },
                            ),
        ),
      ],
    );
  }
}

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded,
                color: AppColors.primary, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Busca un cliente',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escribe el nombre, teléfono o\ndocumento del cliente para buscar',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PaymentClientTile extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;

  const _PaymentClientTile({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (client['name'] ?? client['client_name'] ?? 'Cliente').toString();
    final phone = (client['phone'] ?? '').toString();
    final address = (client['address'] ?? '').toString();

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClientAvatar(name: name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(phone,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payments_rounded, size: 14, color: AppColors.success),
                SizedBox(width: 4),
                Text(
                  'Cobrar',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
