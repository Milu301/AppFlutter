import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app_providers.dart';
import '../../../config/app_config.dart';
import '../../../core/api/api_error.dart';
import '../../../ui/widgets/glass.dart';
import '../../../ui/widgets/states.dart';


class AdminSettingsTab extends ConsumerStatefulWidget {
  const AdminSettingsTab({super.key});

  @override
  ConsumerState<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends ConsumerState<AdminSettingsTab> {
  bool loading = false;
  String? health;
  ApiError? error;

  Future<void> _checkHealth() async {
    setState(() {
      loading = true;
      health = null;
      error = null;
    });

    try {
      final api = ref.read(apiProvider);
      final body = await api.health();
      setState(() {
        health = body.toString();
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider).session;
    if (session == null) return const LoadingView();

    final sub = session.subscriptionExpiresAt;
    final now = DateTime.now().toUtc();

    Duration? left;
    if (sub != null) {
      left = sub.toUtc().difference(now);
    }

    String subText;
    if (sub == null) {
      subText = '—';
    } else if (left != null && left.isNegative) {
      subText = 'Vencida (desde ${sub.toLocal()})';
    } else {
      final d = left ?? const Duration();
      final days = d.inDays;
      subText = 'Hasta ${sub.toLocal()}  •  $days día(s) restante(s)';
    }

    return ListView(
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ajustes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _RowKV(label: 'Rol', value: session.role),
              const SizedBox(height: 6),
              _RowKV(label: 'AdminId', value: session.adminId),
              const SizedBox(height: 6),
              _RowKV(label: 'Email', value: session.adminEmail ?? '—'),
              const SizedBox(height: 6),
              _RowKV(label: 'Suscripción', value: subText),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : _checkHealth,
                      icon: loading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.monitor_heart_outlined),
                      label: const Text('Probar API'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ),
                ],
              ),


              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Error: ${error!.message} (${error!.code})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                ),
              ],
              if (health != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Respuesta:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.70)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Text(
                    health!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'API: ${AppConfig.api}\n\n${AppConfig.hintLocalApi}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}

class _RowKV extends StatelessWidget {
  final String label;
  final String value;
  const _RowKV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ),
        Expanded(
          flex: 7,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
