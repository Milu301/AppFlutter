import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';


import '../../../app_providers.dart';
import '../../../core/api/api_error.dart';
import '../../../core/utils/dates.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';

class VendorLocationScreen extends ConsumerStatefulWidget {
  final String adminId;
  final String vendorId;
  final String? vendorName;

  const VendorLocationScreen({
    super.key,
    required this.adminId,
    required this.vendorId,
    this.vendorName,
  });

  @override
  ConsumerState<VendorLocationScreen> createState() => _VendorLocationScreenState();
}

class _VendorLocationScreenState extends ConsumerState<VendorLocationScreen> {
  bool loading = true;
  ApiError? error;

  Map<String, dynamic>? latestBody;
  List<Map<String, dynamic>> history = [];

  DateTime day = DateTime.now();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadAll();

    // ✅ “casi tiempo real” (última ubicación)
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _loadLatest(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return {};
  }

  Map<String, dynamic> _extractData(Map<String, dynamic>? body) {
    if (body == null) return {};
    final d = body['data'];
    if (d is Map) return d.cast<String, dynamic>();
    return body;
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;

    setState(() => day = d);
    await _loadHistory();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await _loadLatest(silent: true);
      await _loadHistory();

      setState(() => loading = false);
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

  Future<void> _loadLatest({bool silent = false}) async {
    try {
      final api = ref.read(apiProvider);
      final latest = await api.getVendorLocationLatest(widget.adminId, widget.vendorId);

      if (!mounted) return;
      setState(() {
        latestBody = latest;
        if (!silent) error = null;
      });
    } catch (_) {
      // polling silencioso
    }
  }

  Future<void> _loadHistory() async {
    try {
      final api = ref.read(apiProvider);

      // ✅ backend exige date, por eso lo mandamos siempre
      final list = await api.getVendorLocationHistory(
        widget.adminId,
        widget.vendorId,
        date: Dates.ymd(day),
        limit: 500,
        offset: 0,
      );

      if (!mounted) return;
      setState(() {
        history = list.map((e) => _asMap(e)).toList();
        error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        error = ApiError.fromResponse(e.response?.data, status: e.response?.statusCode);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = ApiError(code: 'INTERNAL_ERROR', message: e.toString());
      });
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    final can = await canLaunchUrl(url);
    if (!can) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
      return;
    }

    await launchUrl(url); // ✅ sin LaunchMode
  }

  Future<void> _copyCoords(double lat, double lng) async {
    await Clipboard.setData(ClipboardData(text: '$lat,$lng'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coordenadas copiadas ✅')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.vendorName == null || widget.vendorName!.trim().isEmpty)
        ? 'Ubicación'
        : 'Ubicación • ${widget.vendorName}';

    final latest = _extractData(latestBody);
    final latRaw = latest['lat'] ?? latest['latitude'];
    final lngRaw = latest['lng'] ?? latest['longitude'];

    final double? lat = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw?.toString() ?? '');
    final double? lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw?.toString() ?? '');

    final at = (latest['recorded_at'] ?? latest['captured_at'] ?? latest['created_at'] ?? latest['at'] ?? '').toString();

    return GlassScaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: loading
          ? const LoadingView(title: 'Cargando ubicación...')
          : (error != null)
              ? ErrorView(
                  title: 'Error',
                  subtitle: '${error!.message} (${error!.code})',
                  onRetry: _loadAll,
                )
              : ListView(
                  children: [
                    GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.date_range_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Día del historial',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          TextButton(onPressed: _pickDay, child: Text(Dates.ymd(day))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // -------------------------
                    // Última ubicación
                    // -------------------------
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.my_location_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Última ubicación (auto)',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (lat != null && lng != null) ...[
                            Text(
                              '($lat, $lng)',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _openGoogleMaps(lat, lng),
                                    icon: const Icon(Icons.map_outlined),
                                    label: const Text('Abrir en Google Maps'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  tooltip: 'Copiar coordenadas',
                                  onPressed: () => _copyCoords(lat, lng),
                                  icon: const Icon(Icons.copy),
                                ),
                              ],
                            ),
                          ] else
                            Text(
                              'Sin datos',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                            ),
                          if (at.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              at,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.history),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Historial (${history.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (history.isEmpty)
                      const EmptyView(
                        title: 'Sin historial',
                        subtitle: 'No hay ubicaciones para ese día.',
                      )
                    else
                      ...history.map((h) {
                        final latRaw2 = h['lat'] ?? h['latitude'];
                        final lngRaw2 = h['lng'] ?? h['longitude'];

                        final double? lat2 = latRaw2 is num ? latRaw2.toDouble() : double.tryParse(latRaw2?.toString() ?? '');
                        final double? lng2 = lngRaw2 is num ? lngRaw2.toDouble() : double.tryParse(lngRaw2?.toString() ?? '');

                        final at2 = (h['recorded_at'] ?? h['captured_at'] ?? h['created_at'] ?? h['at'] ?? '').toString();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_outlined),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (lat2 != null && lng2 != null) ? '($lat2, $lng2)' : '(sin coords)',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        at2,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
                                      ),
                                      if (lat2 != null && lng2 != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _openGoogleMaps(lat2, lng2),
                                              icon: const Icon(Icons.map_outlined),
                                              label: const Text('Maps'),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () => _copyCoords(lat2, lng2),
                                              icon: const Icon(Icons.copy),
                                              label: const Text('Copiar'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 18),
                  ],
                ),
    );
  }
}
