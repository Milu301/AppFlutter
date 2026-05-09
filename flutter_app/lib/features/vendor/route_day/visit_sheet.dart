import 'package:flutter/material.dart';

import '../../../core/utils/dates.dart';
import '../../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showVisitSheet(
  BuildContext context, {
  required bool initialVisited,
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VisitSheet(initialVisited: initialVisited),
  );
}

class _VisitSheet extends StatefulWidget {
  final bool initialVisited;
  const _VisitSheet({required this.initialVisited});

  @override
  State<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends State<_VisitSheet> {
  late bool visited;
  final noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    visited = widget.initialVisited;
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final payload = <String, dynamic>{
      'visited': visited,
      'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      'visited_at': Dates.nowIsoWithOffset(),
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
            Text('Registrar visita', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: visited,
                    label: const Text('Visitado'),
                    onSelected: (_) => setState(() => visited = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    selected: !visited,
                    label: const Text('No visitado'),
                    onSelected: (_) => setState(() => visited = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Nota (opcional)')),
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
