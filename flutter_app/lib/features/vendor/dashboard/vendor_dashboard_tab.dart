import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/utils/dates.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/glass.dart';
import '../../common/cash_movement_sheet.dart';

class VendorDashboardTab extends ConsumerStatefulWidget {
  final String vendorId;
  final void Function(int index)? onNavigate;
  const VendorDashboardTab({super.key, required this.vendorId, this.onNavigate});

  @override
  ConsumerState<VendorDashboardTab> createState() => _VendorDashboardTabState();
}

class _VendorDashboardTabState extends ConsumerState<VendorDashboardTab> {
  bool _loading = true;

  // Route day
  int _totalClients = 0;
  int _visitedClients = 0;

  // Stats from /stats endpoint
  int _activeClients = 0;
  int _activeCredits = 0;
  int _lateCredits = 0;
  double _totalPortfolio = 0;
  int _overdueCount = 0;
  double _overdueAmount = 0;
  double _todayCollections = 0;

  // Cash
  double _income = 0;
  double _expense = 0;

  final _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  int _int(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    setState(() => _loading = true);
    final day = Dates.ymd(_today);
    final api = ref.read(apiProvider);

    try {
      final results = await Future.wait([
        api.getVendorRouteDay(widget.vendorId, day).catchError((_) => <String, dynamic>{}),
        api.getVendorCashSummary(widget.vendorId, day).catchError((_) => <String, dynamic>{}),
        api.getVendorStats(widget.vendorId).catchError((_) => <String, dynamic>{}),
      ]);

      final routeBody = results[0];
      final cashBody = results[1];
      final statsBody = results[2];

      final clients = _extractList(routeBody);
      int visited = 0;
      for (final c in clients) {
        final v = c['visited'] ?? c['is_visited'];
        if (v == true) visited++;
      }

      final cashData = _unwrap(cashBody);
      final income = _num(cashData['income'] ?? cashData['in'] ?? 0);
      final expense = _num(cashData['expense'] ?? cashData['out'] ?? 0);

      final sd = statsBody['data'] is Map
          ? (statsBody['data'] as Map).cast<String, dynamic>()
          : statsBody;

      final clientsMap = sd['clients'] is Map ? (sd['clients'] as Map) : <String, dynamic>{};
      final creditsMap = sd['credits'] is Map ? (sd['credits'] as Map) : <String, dynamic>{};
      final overdueMap = sd['overdue'] is Map ? (sd['overdue'] as Map) : <String, dynamic>{};

      final newOverdue = _int(overdueMap['count']);
      if (mounted) {
        setState(() {
          _totalClients = clients.length;
          _visitedClients = visited.clamp(0, clients.length);
          _income = income;
          _expense = expense;
          _activeClients = _int(clientsMap['active']);
          _activeCredits = _int(creditsMap['active']);
          _lateCredits = _int(creditsMap['late']);
          _totalPortfolio = _num(creditsMap['total_portfolio']);
          _overdueCount = newOverdue;
          _overdueAmount = _num(overdueMap['amount']);
          _todayCollections = _num(sd['today_collections']);
          _loading = false;
        });
        ref.read(overdueCountProvider.notifier).state = newOverdue;
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> b) {
    final d = b['data'];
    if (d is Map) return d.cast<String, dynamic>();
    return b;
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> b) {
    final d = _unwrap(b);
    final c1 = d['clients'];
    if (c1 is List) return c1.map((e) => (e as Map).cast<String, dynamic>()).toList();
    final c2 = b['clients'];
    if (c2 is List) return c2.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return [];
  }

  Future<void> _quickCash() async {
    final res = await showCashMovementSheet(context, title: 'Registrar movimiento');
    if (res == null) return;
    try {
      final api = ref.read(apiProvider);
      await api.createVendorCashMovement(widget.vendorId, res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimiento registrado')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DioException ? (e.response?.data?.toString() ?? 'Error') : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currencyProvider);
    final session = ref.watch(authProvider).session;
    final name = session?.vendorName ?? session?.vendorEmail?.split('@').first ?? 'Vendedor';
    final progress = _totalClients > 0 ? _visitedClients / _totalClients : 0.0;
    final net = _income - _expense;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceCard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 4),
          _buildWelcomeCard(name),
          const SizedBox(height: 16),

          if (_overdueCount > 0) ...[
            _buildAlertBanner(),
            const SizedBox(height: 14),
          ],

          _buildPortfolioCard(),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Cobrado hoy',
                  value: _fmt(_todayCollections),
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Balance caja',
                  value: _fmt(net),
                  icon: Icons.account_balance_wallet_rounded,
                  color: net >= 0 ? AppColors.info : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Clientes activos',
                  value: '$_activeClients',
                  icon: Icons.people_rounded,
                  color: AppColors.primary,
                  isMoney: false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Créditos activos',
                  value: '$_activeCredits',
                  icon: Icons.credit_card_rounded,
                  color: AppColors.secondary,
                  isMoney: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildRouteProgress(progress),
          const SizedBox(height: 16),

          _buildQuickActions(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _fmt(double v) => ref.read(currencyProvider).fmtCompact(v);

  String get _greeting {
    final h = _today.hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _greetingEmoji {
    final h = _today.hour;
    if (h < 12) return '🌅';
    if (h < 18) return '☀️';
    return '🌙';
  }

  String _formatDate(DateTime d) {
    const months = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    const days = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];
    return '${days[d.weekday % 7]}, ${d.day} de ${months[d.month - 1]}';
  }

  Widget _buildWelcomeCard(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1F7A), Color(0xFF1B1650), Color(0xFF0F1630)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _greetingEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_greeting,',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _formatDate(_today),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _load,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: _loading
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                  : const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_overdueCount ${_overdueCount == 1 ? 'crédito vencido' : 'créditos vencidos'}',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Pendiente: ${_fmt(_overdueAmount)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => widget.onNavigate?.call(2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Text('Ver', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cartera total activa',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              if (_lateCredits > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    '$_lateCredits en mora',
                    style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _fmt(_totalPortfolio),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$_activeCredits créditos activos',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteProgress(double progress) {
    final allVisited = _totalClients > 0 && _visitedClients >= _totalClients;
    final progressColor = allVisited
        ? AppColors.success
        : progress > 0
            ? AppColors.primary
            : AppColors.textMuted;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  allVisited ? Icons.check_circle_rounded : Icons.route_rounded,
                  color: progressColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cobros del día',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    Text(
                      _totalClients == 0
                          ? 'Sin cobros pendientes hoy'
                          : '$_visitedClients de $_totalClients visitados',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => widget.onNavigate?.call(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Text('Ver', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (_totalClients > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% completado',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                ),
                if (allVisited)
                  const Text(
                    '¡Listo! ✓',
                    style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Acciones rápidas'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _QuickAction(icon: Icons.add_card_rounded, label: 'Cobro', color: AppColors.success, onTap: () => widget.onNavigate?.call(3))),
            const SizedBox(width: 10),
            Expanded(child: _QuickAction(icon: Icons.person_add_rounded, label: 'Cliente', color: AppColors.info, onTap: () => widget.onNavigate?.call(2))),
            const SizedBox(width: 10),
            Expanded(child: _QuickAction(icon: Icons.attach_money_rounded, label: 'Caja', color: AppColors.warning, onTap: _quickCash)),
            const SizedBox(width: 10),
            Expanded(child: _QuickAction(icon: Icons.route_rounded, label: 'Ruta', color: AppColors.primary, onTap: () => widget.onNavigate?.call(1))),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isMoney;
  const _StatTile({required this.label, required this.value, required this.icon, required this.color, this.isMoney = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
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

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _pressed ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.color.withValues(alpha: _pressed ? 0.4 : 0.22)),
            boxShadow: _pressed ? [] : [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: widget.color, size: 22),
              const SizedBox(height: 5),
              Text(widget.label, style: TextStyle(color: widget.color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}
