import 'package:flutter/material.dart';
import '../../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showAssignRouteSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> vendors,
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AssignRouteSheet(vendors: vendors),
  );
}

class _AssignRouteSheet extends StatefulWidget {
  final List<Map<String, dynamic>> vendors;
  const _AssignRouteSheet({required this.vendors});

  @override
  State<_AssignRouteSheet> createState() => _AssignRouteSheetState();
}

class _AssignRouteSheetState extends State<_AssignRouteSheet> {
  String? vendorId;
  DateTime date = DateTime.now();
  String? notes;

  String _fmt(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  @override
  void initState() {
    super.initState();
    if (widget.vendors.isNotEmpty) {
      vendorId = (widget.vendors.first['id'] ?? '').toString();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => date = picked);
  }

  void _submit() {
    if (vendorId == null || vendorId!.isEmpty) return;

    final payload = <String, dynamic>{
      'vendor_id': vendorId,
      'assigned_date': _fmt(date),
      'status': 'assigned',
      'notes': (notes == null || notes!.trim().isEmpty) ? null : notes!.trim(),
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
            Text('Asignar ruta', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: vendorId,
              items: [
                for (final v in widget.vendors)
                  DropdownMenuItem(
                    value: (v['id'] ?? '').toString(),
                    child: Text('${v['name'] ?? 'Vendor'}'),
                  )
              ],
              onChanged: (v) => setState(() => vendorId = v),
              decoration: const InputDecoration(labelText: 'Vendedor'),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(child: Text('Fecha: ${_fmt(date)}')),
                TextButton(onPressed: _pickDate, child: const Text('Cambiar')),
              ],
            ),

            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              onChanged: (v) => notes = v,
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar'))),
                const SizedBox(width: 10),
                Expanded(child: PrimaryGlassButton(text: 'Asignar', onPressed: _submit)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
