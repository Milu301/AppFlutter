import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/states.dart';
import 'credit_form_sheet.dart';
import 'payment_form_sheet.dart';
import 'receipt_sheet.dart';

// Por defecto NO mostramos la respuesta cruda del API.
// Si quieres verla para debug: ejecuta con --dart-define=SHOW_CLIENT_DEBUG=true

class ClientDetailScreen extends ConsumerStatefulWidget {
  final String title;
  final String clientId;
  final bool allowCreditCreate;
  final bool allowPayments;

  const ClientDetailScreen({
    super.key,
    required this.title,
    required this.clientId,
    this.allowCreditCreate = true,
    this.allowPayments = true,
  });

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> client = {};
  List<Map<String, dynamic>> credits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return {};
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic v) {
    if (v is List) return v.map((e) => _asMap(e)).toList();
    return [];
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await ref.read(apiProvider).getClient(widget.clientId);

      final api = ref.read(apiProvider);
      final err = api.extractError(res);
      if (err != null) {
        setState(() {
          error = '${err.message} (${err.code})';
          loading = false;
        });
        return;
      }

      final data = _asMap(res['data']);

      // Client map
      final c = data['client'];
      final clientMap = c is Map ? c.cast<String, dynamic>() : data;

      // Credits list
      List<Map<String, dynamic>> creds = [];
      if (data['credits'] is List) {
        creds = _asListOfMap(data['credits']);
      } else if (clientMap['credits'] is List) {
        creds = _asListOfMap(clientMap['credits']);
      }

      setState(() {
        client = clientMap;
        credits = creds;
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

  String _clientName() {
    final n = (client['name'] ?? client['client_name'] ?? '').toString();
    return n.isEmpty ? widget.title : n;
  }

  String _creditId(Map<String, dynamic> c) => (c['id'] ?? c['credit_id'] ?? c['creditId'] ?? '').toString();

  num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  String _pickStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) {
        final s = m[k].toString();
        if (s.trim().isNotEmpty) return s;
      }
    }
    return '';
  }

  num? _pickNum(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final n = _num(m[k]);
        if (n != null) return n;
      }
    }
    return null;
  }

  Future<void> _createCredit() async {
    final internal = await showCreditFormSheet(context, title: 'Crear crédito');
    if (internal == null) return;

    final payload = internal;

    try {
      final api = ref.read(apiProvider);
      final res = await api.createCredit(widget.clientId, payload);
      final err = api.extractError(res);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Crédito creado ✅')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? (e.response?.data?.toString() ?? 'Error') : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo crear crédito: $msg')));
    }
  }

  Future<void> _createPayment(Map<String, dynamic> credit) async {
    final creditId = _creditId(credit);
    if (creditId.isEmpty) return;

    final internal = await showPaymentFormSheet(context, title: 'Registrar pago');
    if (internal == null) return;

    final payload = <String, dynamic>{
      'amount': internal['amount'],
      'method': internal['method'],
      if (internal['notes'] != null) 'note': internal['notes'],
      'paid_at': internal['paid_at'],
    };

    try {
      final api = ref.read(apiProvider);
      final res = await api.createPayment(creditId, payload);
      final err = api.extractError(res);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
        return;
      }

      final data = _asMap(res['data']);
      final paymentData = _asMap(data['payment']);
      final creditData = _asMap(data['credit']);
      final newBalance = (creditData['balance_amount'] is num)
          ? (creditData['balance_amount'] as num).toDouble()
          : double.tryParse(creditData['balance_amount']?.toString() ?? '') ?? 0;
      final paidAmount = (paymentData['amount'] is num)
          ? (paymentData['amount'] as num).toDouble()
          : (internal['amount'] as double);
      final ccy = _pickStr(credit, const ['currency_code', 'currency', 'ccy']).toUpperCase();

      await _load();
      if (!mounted) return;

      // Extraer cuotas restantes y próximo pago del crédito actualizado
      final updatedCredit = credits.firstWhere(
        (c) => _creditId(c) == creditId,
        orElse: () => credit,
      );
      final allInst = _asListOfMap(updatedCredit['installments']);
      final pendingInst = allInst.where((i) {
        final s = (i['status'] ?? '').toString();
        return s == 'pending' || s == 'late';
      }).toList()
        ..sort((a, b) => (a['due_date'] ?? '').toString().compareTo((b['due_date'] ?? '').toString()));

      final remainingCount = pendingInst.length;
      final totalCount = allInst.length;
      final nextDue = pendingInst.isNotEmpty
          ? (pendingInst.first['due_date'] ?? '').toString()
          : '';

      await showReceiptSheet(
        context,
        clientName: _clientName(),
        clientPhone: _pickStr(client, const ['phone', 'tel', 'mobile']),
        amount: paidAmount,
        method: internal['method'] as String? ?? 'cash',
        newBalance: newBalance,
        currency: ccy,
        note: internal['notes'] as String?,
        remainingInstallments: remainingCount,
        totalInstallments: totalCount > 0 ? totalCount : null,
        nextDueDate: nextDue.isNotEmpty ? nextDue : null,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? (e.response?.data?.toString() ?? 'Error de conexión') : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo registrar pago: $msg')));
    }
  }

  Widget _clientHeader() {
    final phone = _pickStr(client, const ['phone', 'tel', 'mobile']);
    final doc = _pickStr(client, const ['doc_id', 'docId', 'document']);
    final address = _pickStr(client, const ['address', 'addr']);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_clientName(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          if (phone.isNotEmpty)
            Text('📞 $phone', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.80))),
          if (doc.isNotEmpty)
            Text('🪪 $doc', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.80))),
          if (address.isNotEmpty)
            Text('📍 $address', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.80))),
        ],
      ),
    );
  }

  Widget _creditCard(Map<String, dynamic> c, int index) {
    final id = _creditId(c);
    final status = _pickStr(c, const ['status', 'state']);
    final total = _pickNum(c, const ['total_amount', 'amount', 'principal', 'total']);
    final balance = _pickNum(c, const ['balance', 'balance_amount', 'remaining', 'remaining_amount', 'pending']);
    final createdAt = _pickStr(c, const ['created_at', 'start_date', 'starts_at']);
    final ccy = _pickStr(c, const ['currency_code', 'currency', 'ccy']).toUpperCase();
    final installments = _asListOfMap(c['installments']);

    final isClosed = status.toLowerCase().contains('closed') || status.toLowerCase().contains('paid');
    final suf = ccy.isEmpty ? '' : ' $ccy';

    final pending = installments.where((i) {
      final s = (i['status'] ?? '').toString();
      return s == 'pending' || s == 'late';
    }).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Crédito #$index',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _kv('Total', (total == null) ? '-' : '${total.toStringAsFixed(2)}$suf')),
              const SizedBox(width: 10),
              Expanded(child: _kv('Saldo', (balance == null) ? '-' : '${balance.toStringAsFixed(2)}$suf')),
            ],
          ),
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Inicio: $createdAt', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.60))),
          ],
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InstallmentsSection(installments: pending, ccy: suf),
          ],
          const SizedBox(height: 10),
          if (widget.allowPayments)
            FilledButton.icon(
              onPressed: (id.isEmpty || isClosed) ? null : () => _createPayment(c),
              icon: const Icon(Icons.payments_outlined),
              label: Text(isClosed ? 'Crédito cerrado' : 'Registrar pago'),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70))),
          const SizedBox(height: 4),
          Text(v, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _emptyCreditsCard() {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.credit_card_off_outlined, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aún no hay créditos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.allowCreditCreate
                      ? 'Toca “Crear” para registrar el primer crédito de este cliente.'
                      : 'Este cliente no tiene créditos registrados.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: AppBar(
        title: Text(_clientName()),
        actions: [
          TextButton(onPressed: _load, child: const Text('Refrescar')),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const LoadingView(title: 'Cargando cliente...')
          : (error != null)
              ? ErrorView(title: 'Error', subtitle: error!, onRetry: _load)
              : ListView(
                  children: [
                    _clientHeader(),
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Row(
                        children: [
                          Text('Créditos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const Spacer(),
                          if (widget.allowCreditCreate)
                            FilledButton.icon(
                              onPressed: _createCredit,
                              icon: const Icon(Icons.add),
                              label: const Text('Crear'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (credits.isEmpty)
                      _emptyCreditsCard()
                    else
                      ...credits.indexed.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _creditCard(e.$2, e.$1 + 1))),
                    const SizedBox(height: 12),
                    const SizedBox(height: 18),
                  ],
                ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = const Color(0xFF4CAF50);
        break;
      case 'paid':
        color = const Color(0xFF2196F3);
        break;
      case 'late':
        color = const Color(0xFFFF5722);
        break;
      case 'cancelled':
        color = const Color(0xFF9E9E9E);
        break;
      default:
        color = Colors.white;
    }
    final label = switch (status.toLowerCase()) {
      'active' => 'Activo',
      'paid' => 'Pagado',
      'late' => 'Atrasado',
      'cancelled' => 'Cancelado',
      _ => status.isEmpty ? '-' : status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _InstallmentsSection extends StatefulWidget {
  final List<Map<String, dynamic>> installments;
  final String ccy;
  const _InstallmentsSection({required this.installments, required this.ccy});

  @override
  State<_InstallmentsSection> createState() => _InstallmentsSectionState();
}

class _InstallmentsSectionState extends State<_InstallmentsSection> {
  bool _expanded = false;

  Color _statusColor(String s) {
    switch (s) {
      case 'late':
        return const Color(0xFFFF5722);
      case 'pending':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _statusLabel(String s) => switch (s) {
        'late' => 'Atrasada',
        'pending' => 'Pendiente',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    final count = widget.installments.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFFF5722)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$count cuota${count == 1 ? '' : 's'} pendiente${count == 1 ? '' : 's'}',
                    style: const TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: const Color(0xFFFF5722)),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          ...widget.installments.map((inst) {
            final instNum = inst['installment_number'] ?? '-';
            final due = (inst['due_date'] ?? '').toString();
            final amtDue = (inst['amount_due'] is num)
                ? (inst['amount_due'] as num).toStringAsFixed(2)
                : (inst['amount_due']?.toString() ?? '0');
            final amtPaid = (inst['amount_paid'] is num)
                ? (inst['amount_paid'] as num).toStringAsFixed(2)
                : (inst['amount_paid']?.toString() ?? '0');
            final s = (inst['status'] ?? '').toString();
            final color = _statusColor(s);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Center(child: Text('$instNum', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vence: $due', style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0))),
                        Text('Pagado: $amtPaid${widget.ccy} / $amtDue${widget.ccy}',
                            style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: color.withValues(alpha: 0.15),
                    ),
                    child: Text(_statusLabel(s), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

