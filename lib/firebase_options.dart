// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDjFWCxIm9PAS_X02H4tuB6pAueJ96hVug',
    appId: '1:767649510191:android:56275d208ee7f3eb07a7da',
    messagingSenderId: '767649510191',
    projectId: 'ten-thousand-puck-challenge',
    storageBucket: 'ten-thousand-puck-challenge.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBJKvi75HqrrhoTdbi9B9BIktHiJq_HwVs',
    appId: '1:767649510191:ios:5a4c6794939fd50407a7da',
    messagingSenderId: '767649510191',
    projectId: 'ten-thousand-puck-challenge',
    storageBucket: 'ten-thousand-puck-challenge.appspot.com',
    androidClientId: '767649510191-5l35q1ohi7mae12na45fmr670nalilm8.apps.googleusercontent.com',
    iosClientId: '767649510191-97sumh7rc5jaj2d9d0a7h4ia5hc6dnrd.apps.googleusercontent.com',
    iosBundleId: 'com.howtohockey.tenthousandshotchallenge',
  );
}