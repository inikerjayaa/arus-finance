import 'package:arus_finance/core/services/visual_identity_store.dart';
import 'package:arus_finance/shared/icon_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('icon picker searches local catalog and returns stable keys', (
    tester,
  ) async {
    VisualIdentity? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await IconPickerSheet.show(
                  context,
                  initial: const VisualIdentity(
                    iconKey: 'other.category',
                    colorKey: 'slate',
                  ),
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih ikon & warna'), findsOneWidget);
    expect(find.text('Bank'), findsWidgets);
    expect(find.text('Subscription'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'BCA');
    await tester.pumpAndSettle();
    final bcaResult = find.descendant(
      of: find.byType(GridView),
      matching: find.text('BCA'),
    );
    expect(bcaResult, findsOneWidget);

    await tester.tap(bcaResult);
    await tester.pump();
    await tester.tap(find.text('Pakai'));
    await tester.pumpAndSettle();

    expect(result?.iconKey, 'bank.bca');
    expect(result?.colorKey, 'slate');
  });
}
