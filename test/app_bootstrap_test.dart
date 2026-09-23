import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenthousandshotchallenge/main.dart';

void main() {
  testWidgets('renders Flutter UI before initialization completes', (tester) async {
    final completer = Completer<Widget>();

    await tester.pumpWidget(AppBootstrap(initializer: () => completer.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const MaterialApp(home: Text('App ready')));
    await tester.pumpAndSettle();

    expect(find.text('App ready'), findsOneWidget);
  });

  testWidgets('shows retry UI when initialization throws', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      AppBootstrap(
        initializer: () async {
          attempts++;
          if (attempts == 1) throw StateError('startup failed');
          return const MaterialApp(home: Text('Recovered'));
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to start the app'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('times out a hung initializer into retry UI', (tester) async {
    await tester.pumpWidget(
      AppBootstrap(initializer: () => Completer<Widget>().future),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));

    expect(find.text('Unable to start the app'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
