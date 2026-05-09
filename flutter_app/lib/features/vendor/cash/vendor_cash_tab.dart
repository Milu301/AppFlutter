import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/currency/currency_provider.dart';
import '../../../core/utils/dates.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';
import '../../common/cash_movement_sheet.dart';

class VendorCashTab extends ConsumerStatefulWidget {
  final String vendorId;
  const VendorCashTab({super.key, required this.vendorId});

  @override
  ConsumerState<VendorCashTab> createState() => _VendorCashTabState();
}

class _VendorCashTabState extends ConsumerState<VendorCashTab> {
  DateTime _date = DateTime.now();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _movements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surfaceCard,
          ),
        ),
        child: child!,
      ),
    );
    if (d == null) return;
    setState(() => _date = d);
    _load();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asItems(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final items1 = m['items'];
      if (items1 is List) {
        return items1.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      final d = m['data'];
      if (d is List) {
        return d.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
      if (d is Map) {
        final it = d['items'];
        if (it is List) {
          return it.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _summaryMap(dynamic raw) {
    final m = _asMap(raw);
    final d = m['data'];
    if (d is Map) return d.cast<String, dynamic>();
    return m;
  }

  dynamic _pick(Map<String, dynamic>? m, List<String> keys, {dynamic fallback = 0}) {
    if (m == null) return fallback;
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) return m[k];
    }
    return fallback;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final day = Dates.ymd(_date);

    try {
      final api = ref.read(apiProvider);
      final sRaw = await api.getVendorCashSummary(widget.vendorId, day);
      final summary = _summaryMap(sRaw);
      final listRaw = await api.getVendorCash(widget.vendorId, day, limit: 100, offset: 0);
      final items = _asItems(listRaw);

      setState(() {
        _summary = summary;
        _movements = items;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?.toString() ?? e.message ?? 'Error';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addMovement() async {
    final res = await showCashMovementSheet(context, title: 'Nuevo movimiento');
    if (res == null) return;

    try {
      final api = ref.read(apiProvider);
      final body = await api.createVendorCashMovement(widget.vendorId, res);

      final err = api.extractError(_asMap(body));
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Movimiento registrado')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?.toString() ?? 'Error')
          : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo registrar: $msg')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(title: 'Cargando caja...');
    if (_error != null) return ErrorView(title: 'Error', subtitle: _error!, onRetry: _load);

    final income = _num(_pick(_summary, ['income', 'in', 'total_in', 'sum_in', 'ingresos']));
    final expense = _num(_pick(_summary, ['expense', 'out', 'total_out', 'sum_out', 'egresos']));
    final net = _num(_pick(_summary, ['net', 'balance'], fallback: income - expense));
    final isToday = Dates.ymd(_date) == Dates.ymd(DateTime.now());

    final currency = ref.watch(currencyProvider);

    return ListView(
      children: [
        const SizedBox(height: 8),

        // ─── Date header ───
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday ? 'Hoy' : Dates.ymd(_date),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${_movements.length} movimientos',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            _IconBtn(icon: Icons.calendar_today_rounded, onTap: _pickDate, tooltip: 'Cambiar fecha'),
            const SizedBox(width: 8),
            _IconBtn(icon: Icons.refresh_rounded, onTap: _load, tooltip: 'Actualizar'),
          ],
        ),
        const SizedBox(height: 16),

        // ─── Stats cards ───
        Row(
          children: [
            Expanded(
              child: _CashStatCard(
                label: 'Ingresos',
                value: income,
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
                currency: currency,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CashStatCard(
                label: 'Egresos',
                value: expense,
                icon: Icons.trending_down_rounded,
                color: AppColors.error,
                currency: currency,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ─── Balance card ───
        _BalanceCard(net: net, income: income, expense: expense, currency: currency),
        const SizedBox(height: 20),

        // ─── Movements header ───
        Row(
          children: [
            const Expanded(
              child: Text(
                'Movimientos',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            GestureDetector(
              onTap: _addMovement,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Agregar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_movements.isEmpty)
          const EmptyView(
            title: 'Sin movimientos',
            subtitle: 'Registra ingresos o egresos del día.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _movements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _MovementCard(movement: _movements[i], currency: currency),
          ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────
class _CashStatCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final CurrencyConfig currency;

  const _CashStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currency.fmt(value),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.5,
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

// ─────────────────────────────────────────────
// Balance Card
// ─────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final double net;
  final double income;
  final double expense;
  final CurrencyConfig currency;

  const _BalanceCard({required this.net, required this.income, required this.expense, required this.currency});

  @override
  Widget build(BuildContext context) {
    final isPositive = net >= 0;
    final color = isPositive ? AppColors.success : AppColors.error;
    final total = income + expense;
    final incomeRatio = total > 0 ? (income / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            AppColors.surfaceCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.account_balance_wallet_rounded : Icons.warning_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Balance del día',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              StatusBadge(
                label: isPositive ? 'POSITIVO' : 'NEGATIVO',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currency.fmt(net),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 32,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          // Visual bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.error.withValues(alpha: 0.3)),
                FractionallySizedBox(
                  widthFactor: incomeRatio,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ingresos ${income > 0 && total > 0 ? '${(incomeRatio * 100).toStringAsFixed(0)}%' : ''}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const Text(
                'Egresos',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Movement Card
// ─────────────────────────────────────────────
class _MovementCard extends StatelessWidget {
  final Map<String, dynamic> movement;
  final CurrencyConfig currency;
  const _MovementCard({required this.movement, required this.currency});

  String _type() {
    final t = (movement['movement_type'] ?? movement['type'] ??
            movement['direction'] ?? '')
        .toString();
    if (t == 'expense' || t == 'out') return 'out';
    if (t == 'income' || t == 'in') return 'in';
    return t.isEmpty ? 'in' : t;
  }

  String _at() {
    final t = movement['occurred_at'] ?? movement['created_at'] ??
        movement['timestamp'] ?? movement['createdAt'];
    final s = (t ?? '').toString();
    if (s.isEmpty) return '';
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s.length > 10 ? s.substring(0, 10) : s;
    }
  }

  double _amount() {
    final v = movement['amount'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _desc() {
    final d = movement['note'] ?? movement['description'] ?? movement['desc'] ?? movement['concept'];
    return (d ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final type = _type();
    final isOut = type == 'out';
    final color = isOut ? AppColors.error : AppColors.success;
    final icon = isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final amount = _amount();
    final desc = _desc();
    final at = _at();

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isNotEmpty ? desc : (isOut ? 'Egreso' : 'Ingreso'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (at.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(at,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isOut ? '-' : '+'}${currency.fmt(amount)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              StatusBadge(
                label: isOut ? 'Egreso' : 'Ingreso',
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _IconBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceBright,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
