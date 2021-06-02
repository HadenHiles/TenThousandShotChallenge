import 'package:apple_sign_in/apple_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:password_strength/password_strength.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

Future<UserCredential> signInWithGoogle() async {
  // Trigger the authentication flow
  final GoogleSignInAccount googleUser = await GoogleSignIn().signIn();

  // Obtain the auth details from the request
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

  // Create a new credential
  final GoogleAuthCredential credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  // Once signed in, return the UserCredential
  return await auth.signInWithCredential(credential);
}

Future<UserCredential> signInWithApple({List<Scope> scopes = const []}) async {
  // 1. perform the sign-in request
  final result = await AppleSignIn.performRequests([AppleIdRequest(requestedScopes: scopes)]);
  // 2. check the result
  switch (result.status) {
    case AuthorizationStatus.authorized:
      final appleIdCredential = result.credential;
      final oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: String.fromCharCodes(appleIdCredential.identityToken),
        accessToken: String.fromCharCodes(appleIdCredential.authorizationCode),
      );
      return await auth.signInWithCredential(credential).then((authResult) async {
        if (scopes.contains(Scope.fullName)) {
          final displayName = '${appleIdCredential.fullName.givenName} ${appleIdCredential.fullName.familyName}';
          await authResult.user.updateProfile(displayName: displayName);
          authResult.user.reload();
        }

        return authResult;
      });
    case AuthorizationStatus.error:
      throw PlatformException(
        code: 'ERROR_AUTHORIZATION_DENIED',
        message: result.error.toString(),
      );

    case AuthorizationStatus.cancelled:
      throw PlatformException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign in aborted by user',
      );
    default:
      throw UnimplementedError();
  }
}

Future<void> signOut() async {
  await auth.signOut();
}

bool emailVerified() {
  auth.currentUser.reload();
  return auth.currentUser.emailVerified;
}

bool validEmail(String email) {
  return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
}

bool validPassword(String pass) {
  return estimatePasswordStrength(pass) > 0.7;
}

class AppleSignInAvailable {
  AppleSignInAvailable(this.isAvailable);
  final bool isAvailable;

  static Future<AppleSignInAvailable> check() async {
    return AppleSignInAvailable(await AppleSignIn.isAvailable());
  }
}
