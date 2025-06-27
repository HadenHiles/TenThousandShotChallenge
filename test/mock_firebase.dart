import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> setupFirebaseAuthMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = MockFirebasePlatform();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'testApiKey',
      appId: 'testAppId',
      messagingSenderId: 'testSenderId',
      projectId: 'testProjectId',
    ),
  );
}

class MockFirebasePlatform extends FirebasePlatform {
  MockFirebasePlatform() : super();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp(name: name, options: options);
  }

// use the const name "defaultFirebaseAppName",
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp(
      name: name,
      options: const FirebaseOptions(
        apiKey: 'testApiKey',
        appId: 'testAppId',
        messagingSenderId: 'testSenderId',
        projectId: 'testProjectId',
      ),
    );
  }

  Future<void> resetApp(String name) async {
    // Mock the reset behavior for tests
    return;
  }
}

/// Mock implementation of Firebase App
class MockFirebaseApp extends FirebaseAppPlatform {
  MockFirebaseApp({
    String? name,
    FirebaseOptions? options,
  }) : super(
          name ?? defaultFirebaseAppName,
          options ??
              const FirebaseOptions(
                apiKey: 'testApiKey',
                appId: 'testAppId',
                messagingSenderId: 'testSenderId',
                projectId: 'testProjectId',
              ),
        );
}
