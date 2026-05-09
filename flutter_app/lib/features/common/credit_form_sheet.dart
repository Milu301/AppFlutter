import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/utils/dates.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showCreditFormSheet(
  BuildContext context, {
  String title = 'Crear crédito',
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreditFormSheet(title: title),
  );
}

class _CreditFormSheet extends ConsumerStatefulWidget {
  final String title;
  const _CreditFormSheet({required this.title});

  @override
  ConsumerState<_CreditFormSheet> createState() => _CreditFormSheetState();
}

class _CreditFormSheetState extends ConsumerState<_CreditFormSheet> {
  final principalCtrl = TextEditingController();
  final interestCtrl = TextEditingController(text: '20');
  final termsCtrl = TextEditingController(text: '20');
  final notesCtrl = TextEditingController();

  String frequency = 'daily';
  DateTime startDate = DateTime.now();

  String? error;

  @override
  void dispose() {
    principalCtrl.dispose();
    interestCtrl.dispose();
    termsCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  double? _parseNum(TextEditingController c) {
    final raw = c.text.trim().replaceAll(',', '.');
    return double.tryParse(raw);
  }

  int? _parseInt(TextEditingController c) => int.tryParse(c.text.trim());

  double _round2(double n) => (n * 100).roundToDouble() / 100.0;

  void _submit() {
    final principal = _parseNum(principalCtrl);
    final interest = _parseNum(interestCtrl) ?? 0;
    final terms = _parseInt(termsCtrl);
    final currency = ref.read(currencyProvider);

    if (principal == null || principal <= 0) {
      setState(() => error = 'Ingresa un monto válido.');
      return;
    }
    if (interest < 0) {
      setState(() => error = 'El interés no puede ser negativo.');
      return;
    }
    if (terms == null || terms <= 0) {
      setState(() => error = 'Ingresa un número de cuotas válido.');
      return;
    }

    Navigator.pop(context, <String, dynamic>{
      'principal_amount': _round2(principal),
      'interest_rate': _round2(interest),
      'installments_count': terms,
      'currency_code': currency.code,
      'payment_frequency': frequency,
      'start_date': Dates.ymd(startDate),
      'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final principal = _parseNum(principalCtrl) ?? 0;
    final interest = _parseNum(interestCtrl) ?? 0;
    final terms = _parseInt(termsCtrl) ?? 1;

    final total = _round2(principal * (1 + (interest / 100.0)));
    final cuota = terms > 0 ? _round2(total / terms) : 0.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header ───
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                // Currency badge — muestra la moneda activa (se configura en Perfil)
                _CurrencyBadge(code: currency.code, symbol: currency.symbol),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'La moneda se configura en Perfil → Preferencias',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 14),

            // ─── Error ───
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ─── Monto ───
            TextField(
              controller: principalCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto principal *',
                prefixText: '${currency.symbol} ',
              ),
              onChanged: (_) => setState(() => error = null),
            ),
            const SizedBox(height: 10),

            // ─── Interés y Cuotas ───
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: interestCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Interés (%)',
                      suffixText: '%',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: termsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cuotas *',
                      suffixText: 'cuotas',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ─── Frecuencia ───
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'Frecuencia de pago'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Diario')),
                DropdownMenuItem(value: 'interdaily', child: Text('Interdiario')),
                DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                DropdownMenuItem(value: 'biweekly', child: Text('Quincenal')),
                DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
              ],
              onChanged: (v) { if (v != null) setState(() => frequency = v); },
            ),
            const SizedBox(height: 10),

            // ─── Fecha inicio ───
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fecha de inicio', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(height: 1),
                        Text(
                          Dates.ymd(startDate),
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
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
                      if (picked != null) setState(() => startDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: const Text('Cambiar', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ─── Notas ───
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 12),

            // ─── Resumen ───
            if (principal > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        label: 'Total con interés',
                        value: '${currency.symbol}${_fmtNum(total)}',
                        color: AppColors.primary,
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    Expanded(
                      child: _SummaryItem(
                        label: 'Cuota aprox.',
                        value: '${currency.symbol}${_fmtNum(cuota)}',
                        color: AppColors.success,
                      ),
                    ),
                    Container(width: 1, height: 32, color: AppColors.border),
                    Expanded(
                      child: _SummaryItem(
                        label: 'Moneda',
                        value: currency.code,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ─── Actions ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Crear crédito'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}

// ─── Currency badge ───
class _CurrencyBadge extends StatelessWidget {
  final String code;
  final String symbol;
  const _CurrencyBadge({required this.code, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            code,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary item ───
class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.center),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
