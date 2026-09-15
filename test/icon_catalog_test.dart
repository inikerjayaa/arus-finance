import 'package:arus_finance/shared/icon_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('icon catalog stable keys are unique', () {
    final keys = IconCatalog.entries.map((entry) => entry.key).toList();
    expect(keys.toSet().length, keys.length);
  });

  test('bank aliases resolve common Indonesian naming variants', () {
    expect(IconCatalog.suggest('mybank').key, 'bank.maybank');
    expect(IconCatalog.suggest('bank central asia').key, 'bank.bca');
    expect(IconCatalog.suggest('ocbc nisp').key, 'bank.ocbc');
  });

  test('subscription and everyday categories are searchable', () {
    expect(IconCatalog.suggest('chat gpt').key, 'subscription.chatgpt');
    expect(IconCatalog.suggest('netflix').key, 'subscription.netflix');
    expect(IconCatalog.suggest('sepatu').key, 'shopping.shoes');
    expect(IconCatalog.suggest('bensin').key, 'transport.fuel');
  });

  test('group filter keeps icon picker results scoped', () {
    final result = IconCatalog.search(
      'bank',
      group: IconCatalogGroup.bank,
      limit: 100,
    );
    expect(result, isNotEmpty);
    expect(result.every((entry) => entry.group == IconCatalogGroup.bank), isTrue);
  });

  test('unknown stable key has a safe generic fallback', () {
    expect(IconCatalog.fallbackFor('future.unknown').key, 'other.category');
  });
}
