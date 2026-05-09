import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showCashMovementSheet(
  BuildContext context, {
  required String title,
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CashMovementSheet(title: title),
  );
}

class _CashMovementSheet extends StatefulWidget {
  final String title;
  const _CashMovementSheet({required this.title});

  @override
  State<_CashMovementSheet> createState() => _CashMovementSheetState();
}

class _CashMovementSheetState extends State<_CashMovementSheet> {
  String movementType = 'income'; // 'income' | 'expense'
  final amountCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    amountCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      setState(() => error = 'Monto inválido.');
      return;
    }

    final payload = <String, dynamic>{
      'movement_type': movementType,
      'amount': amount,
      if (descCtrl.text.trim().isNotEmpty) 'note': descCtrl.text.trim(),
      'occurred_at': Dates.nowIsoWithOffset(),
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
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: movementType == 'income',
                    label: const Text('Ingreso'),
                    onSelected: (_) => setState(() => movementType = 'income'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    selected: movementType == 'expense',
                    label: const Text('Egreso'),
                    onSelected: (_) => setState(() => movementType = 'expense'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
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
