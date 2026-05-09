import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showPaymentFormSheet(
  BuildContext context, {
  String title = 'Registrar pago',
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentFormSheet(title: title),
  );
}

class _PaymentFormSheet extends StatefulWidget {
  final String title;
  const _PaymentFormSheet({required this.title});

  @override
  State<_PaymentFormSheet> createState() => _PaymentFormSheetState();
}

class _PaymentFormSheetState extends State<_PaymentFormSheet> {
  final amountCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String method = 'cash'; // cash | transfer | card | other
  String? error;

  @override
  void dispose() {
    amountCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => error = 'Monto inválido.');
      return;
    }

    final notes = notesCtrl.text.trim();

    final payload = <String, dynamic>{
      'amount': amount,
      'method': method,
      if (notes.isNotEmpty) 'notes': notes,
      'paid_at': Dates.nowIsoUtc(),
    };

    Navigator.pop(context, payload);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + bottom),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (error != null) ...[
              GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error!)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto *'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Método'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
                DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'other', child: Text('Otro')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => method = v);
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas')),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar'))),
                const SizedBox(width: 10),
                Expanded(child: PrimaryGlassButton(text: 'Guardar', onPressed: _submit)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
