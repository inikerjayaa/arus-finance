import 'package:flutter/material.dart';

import '../../app_controller.dart';

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

/// Kept as a compatibility seam while Home is simplified in V49.
///
/// The previous implementation eagerly built a local insight and wrapped it in
/// decorative chrome every time Home was opened. The primary dashboard already
/// presents the user's financial facts, so this slot intentionally stays empty:
/// one fact gets one primary presentation, with no extra work on the Home path.
class HomeGreetingInsight extends StatelessWidget {
  const HomeGreetingInsight({
    super.key,
    required this.controller,
    required this.visible,
  });

  final AppController controller;
  final bool visible;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
