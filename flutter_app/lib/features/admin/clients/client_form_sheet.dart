import 'package:flutter/material.dart';
import '../../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showClientFormSheet(
  BuildContext context, {
  required String title,
  Map<String, dynamic>? initial,
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClientFormSheet(title: title, initial: initial),
  );
}

class _ClientFormSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initial;

  const _ClientFormSheet({required this.title, required this.initial});

  @override
  State<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<_ClientFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController docCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController notesCtrl;

  String status = 'active';
  String category = 'normal';
  String frequency = 'daily';
  String? error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? {};
    nameCtrl = TextEditingController(text: (i['name'] ?? '').toString());
    docCtrl = TextEditingController(text: (i['doc_id'] ?? i['docId'] ?? '').toString());
    phoneCtrl = TextEditingController(text: (i['phone'] ?? '').toString());
    addressCtrl = TextEditingController(text: (i['address'] ?? '').toString());
    notesCtrl = TextEditingController(text: (i['notes'] ?? '').toString());

    status = ((i['status'] ?? 'active').toString().isEmpty) ? 'active' : (i['status'] ?? 'active').toString();
    category = ((i['category'] ?? 'normal').toString().isEmpty) ? 'normal' : (i['category'] ?? 'normal').toString();
    frequency = ((i['payment_frequency'] ?? i['frequency'] ?? 'daily').toString().isEmpty)
        ? 'daily'
        : (i['payment_frequency'] ?? i['frequency'] ?? 'daily').toString();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    docCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => error = 'El nombre debe tener mínimo 2 caracteres.');
      return;
    }

    final payload = <String, dynamic>{
      'name': name,
      'doc_id': docCtrl.text.trim().isEmpty ? null : docCtrl.text.trim(),
      'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
      'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      'status': status,
      'category': category,
      'payment_frequency': frequency,
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

            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre *')),
            const SizedBox(height: 10),
            TextField(controller: docCtrl, decoration: const InputDecoration(labelText: 'Documento')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 10),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Dirección')),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas')),

            const SizedBox(height: 12),
            _Dropdown<String>(
              label: 'Frecuencia pago',
              value: frequency,
              items: const [
                ('daily', 'Diario'),
                ('interdaily', 'Interdiario'),
                ('weekly', 'Semanal'),
                ('biweekly', 'Quincenal'),
                ('monthly', 'Mensual'),
              ],
              onChanged: (v) => setState(() => frequency = v),
            ),
            const SizedBox(height: 10),
            _Dropdown<String>(
              label: 'Categoría',
              value: category,
              items: const [
                ('normal', 'Normal'),
                ('atrasado', 'Atrasado'),
                ('moroso', 'Moroso'),
                ('congelado', 'Congelado'),
                ('clavo', 'Clavo'),
              ],
              onChanged: (v) => setState(() => category = v),
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: status == 'active',
                    label: const Text('Activo'),
                    onSelected: (_) => setState(() => status = 'active'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    selected: status == 'inactive',
                    label: const Text('Inactivo'),
                    onSelected: (_) => setState(() => status = 'inactive'),
                  ),
                ),
              ],
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

typedef _Pair<T> = (T, String);

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<_Pair<T>> items;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final it in items)
          DropdownMenuItem(
            value: it.$1,
            child: Text(it.$2),
          )
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }
}
