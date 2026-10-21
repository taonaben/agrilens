import 'package:agrilens/app/main/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sidebar navigates between pages, history and settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: App()));
    expect(find.text('Chat page'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    expect(find.text('Store page'), findsOneWidget);

    await tester.tap(find.text('Crop planning'));
    await tester.pumpAndSettle();
    expect(find.text('Crop planning chat'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings page'), findsOneWidget);
  });

  testWidgets('mobile navigation opens in a drawer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: App()));
    expect(find.text('Chat page'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weather'));
    await tester.pumpAndSettle();

    expect(find.text('Weather page'), findsOneWidget);
  });
}
