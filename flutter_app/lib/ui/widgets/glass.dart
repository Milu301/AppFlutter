import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────
// Background gradient
// ─────────────────────────────────────────────
class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgMid, AppColors.bg, AppColors.bg],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// GlassCard
// ─────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final LinearGradient? gradient;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    Widget content = Padding(padding: padding, child: child);

    if (gradient != null) {
      content = Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
          border: Border.all(color: AppColors.borderBright.withValues(alpha: 0.5)),
        ),
        child: ClipRRect(borderRadius: borderRadius, child: content),
      );
      return onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
            );
    }

    return Material(
      color: color ?? AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}

// ─────────────────────────────────────────────
// GlassScaffold
// ─────────────────────────────────────────────
class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const GlassScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: appBar,
      body: PremiumBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}

// ─────────────────────────────────────────────
// PrimaryGlassButton (gradient)
// ─────────────────────────────────────────────
class PrimaryGlassButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool enabled;
  final bool loading;

  const PrimaryGlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.enabled = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || loading || onPressed == null;

    Widget label = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : (icon == null
            ? Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ));

    final btn = Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: isDisabled
            ? null
            : const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isDisabled ? AppColors.surfaceBright : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(
                color: isDisabled ? AppColors.textMuted : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: isDisabled ? AppColors.textMuted : Colors.white,
                  size: 18,
                ),
                child: label,
              ),
            ),
          ),
        ),
      ),
    );

    if (fullWidth) return SizedBox(width: double.infinity, child: btn);
    return btn;
  }
}

// ─────────────────────────────────────────────
// StatCard — tarjeta de estadística
// ─────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SectionHeader
// ─────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ClientAvatar — círculo con iniciales
// ─────────────────────────────────────────────
class ClientAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const ClientAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _color {
    if (color != null) return color!;
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.info,
      AppColors.warning,
      AppColors.success,
    ];
    int hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFF;
    }
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.35,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CurrencyText — formato moneda
// ─────────────────────────────────────────────
class CurrencyText extends ConsumerWidget {
  final double amount;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;

  const CurrencyText({
    super.key,
    required this.amount,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w700,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(currencyProvider);
    final formatted = cfg.fmt(amount.abs());

    Color c = color ?? AppColors.textPrimary;
    if (color == null) {
      if (amount > 0) c = AppColors.success;
      if (amount < 0) c = AppColors.error;
    }

    return Text(
      formatted,
      style: TextStyle(
        color: c,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// StatusBadge
// ─────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AppLogo
// ─────────────────────────────────────────────
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.monetization_on_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
