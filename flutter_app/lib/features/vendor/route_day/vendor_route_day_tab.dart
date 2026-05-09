import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/currency/currency_provider.dart';
import '../../../core/utils/dates.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';
import '../../common/client_detail_screen.dart';
import 'visit_sheet.dart';

class VendorRouteDayTab extends ConsumerStatefulWidget {
  final String vendorId;
  const VendorRouteDayTab({super.key, required this.vendorId});

  @override
  ConsumerState<VendorRouteDayTab> createState() => _VendorRouteDayTabState();
}

class _VendorRouteDayTabState extends ConsumerState<VendorRouteDayTab> {
  DateTime date = DateTime.now();

  bool loading = true;
  bool _closing = false;
  bool _dayClosed = false;
  String? error;

  Map<String, dynamic>? body;
  List<Map<String, dynamic>> clients = [];

  String? routeId;
  String? assignmentId;
  String? routeName;

  double dueToday = 0;
  double dueOverdue = 0;
  double dueTotal = 0;

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
    setState(() => date = d);
    _load();
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> b) {
    final d = b['data'];
    if (d is Map) return d.cast<String, dynamic>();
    return {};
  }

  List<Map<String, dynamic>> _extractClients(Map<String, dynamic> b) {
    final d = _extractData(b);
    final c1 = d['clients'];
    if (c1 is List) return c1.map((e) => (e as Map).cast<String, dynamic>()).toList();
    final c2 = b['clients'];
    if (c2 is List) return c2.map((e) => (e as Map).cast<String, dynamic>()).toList();
    final items = d['items'];
    if (items is List) return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return [];
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, double> _extractTotals(Map<String, dynamic> b) {
    final d = _extractData(b);
    final t0 = d['totals'] ?? b['totals'];
    if (t0 is Map) {
      final m = t0.cast<String, dynamic>();
      return {
        'due_today': _num(m['due_today'] ?? m['dueToday']),
        'due_overdue': _num(m['due_overdue'] ?? m['dueOverdue']),
        'due_total': _num(m['due_total'] ?? m['dueTotal'] ?? m['total']),
      };
    }
    return const {'due_today': 0, 'due_overdue': 0, 'due_total': 0};
  }

  String _clientId(Map<String, dynamic> c) =>
      (c['client_id'] ?? c['clientId'] ?? c['id'] ?? '').toString();

  String _clientName(Map<String, dynamic> c) =>
      (c['name'] ?? c['client_name'] ?? c['clientName'] ?? 'Cliente').toString();

  bool _isVisited(Map<String, dynamic> c) {
    final v = c['visited'] ?? c['is_visited'];
    if (v is bool) return v;
    final st = (c['visit_status'] ?? c['status'] ?? '').toString().toLowerCase();
    return st.contains('visited') || st.contains('done') || st.contains('ok');
  }

  double _dueToday(Map<String, dynamic> c) => _num(c['due_today'] ?? c['dueToday']);
  double _dueOverdue(Map<String, dynamic> c) => _num(c['due_overdue'] ?? c['dueOverdue']);
  double _dueTotal(Map<String, dynamic> c) =>
      _num(c['due_total'] ?? c['dueTotal'] ?? c['total']);
  String _nextDue(Map<String, dynamic> c) =>
      (c['next_due_date'] ?? c['nextDueDate'] ?? '').toString();

  int _remainingInstallments(Map<String, dynamic> c) {
    final direct = c['remaining_installments'] ?? c['remainingInstallments'];
    final d = int.tryParse(direct?.toString() ?? '');
    if (d != null) return d;
    final dueItems = c['due_items'] ?? c['dueItems'];
    if (dueItems is List) {
      int maxR = 0;
      for (final it in dueItems) {
        if (it is Map) {
          final r = int.tryParse(
                  '${it['remaining_installments'] ?? it['remainingInstallments'] ?? 0}') ??
              0;
          if (r > maxR) maxR = r;
        }
      }
      return maxR;
    }
    return 0;
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    final day = Dates.ymd(date);

    try {
      final api = ref.read(apiProvider);
      final res = await api.getVendorRouteDay(widget.vendorId, day);

      final data = _extractData(res);

      String? rid;
      String? aid;
      String? rname;

      final route = data['route'];
      if (route is Map) {
        final rm = route.cast<String, dynamic>();
        rid = (rm['id'] ?? rm['route_id'] ?? '').toString();
        rname = (rm['name'] ?? rm['route_name'] ?? '').toString();
      }

      rid ??= (data['route_id'] ?? data['routeId'] ?? '').toString();

      final ass = data['assignment'] ?? data['route_assignment'];
      if (ass is Map) {
        final am = ass.cast<String, dynamic>();
        aid = (am['id'] ?? am['assignment_id'] ?? am['route_assignment_id'] ?? '').toString();
        rname ??= (am['route_name'] ?? am['routeName'] ?? am['name'] ?? '').toString();
      }

      aid ??= (data['route_assignment_id'] ?? data['assignment_id'] ?? data['routeAssignmentId'] ?? '').toString();
      rname ??= (data['route_name'] ?? data['name'] ?? '').toString();

      final totals = _extractTotals(res);

      setState(() {
        body = res;
        clients = _extractClients(res);
        routeId = rid?.isEmpty == true ? null : rid;
        assignmentId = aid?.isEmpty == true ? null : aid;
        routeName = rname?.isEmpty == true ? null : rname;
        dueToday = totals['due_today'] ?? 0;
        dueOverdue = totals['due_overdue'] ?? 0;
        dueTotal = totals['due_total'] ?? 0;
        loading = false;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        final data = e.response?.data;
        String code = '';
        String msg = '';
        if (data is Map) {
          final err = data['error'];
          if (err is Map) {
            code = (err['code'] ?? '').toString();
            msg = (err['message'] ?? '').toString();
          }
        } else if (data is String) {
          msg = data;
        }

        if (code == 'NOT_FOUND' || msg.toLowerCase().contains('ruta no encontrada')) {
          setState(() {
            body = null;
            clients = [];
            routeId = null;
            assignmentId = null;
            routeName = null;
            dueToday = 0;
            dueOverdue = 0;
            dueTotal = 0;
            error = null;
            loading = false;
          });
          return;
        }
      }

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

  Future<void> _closeDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Cerrar caja del día',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Los clientes que no pagaron pasarán automáticamente a estado "sin pago".\n\nNo se podrán registrar más movimientos hoy. ¿Confirmar cierre?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar día'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _closing = true);
    try {
      final api = ref.read(apiProvider);
      final day = Dates.ymd(date);
      final body = await api.closeRouteDay(widget.vendorId, day);
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${err.message}')),
        );
        setState(() => _closing = false);
        return;
      }
      setState(() {
        _dayClosed = true;
        _closing = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Día cerrado. Clientes sin pago marcados.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?.toString() ?? 'Error')
          : e.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo cerrar: $msg')));
      setState(() => _closing = false);
    }
  }

  Future<void> _openClient(String clientId, String name) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientDetailScreen(
          title: name,
          clientId: clientId,
          allowCreditCreate: true,
          allowPayments: true,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _visit(Map<String, dynamic> c) async {
    final id = _clientId(c);
    if (id.isEmpty) return;

    final res = await showVisitSheet(context, initialVisited: _isVisited(c));
    if (res == null) return;

    final payload = <String, dynamic>{
      'vendor_id': widget.vendorId,
      'client_id': id,
      'assigned_date': Dates.ymd(date),
      ...res,
    };
    if (routeId != null && routeId!.isNotEmpty) payload['route_id'] = routeId;
    if (assignmentId != null && assignmentId!.isNotEmpty) {
      payload['route_assignment_id'] = assignmentId;
    }

    try {
      final api = ref.read(apiProvider);
      final body = await api.createRouteVisit(payload);
      final err = api.extractError(body);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Visita registrada')));
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
    if (loading) return const LoadingView(title: 'Cargando ruta...');
    if (error != null) return ErrorView(title: 'Error', subtitle: error!, onRetry: _load);

    final currency = ref.watch(currencyProvider);
    const headerName = 'Cobros del día';
    final visited = clients.where(_isVisited).length;
    final total = clients.length;
    final progress = total > 0 ? visited / total : 0.0;
    final showTotals = dueToday != 0 || dueOverdue != 0 || dueTotal != 0;
    final isToday = Dates.ymd(date) == Dates.ymd(DateTime.now());

    return Column(
      children: [
        const SizedBox(height: 8),
        // ─── Header card ───
        GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.route_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          headerName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isToday ? 'Hoy — $total clientes' : '${Dates.ymd(date)} — $total clientes',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                    tooltip: 'Cambiar fecha',
                  ),
                  const SizedBox(width: 6),
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: _load,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),

              if (total > 0) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                      progress == 1.0 ? AppColors.success : AppColors.primary,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$visited de $total visitados',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: progress == 1.0 ? AppColors.success : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (isToday) ...[
                  const SizedBox(height: 10),
                  _dayClosed
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
                              SizedBox(width: 6),
                              Text(
                                'DÍA CERRADO — sin movimientos hasta mañana',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _closing ? null : _closeDay,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error.withValues(alpha: 0.85),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: _closing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.lock_clock_rounded, size: 16),
                            label: Text(_closing ? 'Cerrando...' : 'Cerrar caja del día'),
                          ),
                        ),
                ],
              ],

              if (showTotals) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _TotalChip(label: 'Hoy', amount: dueToday, color: AppColors.success, currency: currency),
                    const SizedBox(width: 8),
                    _TotalChip(label: 'Vencido', amount: dueOverdue, color: AppColors.error, currency: currency),
                    const SizedBox(width: 8),
                    _TotalChip(label: 'Total', amount: dueTotal, color: AppColors.info, currency: currency),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── Client list ───
        Expanded(
          child: clients.isEmpty
              ? const EmptyView(
                  title: 'Sin cobros para hoy',
                  subtitle: 'No hay cuotas por cobrar en esta fecha.',
                )
              : ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    return _ClientCard(
                      client: c,
                      onTap: () {
                        final id = _clientId(c);
                        if (id.isEmpty) return;
                        _openClient(id, _clientName(c));
                      },
                      onVisit: () => _visit(c),
                      isVisited: _isVisited(c),
                      name: _clientName(c),
                      dueToday: _dueToday(c),
                      dueOverdue: _dueOverdue(c),
                      dueTotal: _dueTotal(c),
                      nextDue: _nextDue(c),
                      remaining: _remainingInstallments(c),
                      currency: currency,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Client Card
// ─────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;
  final VoidCallback onVisit;
  final bool isVisited;
  final String name;
  final double dueToday;
  final double dueOverdue;
  final double dueTotal;
  final String nextDue;
  final int remaining;
  final CurrencyConfig currency;

  const _ClientCard({
    required this.client,
    required this.onTap,
    required this.onVisit,
    required this.isVisited,
    required this.name,
    required this.dueToday,
    required this.dueOverdue,
    required this.dueTotal,
    required this.nextDue,
    required this.remaining,
    required this.currency,
  });

  bool get _hasMoneyInfo =>
      dueToday != 0 || dueOverdue != 0 || dueTotal != 0 || remaining > 0 || nextDue.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with visited status
          Stack(
            children: [
              ClientAvatar(name: name, size: 44),
              if (isVisited)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceCard, width: 2),
                    ),
                    child: const Icon(Icons.check, size: 9, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (dueOverdue > 0)
                      const StatusBadge(label: 'VENCIDO', color: AppColors.error),
                    if (dueOverdue == 0 && dueToday > 0)
                      const StatusBadge(label: 'COBRAR HOY', color: AppColors.success),
                  ],
                ),

                const SizedBox(height: 4),
                Text(
                  isVisited ? 'Visitado' : 'Pendiente de visita',
                  style: TextStyle(
                    color: isVisited ? AppColors.success : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (_hasMoneyInfo) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (dueToday > 0)
                        _MoneyChip(
                            label: 'Hoy',
                            value: currency.fmt(dueToday),
                            color: AppColors.success),
                      if (dueOverdue > 0)
                        _MoneyChip(
                            label: 'Vencido',
                            value: currency.fmt(dueOverdue),
                            color: AppColors.error),
                      if (remaining > 0)
                        _MoneyChip(
                            label: 'Cuotas',
                            value: '$remaining',
                            color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Visit button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onVisit,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isVisited
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.surfaceBright,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isVisited
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Icon(
                isVisited ? Icons.check_circle_rounded : Icons.edit_calendar_rounded,
                size: 18,
                color: isVisited ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MoneyChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final CurrencyConfig currency;
  const _TotalChip({required this.label, required this.amount, required this.color, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currency.fmt(amount),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ],
        ),
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
