import 'package:flutter/material.dart';

import '../../core/utils/json_utils.dart';
import 'glass.dart';

class JsonCard extends StatelessWidget {
  final dynamic data;
  final String? title;

  const JsonCard({super.key, required this.data, this.title});

  @override
  Widget build(BuildContext context) {
    final txt = JsonUtils.pretty(data);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.black.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                txt,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
