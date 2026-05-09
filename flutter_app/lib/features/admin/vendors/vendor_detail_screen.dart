import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';
import 'vendor_location_screen.dart';
import 'vendor_form_sheet.dart';

class VendorDetailScreen extends ConsumerStatefulWidget {
  final String adminId;
  final String vendorId;
  final String? vendorName;

  const VendorDetailScreen({
    super.key,
    required this.adminId,
    required this.vendorId,
    this.vendorName,
  });

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic>? body;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await ref.read(apiProvider).getVendor(widget.vendorId);
      setState(() {
        body = res;
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

  Map<String, dynamic> _vendorFromBody() {
    final b = body ?? {};
    final data = b['data'];
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final v = m['vendor'];
      if (v is Map) return v.cast<String, dynamic>();
      return m;
    }
    return {};
  }

  Future<void> _edit() async {
    final v = _vendorFromBody();
    final payload = await showVendorFormSheet(context, title: 'Editar vendedor', initial: v);
    if (payload == null) return;

    try {
      final api = ref.read(apiProvider);
      final res = await api.updateVendor(widget.vendorId, payload);
      final err = api.extractError(res);
      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${err.message} (${err.code})')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actualizado ✅')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _resetDevice() async {
    try {
      await ref.read(apiProvider).resetVendorDevice(widget.vendorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device reset enviado ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo: $e')));
    }
  }

  Future<void> _forceLogout() async {
    try {
      await ref.read(apiProvider).forceLogoutVendor(widget.vendorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Force logout enviado ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo: $e')));
    }
  }

  void _openLocation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VendorLocationScreen(
          adminId: widget.adminId,
          vendorId: widget.vendorId,
          vendorName: widget.vendorName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.vendorName == null || widget.vendorName!.trim().isEmpty
        ? 'Vendedor'
        : widget.vendorName!;

    return GlassScaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(onPressed: _load, child: const Text('Refrescar')),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const LoadingView(title: 'Cargando vendedor...')
          : (error != null)
              ? ErrorView(title: 'Error', subtitle: error!, onRetry: _load)
              : ListView(
                  children: [
                    GlassCard(
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Acciones',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          TextButton(onPressed: _edit, child: const Text('Editar')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openLocation,
                              icon: const Icon(Icons.my_location_outlined),
                              label: const Text('Ubicación'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _resetDevice,
                              icon: const Icon(Icons.phonelink_erase_outlined),
                              label: const Text('Reset device'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _forceLogout,
                              icon: const Icon(Icons.logout),
                              label: const Text('Force logout'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 18),
                  ],
                ),
    );
  }
}
