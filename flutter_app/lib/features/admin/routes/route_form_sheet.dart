import 'package:flutter/material.dart';
import '../../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showRouteFormSheet(
  BuildContext context, {
  required String title,
  Map<String, dynamic>? initial,
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RouteFormSheet(title: title, initial: initial),
  );
}

class _RouteFormSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initial;
  const _RouteFormSheet({required this.title, this.initial});

  @override
  State<_RouteFormSheet> createState() => _RouteFormSheetState();
}

class _RouteFormSheetState extends State<_RouteFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController notesCtrl;

  String status = 'active';
  String? error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? {};
    nameCtrl = TextEditingController(text: (i['name'] ?? '').toString());
    // ✅ Compat: backend usa description
    notesCtrl = TextEditingController(text: (i['notes'] ?? i['description'] ?? '').toString());
    status = ((i['status'] ?? 'active').toString().isEmpty) ? 'active' : (i['status'] ?? 'active').toString();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => error = 'Nombre inválido.');
      return;
    }

    // ✅ Compat: el backend usa "description".
    // La UI históricamente usó "notes". Para NO romper nada, enviamos ambos.
    final notes = notesCtrl.text.trim();
    final payload = <String, dynamic>{
      'name': name,
      'notes': notes.isEmpty ? null : notes,
      'description': notes.isEmpty ? null : notes,
      'status': status,
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
            TextField(controller: notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notas')),
            const SizedBox(height: 12),
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
