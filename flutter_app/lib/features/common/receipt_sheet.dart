import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/theme/app_theme.dart';

Future<void> showReceiptSheet(
  BuildContext context, {
  required String clientName,
  required String clientPhone,
  required double amount,
  required String method,
  required double newBalance,
  required String currency,
  String? note,
  int? remainingInstallments,
  int? totalInstallments,
  String? nextDueDate,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReceiptSheet(
      clientName: clientName,
      clientPhone: clientPhone,
      amount: amount,
      method: method,
      newBalance: newBalance,
      currency: currency,
      note: note,
      remainingInstallments: remainingInstallments,
      totalInstallments: totalInstallments,
      nextDueDate: nextDueDate,
    ),
  );
}

class _ReceiptSheet extends StatelessWidget {
  final String clientName;
  final String clientPhone;
  final double amount;
  final String method;
  final double newBalance;
  final String currency;
  final String? note;
  final int? remainingInstallments;
  final int? totalInstallments;
  final String? nextDueDate;

  const _ReceiptSheet({
    required this.clientName,
    required this.clientPhone,
    required this.amount,
    required this.method,
    required this.newBalance,
    required this.currency,
    this.note,
    this.remainingInstallments,
    this.totalInstallments,
    this.nextDueDate,
  });

  bool get _isPaidOff => newBalance <= 0;

  String get _methodLabel => switch (method) {
        'cash' => 'Efectivo',
        'transfer' => 'Transferencia',
        'card' => 'Tarjeta',
        _ => method,
      };

  String get _dateLabel {
    final now = DateTime.now();
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${now.day.toString().padLeft(2,'0')} ${months[now.month-1]} ${now.year}  '
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
  }

  String _fmtAmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    final ccy = currency.isEmpty ? '' : ' $currency';
    return '$buf$ccy';
  }

  String _fmtNextDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      return '${d.day.toString().padLeft(2,'0')} ${months[d.month-1]} ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  String get _receiptText {
    const sep = '─────────────────────';
    final ccy = currency.isEmpty ? '' : ' $currency';
    final buf = StringBuffer();

    if (_isPaidOff) {
      buf.writeln('*🎉 ¡CRÉDITO SALDADO! 🎉*');
    } else {
      buf.writeln('*RECIBO DE PAGO ✅*');
    }
    buf.writeln(sep);
    buf.writeln('📅 $_dateLabel');
    buf.writeln('👤 $clientName');
    buf.writeln(sep);
    buf.writeln('💰 *Pagado:* ${_fmtAmt(amount)}');
    buf.writeln('💳 Método: $_methodLabel');
    if (note != null && note!.isNotEmpty) {
      buf.writeln('📝 Nota: $note');
    }
    buf.writeln(sep);

    if (_isPaidOff) {
      buf.writeln('✅ *Crédito PAGADO completamente*');
      buf.writeln('🙏 ¡Gracias por cumplir con todos tus pagos!');
    } else {
      buf.writeln('💼 *Estado del crédito:*');
      buf.writeln('💵 Saldo pendiente: ${newBalance.toStringAsFixed(0)}$ccy');
      if (remainingInstallments != null && totalInstallments != null) {
        buf.writeln('📋 Cuotas: $remainingInstallments pendiente${remainingInstallments == 1 ? '' : 's'} de $totalInstallments');
      } else if (remainingInstallments != null) {
        buf.writeln('📋 Cuotas restantes: $remainingInstallments');
      }
      if (nextDueDate != null && nextDueDate!.isNotEmpty) {
        buf.writeln('📆 Próximo pago: ${_fmtNextDate(nextDueDate!)}');
      }
    }

    buf.writeln(sep);
    buf.write('_Enviado con COBROSAPP_');
    return buf.toString();
  }

  Future<void> _sendWhatsApp(BuildContext context) async {
    if (clientPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente no tiene número registrado')),
      );
      return;
    }
    final clean = clientPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(_receiptText)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Future<void> _copyReceipt(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _receiptText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recibo copiado al portapapeles')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ccy = currency.isEmpty ? '' : ' $currency';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 14,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ─── Top icon ───
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _isPaidOff
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isPaidOff
                    ? AppColors.success.withValues(alpha: 0.4)
                    : AppColors.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              _isPaidOff ? Icons.verified_rounded : Icons.receipt_long_rounded,
              color: _isPaidOff ? AppColors.success : AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 10),

          Text(
            _isPaidOff ? '¡Crédito saldado!' : 'Pago registrado',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            clientName,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 18),

          // ─── Amount highlight ───
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.12),
                  AppColors.success.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                const Text('Monto pagado', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  _fmtAmt(amount),
                  style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Detail rows ───
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.payments_rounded,
                  label: 'Método',
                  value: _methodLabel,
                  color: AppColors.textPrimary,
                ),
                const _Divider(),
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Fecha y hora',
                  value: _dateLabel,
                  color: AppColors.textSecondary,
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const _Divider(),
                  _DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Nota',
                    value: note!,
                    color: AppColors.textSecondary,
                  ),
                ],
                const _Divider(),
                _DetailRow(
                  icon: _isPaidOff ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                  label: 'Saldo restante',
                  value: _isPaidOff ? 'PAGADO ✓' : _fmtAmt(newBalance),
                  color: _isPaidOff ? AppColors.success : AppColors.error,
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ─── Credit progress (only if not paid off and we have installment data) ───
          if (!_isPaidOff && remainingInstallments != null) ...[
            _CreditProgressCard(
              remaining: remainingInstallments!,
              total: totalInstallments ?? remainingInstallments!,
              nextDueDate: nextDueDate,
              ccy: ccy,
              balance: newBalance,
            ),
            const SizedBox(height: 10),
          ],

          // ─── Paid off celebration ───
          if (_isPaidOff) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Crédito completamente pagado!',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'El cliente ha cumplido con todos sus pagos.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ─── Actions ───
          if (clientPhone.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _sendWhatsApp(context),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar por WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyReceipt(context),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar recibo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Credit progress card
// ─────────────────────────────────────────────
class _CreditProgressCard extends StatelessWidget {
  final int remaining;
  final int total;
  final String? nextDueDate;
  final String ccy;
  final double balance;

  const _CreditProgressCard({
    required this.remaining,
    required this.total,
    required this.nextDueDate,
    required this.ccy,
    required this.balance,
  });

  String _fmtNextDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      final diff = d.difference(DateTime.now()).inDays;
      final dayLabel = diff == 0
          ? 'Hoy'
          : diff == 1
              ? 'Mañana'
              : diff < 0
                  ? 'Hace ${-diff} día${-diff == 1 ? '' : 's'}'
                  : 'En $diff días';
      return '${d.day.toString().padLeft(2,'0')} ${months[d.month-1]} ${d.year}  ·  $dayLabel';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = total - remaining;
    final progress = total > 0 ? paid / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Progreso del crédito',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              _ProgressStat(
                label: 'Pagadas',
                value: '$paid',
                color: AppColors.success,
              ),
              const Spacer(),
              _ProgressStat(
                label: 'Restantes',
                value: '$remaining',
                color: AppColors.warning,
                alignEnd: true,
              ),
              const Spacer(),
              _ProgressStat(
                label: 'Total',
                value: '$total',
                color: AppColors.textSecondary,
                alignEnd: true,
              ),
            ],
          ),

          // Next due date
          if (nextDueDate != null && nextDueDate!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, color: AppColors.info, size: 15),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Próximo pago',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                      Text(
                        _fmtNextDate(nextDueDate!),
                        style: const TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;
  const _ProgressStat({required this.label, required this.value, required this.color, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _DetailRow({required this.icon, required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: AppColors.border),
    );
  }
}
