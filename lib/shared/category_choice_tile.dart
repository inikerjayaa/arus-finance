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

/// Canonical category picker used by transaction-entry surfaces.
///
/// Keeping this in shared UI prevents Quick Add and future category pickers
/// from drifting back to text-only/radio-only rows. It is deliberately small:
/// no extra assets, animation, state manager, or dependency is introduced.
///
/// The keyboard is dismissed before the sheet opens. This preserves the
/// existing Quick Add handoff behavior and avoids stacking the category sheet
/// above a still-visible numeric keyboard on slower Android devices.
Future<String?> showCategoryChoicePicker(
  BuildContext context, {
  required String title,
  required List<Category> categories,
  String? selectedId,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  for (var i = 0; i < 16; i++) {
    if (!context.mounted) return null;
    if (MediaQuery.viewInsetsOf(context).bottom <= 0) break;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  if (!context.mounted) return null;

  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(sheetContext)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        ...categories.map(
          (category) => CategoryChoiceTile(
            category: category,
            selected: category.id == selectedId,
            onTap: () => Navigator.pop(sheetContext, category.id),
          ),
        ),
      ],
    ),
  );
}
