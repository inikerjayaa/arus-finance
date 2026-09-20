import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/services/local_insight_controller_access.dart';
import '../../core/services/local_insight_service.dart';

String homeGreetingFor(DateTime value, {String? name}) {
  final hour = value.toLocal().hour;
  final greeting = switch (hour) {
    < 11 => 'Selamat pagi',
    < 15 => 'Selamat siang',
    < 18 => 'Selamat sore',
    _ => 'Selamat malam',
  };
  final cleanName = name?.trim();
  return cleanName == null || cleanName.isEmpty ? greeting : '$greeting, $cleanName';
}

class HomeGreetingInsight extends StatefulWidget {
  const HomeGreetingInsight({super.key, required this.controller, required this.visible});
  final AppController controller;
  final bool visible;

  @override
  State<HomeGreetingInsight> createState() => _HomeGreetingInsightState();
}

class _HomeGreetingInsightState extends State<HomeGreetingInsight> {
  LocalInsight? _insight;
  bool _requested = false;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    _requestOnce();
  }

  @override
  void didUpdateWidget(covariant HomeGreetingInsight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible && !widget.visible && !_consumed) setState(() => _consumed = true);
  }

  Future<void> _requestOnce() async {
    if (_requested) return;
    _requested = true;
    final service = widget.controller.localInsightService;
    if (service == null) return;
    try {
      final insight = await service.build();
      if (mounted) setState(() => _insight = insight);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_consumed || _insight == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final insight = _insight!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
      child: Semantics(
        container: true,
        label: 'Insight SAKU. ${insight.title}. ${insight.message}',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: .22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, size: 20, color: theme.colorScheme.tertiary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Insight SAKU', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.tertiary, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(insight.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(insight.message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup insight',
                  onPressed: () => setState(() => _consumed = true),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
