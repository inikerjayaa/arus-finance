import 'dart:convert';
import 'dart:io';
import 'package:arus_finance/shared/saku_brand.dart';
import 'package:arus_finance/shared/saku_splash.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SAKU splash uses the unchanged stacked original without a spinner', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SakuSplashScreen()));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, SakuBrand.stackedLogoAsset);
    expect(image.fit, BoxFit.contain);
    expect(image.color, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('SAKU'), findsNothing); // Never re-typeset the image wordmark.
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, SakuBrand.noturno);
  });

  testWidgets('shared horizontal branding uses original proportions and colors', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SakuBrandHorizontal())));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, SakuBrand.horizontalLogoAsset);
    expect(image.width! / image.height!, closeTo(1448 / 1086, .00001));
    expect(image.fit, BoxFit.contain);
    expect(image.color, isNull);
  });

  test('approved originals retain their source hashes and bundled bytes', () async {
    final manifest = jsonDecode(File('native_artwork/saku/provenance.json').readAsStringSync()) as Map<String, dynamic>;
    for (final raw in manifest['approved_originals'] as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final path = row['path'] as String;
      final bytes = File(path).readAsBytesSync();
      expect(sha256.convert(bytes).toString(), row['sha256']);
      if (path.startsWith('assets/')) {
        final data = await rootBundle.load(path);
        expect(sha256.convert(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)).toString(), row['sha256']);
      }
    }
  });
}
