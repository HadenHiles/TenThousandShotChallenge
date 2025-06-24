// Example usage for google_sign_in 7.x
// This is a reference for updating your signInWithGoogle function
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

Future<UserCredential> signInWithGoogle() async {
  // Use the singleton instance
  final GoogleSignIn signIn = GoogleSignIn.instance;

  // Optionally, initialize with clientId/serverClientId if needed
  // await signIn.initialize(clientId: ..., serverClientId: ...);

  try {
    // Start the sign-in flow
    final bool supportsAuth = signIn.supportsAuthenticate();
    if (supportsAuth) {
      await signIn.authenticate();
    } else {
      // For web, use the rendered button or fallback
      throw PlatformException(
        code: 'ERROR_UNSUPPORTED_PLATFORM',
        message: 'GoogleSignIn.authenticate() not supported on this platform.',
      );
    }

    final GoogleSignInAccount? googleUser = signIn.currentUser;
    if (googleUser == null) {
      throw PlatformException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign in aborted by user',
      );
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await auth.signInWithCredential(credential);
  } catch (e) {
    throw PlatformException(
      code: 'ERROR_GOOGLE_SIGN_IN_FAILED',
      message: e.toString(),
    );
  }
}
