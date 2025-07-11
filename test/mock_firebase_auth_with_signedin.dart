import 'package:firebase_auth/firebase_auth.dart'; // For UserCredential, FirebaseAuthException
import 'package:tenthousandshotchallenge/router.dart'; // For AuthChangeNotifier
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

class MockFirebaseAuthWithSignedIn extends MockFirebaseAuth {
  bool _signedIn = false;
  final MockUser? _mockUser;
  MockFirebaseAuthWithSignedIn({required super.mockUser, bool signedIn = false}) : _mockUser = mockUser {
    _signedIn = signedIn;
  }
  set signedIn(bool value) => _signedIn = value;
  @override
  MockUser? get currentUser => _signedIn ? _mockUser : null;
}

// Generic error mock
class ErrorAuthMock extends MockFirebaseAuthWithSignedIn {
  final String code;
  final String? message;
  ErrorAuthMock({required MockUser mockUser, required this.code, this.message}) : super(mockUser: mockUser, signedIn: false);
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) async {
    throw FirebaseAuthException(code: code, message: message);
  }
}

// Factory for common test users and auth states
class TestAuthFactory {
  static MockUser get defaultUser => MockUser(
        uid: 'test_uid',
        email: 'test@example.com',
        displayName: 'Test User',
        isEmailVerified: true,
      );

  static MockFirebaseAuthWithSignedIn get signedInAuth => MockFirebaseAuthWithSignedIn(mockUser: defaultUser, signedIn: true);
  static MockFirebaseAuthWithSignedIn get signedOutAuth => MockFirebaseAuthWithSignedIn(mockUser: defaultUser, signedIn: false);
  static MockFirebaseAuthWithSignedIn customUser({required MockUser user, bool signedIn = true}) => MockFirebaseAuthWithSignedIn(mockUser: user, signedIn: signedIn);

  static ErrorAuthMock wrongPasswordAuth({MockUser? user}) => ErrorAuthMock(mockUser: user ?? defaultUser, code: 'wrong-password', message: 'Wrong password');
  static ErrorAuthMock userNotFoundAuth({MockUser? user}) => ErrorAuthMock(mockUser: user ?? defaultUser, code: 'user-not-found', message: 'No user found for that email');
  static ErrorAuthMock disabledAccountAuth({MockUser? user}) => ErrorAuthMock(mockUser: user ?? defaultUser, code: 'user-disabled', message: 'This user has been disabled');
  static ErrorAuthMock networkErrorAuth({MockUser? user}) => ErrorAuthMock(mockUser: user ?? defaultUser, code: 'network-request-failed', message: 'A network error occurred');
}

// Utility functions
void simulateLogin(MockFirebaseAuthWithSignedIn auth, AuthChangeNotifier notifier) {
  auth.signedIn = true;
  notifier.notifyListeners();
}

void simulateLogout(MockFirebaseAuthWithSignedIn auth, AuthChangeNotifier notifier) {
  auth.signedIn = false;
  notifier.notifyListeners();
}
