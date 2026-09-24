import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'category_visuals.dart';

/// Lightweight reusable category row for picker surfaces.
///
/// Keeps category identity visual and selection state separate: the leading
/// icon always comes from [CategoryVisuals], while selection is shown as a
/// trailing radio indicator. This avoids replacing the category icon when a
/// row becomes selected.
class CategoryChoiceTile extends StatelessWidget {
  const CategoryChoiceTile({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        CategoryVisuals.iconFor(category),
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(category.name),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
