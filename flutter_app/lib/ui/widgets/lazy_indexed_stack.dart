import 'package:flutter/widgets.dart';

/// IndexedStack pero "lazy": construye cada tab sólo cuando se visita.
///
/// Esto evita que TODOS los tabs disparen requests en initState al entrar
/// al Home (lo que causaba jank + demasiadas llamadas al backend).
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> builders;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<Widget?> _cache;

  @override
  void initState() {
    super.initState();
    _cache = List<Widget?>.filled(widget.builders.length, null, growable: false);
    _cache[widget.index] = widget.builders[widget.index](context);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.builders.length != widget.builders.length) {
      // Caso raro: cambió el número de tabs.
      _cache = List<Widget?>.filled(widget.builders.length, null, growable: false);
    }

    if (widget.index >= 0 && widget.index < widget.builders.length) {
      _cache[widget.index] ??= widget.builders[widget.index](context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(
        widget.builders.length,
        (i) => _cache[i] ?? const SizedBox.shrink(),
      ),
    );
  }
}
