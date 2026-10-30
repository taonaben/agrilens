import 'package:agrilens/app/chat/components/widgets/chat_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reply language menu offers Ndebele and reports the selection', (
    tester,
  ) async {
    String? selectedLanguage;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatActionBar(
            isBusy: false,
            showRetryAction: false,
            responseLanguage: 'shona',
            onResponseLanguageChanged: (value) => selectedLanguage = value,
            onNewChatTap: () {},
            onRetryTap: () {},
            onDeleteTap: () {},
            onCancelTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Shona'), findsOneWidget);
    await tester.tap(find.byTooltip('Reply language'));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Ndebele'), findsOneWidget);

    await tester.tap(find.text('Ndebele'));
    await tester.pumpAndSettle();
    expect(selectedLanguage, 'ndebele');
  });
}
