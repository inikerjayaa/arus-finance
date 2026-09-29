import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:arus_finance/shared/saku_icon_registry.dart';
import 'package:arus_finance/shared/saku_visual_icon.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every mapped vetted logo decodes from bundle and matches provenance', () async {
    final manifest = jsonDecode(File('assets/brands/provenance.json').readAsStringSync()) as Map<String, dynamic>;
    final entries = {for (final row in manifest['assets'] as List<dynamic>) (row as Map<String, dynamic>)['id'] as String: row};
    for (final choice in SakuIconRegistry.choices.where((c) => c.hasBundledAsset)) {
      final entry = entries[choice.key.substring(SakuIconRegistry.brandPrefix.length)];
      expect(entry, isNotNull, reason: choice.key);
      expect(entry!['asset_path'], choice.assetPath);
      final data = await rootBundle.load(choice.assetPath!);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      expect(sha256.convert(bytes).toString(), entry['asset_sha256'], reason: choice.key);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
      frame.image.dispose();
      codec.dispose();
    }
  });
  testWidgets('named brand cannot be stretched or recolored', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SakuVisualIcon(iconKey: 'brand:bca', fit: BoxFit.fill, color: Colors.red)));
    final widget = tester.widget<Image>(find.byType(Image));
    expect(widget.fit, BoxFit.contain);
    expect(widget.color, isNull);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
  testWidgets('missing named logo is explicit and never generic', (tester) async {
    final missing = SakuIconRegistry.missingRequiredBrandAssets;
    if (missing.isEmpty) return;
    final choice = missing.first;
    await tester.pumpWidget(MaterialApp(home: SakuVisualIcon(iconKey: choice.key)));
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byIcon(choice.fallbackIcon), findsNothing);
  });
}
