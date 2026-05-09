import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/utils/dates.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';
import '../../common/cash_movement_sheet.dart';

class AdminCashTab extends ConsumerStatefulWidget {
  final String adminId;
  const AdminCashTab({super.key, required this.adminId});

  @override
  ConsumerState<AdminCashTab> createState() => _AdminCashTabState();
}

class _AdminCashTabState extends ConsumerState<AdminCashTab> {
  DateTime date = DateTime.now();

  bool loading = true;
  String? error;

  Map<String, dynamic>? summaryBody;
  List<Map<String, dynamic>> movements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() => date = d);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    final day = Dates.ymd(date);

    try {
      final api = ref.read(apiProvider);
      final s = await api.getAdminCashSummary(widget.adminId, day);
      final m = await api.getAdminCash(widget.adminId, day, limit: 100);

      setState(() {
        summaryBody = s;
        movements = m.map((e) => (e as Map).cast<String, dynamic>()).toList();
        loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        error = e.response?.data?.toString() ?? e.message ?? 'Error';
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  Map<String, dynamic> _summaryData() {
    final b = summaryBody ?? {};
    final data = b['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return {};
  }

  num? _pickAny(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final n = _num(m[k]);
        if (n != null) return n;
      }
    }
    return null;
  }

  Future<void> _addMovement() async {
    final payload = await showCashMovementSheet(context, title: 'Nuevo movimiento (Admin)');
    if (payload == null) return;

    try {
      final api = ref.read(apiProvider);
      final body = await api.createAdminCashMovement(widget.adminId, payload);
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimiento guardado ✅')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? (e.response?.data?.toString() ?? 'Error') : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo: $msg')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = Dates.ymd(date);

    if (loading) {
      return const LoadingView(title: 'Cargando caja...');
    }

    if (error != null) {
      return ErrorView(title: 'Error', subtitle: error!, onRetry: _load);
    }

    final summary = _summaryData();
    final totalIn = _pickAny(summary, const ['total_in', 'in_total', 'income_total', 'in', 'income']);
    final totalOut = _pickAny(summary, const ['total_out', 'out_total', 'expense_total', 'out', 'expense']);
    final balance = _pickAny(summary, const ['balance', 'net', 'total', 'cash']);

    return ListView(
      children: [
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Caja • $day',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(onPressed: _pickDate, child: const Text('Fecha')),
              const SizedBox(width: 6),
              TextButton(onPressed: _load, child: const Text('Refrescar')),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Ingresos',
                  value: totalIn?.toStringAsFixed(2) ?? '-',
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Egresos',
                  value: totalOut?.toStringAsFixed(2) ?? '-',
                  icon: Icons.trending_down,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Balance',
                  value: balance?.toStringAsFixed(2) ?? '-',
                  icon: Icons.ssid_chart,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Row(
            children: [
              Text('Movimientos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addMovement,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (movements.isEmpty)
          const EmptyView(title: 'Sin movimientos', subtitle: 'Aún no hay movimientos en esta fecha.')
        else
          ...movements.map((m) {
            final type = (m['type'] ?? m['direction'] ?? m['kind'] ?? '').toString();
            final amount = m['amount'] ?? m['value'];
            final desc = (m['description'] ?? m['note'] ?? '').toString();
            final at = (m['occurred_at'] ?? m['created_at'] ?? m['at'] ?? '').toString();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                child: Row(
                  children: [
                    Icon(type.contains('out') ? Icons.remove_circle_outline : Icons.add_circle_outline),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monto: $amount', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70))),
                          ],
                          if (at.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(at, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.45))),
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
                      child: Text(type.isEmpty ? '-' : type),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70))),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
