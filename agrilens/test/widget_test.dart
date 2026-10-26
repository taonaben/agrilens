import 'package:agrilens/app/main/app.dart';
import 'package:agrilens/app/auth/services/auth_session.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createApp() {
    final session = AuthSession();
    final apiClient = ApiClient(
      accessTokenProvider: () async => null,
      baseUrl: 'https://api.example.com',
    );
    return MaterialApp(home: App(apiClient: apiClient, authSession: session));
  }

  testWidgets('wide sidebar shows app destinations', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('AgriLens'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('mobile navigation opens in a drawer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createApp());
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
