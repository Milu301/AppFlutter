import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/api/api_error.dart';
import '../../core/utils/device_id.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/glass.dart';

class VendorLoginScreen extends ConsumerStatefulWidget {
  const VendorLoginScreen({super.key});

  @override
  ConsumerState<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends ConsumerState<VendorLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _pass;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  bool _loading = false;
  bool _obscure = true;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    _pass = TextEditingController();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _slideIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic)
        .drive(Tween(begin: const Offset(0, 0.06), end: Offset.zero));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(ApiError e) {
    switch (e.code) {
      case 'UNAUTHORIZED':
      case 'HTTP_401':
        return 'Correo o contraseña incorrectos.';
      case 'FORBIDDEN':
      case 'HTTP_403':
        if (e.message.toLowerCase().contains('inactiv')) return 'Tu cuenta está inactiva. Contacta al administrador.';
        if (e.message.toLowerCase().contains('suscripci')) return 'La suscripción ha expirado.';
        if (e.message.toLowerCase().contains('device') || e.message.toLowerCase().contains('dispositivo')) return 'Dispositivo no autorizado.';
        return e.message;
      case 'SUBSCRIPTION_EXPIRED':
        return 'La suscripción ha expirado. Contacta al administrador.';
      case 'DEVICE_MISMATCH':
        return 'Este dispositivo no está autorizado.';
      case 'NETWORK_ERROR':
      case 'HTTP_503':
      case 'HTTP_502':
        return 'Sin conexión. Verifica tu internet.';
      case 'TOO_MANY_REQUESTS':
      case 'HTTP_429':
        return 'Demasiados intentos. Espera un momento.';
      case 'INTERNAL_ERROR':
      case 'HTTP_500':
        return 'Error del servidor. Intenta más tarde.';
      default:
        return e.message.isNotEmpty ? e.message : 'Error al iniciar sesión.';
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await ref.read(authProvider.notifier).loginVendor(
          email: _email.text.trim(),
          password: _pass.text,
        );

    if (!mounted) return;

    if (!ok) {
      final raw = ref.read(authProvider).lastError;
      setState(() {
        _loading = false;
        _error = raw != null ? ApiError(code: raw.code, message: _friendlyError(raw)) : null;
      });
      return;
    }

    setState(() => _loading = false);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _showDeviceId() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En Web el dispositivo no se vincula como en móvil.')),
      );
      return;
    }

    final id = await DeviceId.getStableId();
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('ID del dispositivo'),
        content: SelectableText(id),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: id));
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(dialogCtx)
                  .showSnackBar(const SnackBar(content: Text('Copiado al portapapeles')));
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Fondo degradado
          Positioned.fill(
            child: CustomPaint(painter: _BgPainter()),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.height - MediaQuery.of(context).padding.top),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideIn,
                          child: _buildHeader(),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Form card
                      FadeTransition(
                        opacity: _fadeIn,
                        child: SlideTransition(
                          position: _slideIn,
                          child: _buildForm(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(size: 60),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.textPrimary, AppColors.primaryLight],
          ).createShader(bounds),
          child: const Text(
            'Bienvenido',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Inicia sesión para gestionar\ntus cobros del día',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _ErrorBanner(error: _error!),
              const SizedBox(height: 16),
            ],

            // Email
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Escribe tu correo';
                final emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRe.hasMatch(value)) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Escribe tu contraseña';
                if ((v ?? '').length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Botón login
            PrimaryGlassButton(
              text: _loading ? 'Ingresando…' : 'Iniciar sesión',
              icon: _loading ? null : Icons.login_rounded,
              fullWidth: true,
              onPressed: _loading ? null : _submit,
              loading: _loading,
            ),

            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _showDeviceId,
                icon: const Icon(Icons.phonelink_lock_outlined, size: 16),
                label: const Text('Ver ID del dispositivo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final ApiError error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error.message,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Orb superior izquierda
    paint.color = AppColors.primary.withValues(alpha: 0.12);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.1), 180, paint);

    // Orb inferior derecha
    paint.color = AppColors.secondary.withValues(alpha: 0.07);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.75), 220, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
