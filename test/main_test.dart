import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tenthousandshotchallenge/main.dart';
import 'package:tenthousandshotchallenge/theme/PreferencesStateNotifier.dart';
import 'package:tenthousandshotchallenge/services/NetworkStatusService.dart';
import 'package:tenthousandshotchallenge/Navigation.dart';
import 'package:tenthousandshotchallenge/IntroScreen.dart';
import 'package:tenthousandshotchallenge/Login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tenthousandshotchallenge/router.dart';
import 'main_test.mocks.dart';

// Mock classes
@GenerateMocks([
  FirebaseAnalytics,
  CustomerInfo,
  NetworkStatusService,
])
void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

// Stub for AppleSignInAvailable
class AppleSignInAvailable {
  final bool isAvailable;
  AppleSignInAvailable({this.isAvailable = false});
  static Future<AppleSignInAvailable> check() async {
    return AppleSignInAvailable(isAvailable: false);
  }
}

// Minimal fake for EntitlementInfos to control subscription level in tests
class FakeEntitlementInfos implements EntitlementInfos {
  final Map<String, EntitlementInfo> _active;
  FakeEntitlementInfos(this._active);
  @override
  Map<String, EntitlementInfo> get active => _active;
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Minimal fake for EntitlementInfo to use in tests
class FakeEntitlementInfo implements EntitlementInfo {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

bool get isIntegrationTest => Platform.environment['FLUTTER_TEST'] != 'true' && Platform.environment['USE_FIREBASE_EMULATOR'] == 'true';

void main() {
  NetworkStatusService.isTestingOverride = true;
  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseFirestore firestore;
  setUp(() async {
    if (isIntegrationTest) {
      await Firebase.initializeApp();
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      firestore = FirebaseFirestore.instance;
    } else {
      firestore = FakeFirebaseFirestore();
    }
  });
  testWidgets('Home widget shows IntroScreen when introShown is false', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'dark_mode': false,
      'puck_count': 25,
      'friend_notifications': true,
      'target_date': DateTime.now().add(Duration(days: 100)).toIso8601String(),
      'intro_shown': false, // Set to false for IntroScreen test
      'fcm_token': 'mock_token',
    });
    final mockAuth = MockFirebaseAuth(signedIn: true);
    final mockAnalytics = MockFirebaseAnalytics();
    when(mockAnalytics.logScreenView(
      screenName: anyNamed('screenName'),
      screenClass: anyNamed('screenClass'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.logEvent(
      name: anyNamed('name'),
      parameters: anyNamed('parameters'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.setUserId(
      id: anyNamed('id'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.setUserProperty(
      name: anyNamed('name'),
      value: anyNamed('value'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.resetAnalyticsData()).thenAnswer((_) async => Void);
    when(mockAnalytics.setAnalyticsCollectionEnabled(any)).thenAnswer((_) async => Void);
    final mockCustomerInfo = MockCustomerInfo();
    // Free user: no entitlements
    when(mockCustomerInfo.entitlements).thenReturn(FakeEntitlementInfos({}));
    final mockNetworkStatus = MockNetworkStatusService();
    // Stub networkStatusController for NetworkStatusService
    when(mockNetworkStatus.networkStatusController).thenReturn(StreamController<NetworkStatus>());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(isAvailable: false)),
          ChangeNotifierProvider<PreferencesStateNotifier>(
            create: (_) => PreferencesStateNotifier(),
          ),
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: firestore),
          Provider<FirebaseAnalytics>.value(value: mockAnalytics),
          Provider<CustomerInfo?>.value(value: mockCustomerInfo),
          Provider<NetworkStatusService>.value(value: mockNetworkStatus),
        ],
        child: Home(introShownNotifier: IntroShownNotifier.withValue(false)),
      ),
    );
    await tester.pumpAndSettle();
    // Should show IntroScreen if introShown is false
    expect(find.byType(IntroScreen), findsOneWidget);
  });

  testWidgets('Home widget shows Login when user is not logged in and introShown is true', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'dark_mode': false,
      'puck_count': 25,
      'friend_notifications': true,
      'target_date': DateTime.now().add(Duration(days: 100)).toIso8601String(),
      'intro_shown': true, // Set to true for Login test (user not logged in)
      'fcm_token': 'mock_token',
    });
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final mockAnalytics = MockFirebaseAnalytics();
    when(mockAnalytics.logScreenView(
      screenName: anyNamed('screenName'),
      screenClass: anyNamed('screenClass'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.logEvent(
      name: anyNamed('name'),
      parameters: anyNamed('parameters'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.setUserId(
      id: anyNamed('id'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.setUserProperty(
      name: anyNamed('name'),
      value: anyNamed('value'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.resetAnalyticsData()).thenAnswer((_) async => Void);
    when(mockAnalytics.setAnalyticsCollectionEnabled(any)).thenAnswer((_) async => Void);
    final mockCustomerInfo = MockCustomerInfo();
    // Free user: no entitlements
    when(mockCustomerInfo.entitlements).thenReturn(FakeEntitlementInfos({}));
    final mockNetworkStatus = MockNetworkStatusService();
    // Stub networkStatusController for NetworkStatusService
    when(mockNetworkStatus.networkStatusController).thenReturn(StreamController<NetworkStatus>());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(isAvailable: false)),
          ChangeNotifierProvider<PreferencesStateNotifier>(
            create: (_) => PreferencesStateNotifier(),
          ),
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: firestore),
          Provider<FirebaseAnalytics>.value(value: mockAnalytics),
          Provider<CustomerInfo?>.value(value: mockCustomerInfo),
          Provider<NetworkStatusService>.value(value: mockNetworkStatus),
        ],
        child: Home(introShownNotifier: IntroShownNotifier.withValue(true)),
      ),
    );
    await tester.pumpAndSettle();
    // Should show Login if user is not logged in
    expect(find.byType(Login), findsOneWidget);
  });

  testWidgets('Home widget shows Navigation when user is logged in and introShown is true', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'dark_mode': false,
      'puck_count': 25,
      'friend_notifications': true,
      'target_date': DateTime.now().add(Duration(days: 100)).toIso8601String(),
      'intro_shown': true, // Set to true for Navigation test
      'fcm_token': 'mock_token',
    });
    final mockUser = MockUser(
      isAnonymous: false,
      uid: 'testuid',
      email: 'test@example.com',
    );
    final mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    final mockAnalytics = MockFirebaseAnalytics();
    when(mockAnalytics.logScreenView(
      screenName: anyNamed('screenName'),
      screenClass: anyNamed('screenClass'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.logEvent(
      name: anyNamed('name'),
      parameters: anyNamed('parameters'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.setUserId(
      id: anyNamed('id'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.setUserProperty(
      name: anyNamed('name'),
      value: anyNamed('value'),
    )).thenAnswer((_) async => Void);
    when(mockAnalytics.resetAnalyticsData()).thenAnswer((_) async => Void);
    when(mockAnalytics.setAnalyticsCollectionEnabled(any)).thenAnswer((_) async => Void);
    // Create the user document to avoid not-found errors
    await firestore.collection('users').doc('testuid').set({
      'display_name_lowercase': 'test@example.com',
      'display_name': 'test@example.com',
      'email': 'test@example.com',
      'public': true,
      'fcm_token': 'mock_token',
    });
    final mockCustomerInfo = MockCustomerInfo();
    // Pro user: has 'pro' entitlement
    when(mockCustomerInfo.entitlements).thenReturn(FakeEntitlementInfos({'pro': FakeEntitlementInfo()}));
    final mockNetworkStatus = MockNetworkStatusService();
    // Stub networkStatusController for NetworkStatusService
    when(mockNetworkStatus.networkStatusController).thenReturn(StreamController<NetworkStatus>());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppleSignInAvailable>.value(value: AppleSignInAvailable(isAvailable: false)),
          ChangeNotifierProvider<PreferencesStateNotifier>(
            create: (_) => PreferencesStateNotifier(),
          ),
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: firestore),
          Provider<FirebaseAnalytics>.value(value: mockAnalytics),
          Provider<CustomerInfo?>.value(value: mockCustomerInfo),
          Provider<NetworkStatusService>.value(value: mockNetworkStatus),
        ],
        child: Home(introShownNotifier: IntroShownNotifier.withValue(true)),
      ),
    );
    await tester.pump(); // allow first frame
    await tester.pump(const Duration(milliseconds: 100)); // allow post frame callback
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    // Should show Navigation widget if user is logged in and introShown is true
    expect(find.byType(Navigation), findsOneWidget);
  });
}
