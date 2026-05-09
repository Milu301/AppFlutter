import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/utils/dates.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';

class AdminReportsTab extends ConsumerStatefulWidget {
  final String adminId;
  const AdminReportsTab({super.key, required this.adminId});

  @override
  ConsumerState<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends ConsumerState<AdminReportsTab> {
  DateTime date = DateTime.now();

  bool loading = true;
  ApiError? error;

  Map<String, dynamic>? collections;
  Map<String, dynamic>? lateClients;
  Map<String, dynamic>? vendorPerformance;

  bool csvDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return {};
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic v) {
    if (v is List) {
      return v.map((e) => _asMap(e)).toList();
    }
    return const [];
  }

  num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  String _money(num? v) {
    if (v == null) return '-';
    // Simple (sin intl). Ajusta luego si quieres separadores.
    return v.toStringAsFixed(0);
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
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    final day = Dates.ymd(date);

    try {
      final api = ref.read(apiProvider);

      final c = await api.getCollectionsReport(widget.adminId, day);
      final l = await api.getLateClientsReport(widget.adminId, day);
      final v = await api.getVendorPerformanceReport(widget.adminId, day);

      // Si cualquiera viene con ok:false, muéstralo.
      final err = api.extractError(c) ?? api.extractError(l) ?? api.extractError(v);
      if (err != null) {
        setState(() {
          error = err;
          loading = false;
        });
        return;
      }

      setState(() {
        collections = c;
        lateClients = l;
        vendorPerformance = v;
        loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        error = ApiError.fromResponse(e.response?.data, status: e.response?.statusCode);
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = ApiError(code: 'INTERNAL_ERROR', message: e.toString());
        loading = false;
      });
    }
  }

  Future<void> _downloadCsv() async {
    if (csvDownloading) return;
    setState(() => csvDownloading = true);

    final day = Dates.ymd(date);

    try {
      final api = ref.read(apiProvider);
      final csv = await api.getCollectionsCsv(widget.adminId, day);

      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copiado al portapapeles ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException ? (e.response?.data?.toString() ?? e.message ?? 'Error') : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo descargar CSV: $msg')),
      );
    } finally {
      if (mounted) setState(() => csvDownloading = false);
    }
  }

  void _showRaw(String title, dynamic data) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.60,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      pretty,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: pretty));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copiado ✅')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('Copiar JSON'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = Dates.ymd(date);

    if (loading) return const LoadingView(title: 'Cargando reportes...');
    if (error != null) {
      return ErrorView(
        title: 'No se pudieron cargar los reportes',
        subtitle: '${error!.message} (${error!.code})',
        onRetry: _loadAll,
      );
    }

    final cData = _asMap(collections?['data']);
    final total = _asMap(cData['total']);
    final totalAmount = _num(total['total_amount']);
    final paymentsCount = _num(total['payments_count']);
    final byVendor = _asListOfMap(cData['by_vendor']);

    final lateList = _asListOfMap(_asMap(lateClients?['data'])['data']);
    // En backend: /late-clients devuelve {ok:true, data:[...]} (lista directa)
    final lateDirect = (lateClients?['data'] is List) ? _asListOfMap(lateClients?['data']) : const <Map<String, dynamic>>[];

    final late = lateDirect.isNotEmpty ? lateDirect : lateList;

    final vpData = _asMap(vendorPerformance?['data']);
    final vpVendors = _asListOfMap(vpData['vendors']);

    return ListView(
      children: [
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.bar_chart_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reportes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: $day',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cambiar fecha',
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              IconButton(
                tooltip: 'Refrescar',
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Resumen Cobros
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cobros del día',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: csvDownloading ? null : _downloadCsv,
                    icon: csvDownloading
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined, size: 18),
                    label: const Text('CSV'),
                  ),
                  IconButton(
                    tooltip: 'Ver JSON',
                    onPressed: () => _showRaw('Cobros (raw)', collections),
                    icon: const Icon(Icons.code),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'Total',
                      value: _money(totalAmount),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatChip(
                      label: 'Pagos',
                      value: (paymentsCount ?? 0).toString(),
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Por vendedor',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (byVendor.isEmpty)
                Text(
                  'Sin datos por vendedor.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                )
              else
                ...byVendor.map((v) {
                  final name = (v['vendor_name'] ?? v['name'] ?? 'Vendedor').toString();
                  final amount = _num(v['total_amount']);
                  final count = _num(v['payments_count']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _money(amount),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: Text('${(count ?? 0).toInt()}'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Clientes atrasados
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Clientes atrasados',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver JSON',
                    onPressed: () => _showRaw('Late clients (raw)', lateClients),
                    icon: const Icon(Icons.code),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (late.isEmpty)
                Text(
                  'Sin atrasos para esta fecha ✅',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                )
              else
                ...late.take(20).map((c) {
                  final name = (c['name'] ?? 'Cliente').toString();
                  final overdue = _num(c['overdue_amount']);
                  final inst = _num(c['overdue_installments']);
                  final phone = (c['phone'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (phone.isNotEmpty)
                                  Text(
                                    phone,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _money(overdue),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                '${(inst ?? 0).toInt()} cuotas',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (late.length > 20) ...[
                const SizedBox(height: 6),
                Text(
                  'Mostrando 20 de ${late.length}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Performance
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Performance vendedores',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ver JSON',
                    onPressed: () => _showRaw('Vendor performance (raw)', vendorPerformance),
                    icon: const Icon(Icons.code),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (vpVendors.isEmpty)
                Text(
                  'Sin datos para esta fecha.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                )
              else
                ...vpVendors.take(20).map((v) {
                  final name = (v['vendor_name'] ?? 'Vendedor').toString();
                  final pay = _num(v['payments_total']);
                  final cash = _num(v['cash_net']);
                  final visits = _num(v['visits_count']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Pagos: ${_money(pay)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Caja: ${_money(cash)}  •  Visitas: ${(visits ?? 0).toInt()}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (vpVendors.length > 20) ...[
                const SizedBox(height: 6),
                Text(
                  'Mostrando 20 de ${vpVendors.length}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 18),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
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
