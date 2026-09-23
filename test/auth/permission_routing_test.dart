import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:tenthousandshotchallenge/IntroScreen.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:tenthousandshotchallenge/router.dart';

import '../main_test.mocks.dart';

class _MissingPermissionsNotifier extends PermissionsNotifier {
  _MissingPermissionsNotifier() : super.withGranted();

  @override
  bool get checked => true;

  @override
  bool get needsPermissions => true;
}

void main() {
  testWidgets('missing permissions do not redirect during startup', (tester) async {
    final auth = MockFirebaseAuth(signedIn: false);
    final analytics = MockFirebaseAnalytics();
    when(
      analytics.logScreenView(
        screenName: anyNamed('screenName'),
        screenClass: anyNamed('screenClass'),
      ),
    ).thenAnswer((_) async {});
    final authNotifier = AuthChangeNotifier(auth);
    final router = createAppRouter(
      analytics,
      authNotifier: authNotifier,
      introShownNotifier: IntroShownNotifier.withValue(true),
      permissionsNotifier: _MissingPermissionsNotifier(),
      initialLocation: '/login',
    );
    addTearDown(authNotifier.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      Provider<FirebaseAuth>.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Login), findsOneWidget);
    expect(find.byType(PermissionsScreen), findsNothing);
  });
}
