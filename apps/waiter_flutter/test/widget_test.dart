import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waiter_flutter/main.dart';

void main() {
  testWidgets('muestra login de meseros', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WaiterApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Meseros'), findsOneWidget);
    expect(find.text('Recordarme en este dispositivo'), findsOneWidget);
    final passwordField = find.byType(TextField).last;
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    final visibilityButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.visibility),
    );
    visibilityButton.onPressed!();
    await tester.pump();
    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
  });
}
