import 'package:flutter/material.dart';
import '../../../ui/widgets/glass.dart';

Future<Map<String, dynamic>?> showVendorFormSheet(
  BuildContext context, {
  required String title,
  Map<String, dynamic>? initial,
}) async {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VendorFormSheet(title: title, initial: initial),
  );
}

class _VendorFormSheet extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initial;

  const _VendorFormSheet({required this.title, required this.initial});

  @override
  State<_VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends State<_VendorFormSheet> {
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController passCtrl;
  late final TextEditingController phoneCtrl;

  String status = 'active';
  bool canCreateClients = true;
  bool canCreateCredits = true;
  String? error;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? {};
    nameCtrl = TextEditingController(text: (i['name'] ?? '').toString());
    emailCtrl = TextEditingController(text: (i['email'] ?? '').toString());
    passCtrl = TextEditingController();
    phoneCtrl = TextEditingController(text: (i['phone'] ?? '').toString());
    status = ((i['status'] ?? 'active').toString().isEmpty) ? 'active' : (i['status'] ?? 'active').toString();

    // permisos (si vienen en la fila del backend)
    final perms = (i['permissions'] is Map) ? (i['permissions'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    canCreateClients = (perms['canCreateClients'] ?? true) == true;
    canCreateCredits = (perms['canCreateCredits'] ?? true) == true;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (name.length < 2) {
      setState(() => error = 'El nombre debe tener mínimo 2 caracteres.');
      return;
    }
    if (email.length < 5 || !email.contains('@')) {
      setState(() => error = 'Email inválido.');
      return;
    }

    // ✅ En backend: password es requerido para crear y min 6.
    if (widget.initial == null) {
      if (pass.isEmpty) {
        setState(() => error = 'El password es obligatorio para crear el vendedor.');
        return;
      }
      if (pass.length < 6) {
        setState(() => error = 'El password debe tener mínimo 6 caracteres.');
        return;
      }
    } else {
      // update: si viene, validar
      if (pass.isNotEmpty && pass.length < 6) {
        setState(() => error = 'El password debe tener mínimo 6 caracteres.');
        return;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'status': status,
      'phone': phone.isEmpty ? null : phone,
      'permissions': {
        'canCreateClients': canCreateClients,
        'canCreateCredits': canCreateCredits,
      },
    };
    if (pass.isNotEmpty) {
      payload['password'] = pass;
    }

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
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email *')),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.initial == null ? 'Password *' : 'Password (dejar vacío para no cambiar)',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: canCreateClients,
                    onChanged: (v) => setState(() => canCreateClients = v),
                    title: const Text('Puede crear clientes'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: canCreateCredits,
                    onChanged: (v) => setState(() => canCreateCredits = v),
                    title: const Text('Puede crear créditos'),
                  ),
                ),
              ],
            ),
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
