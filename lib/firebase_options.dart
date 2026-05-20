// IMPORTANT: This file contains placeholder values.
// Replace all 'YOUR_...' values with your actual Firebase project configuration.
//
// Steps to get real values:
//   1. Create a Firebase project at https://console.firebase.google.com
//   2. Install FlutterFire CLI:  dart pub global activate flutterfire_cli
//   3. Run in this project:       flutterfire configure
//   4. That command will overwrite this file with real credentials.
//
// Alternatively, copy values manually from your Firebase project settings.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAE4Q_xovSfiDWC9RJ0OiM-RlqcG2Qdqdo',
    appId: '1:958405383066:web:badef831f9a873be676023',
    messagingSenderId: '958405383066',
    projectId: 'lineskip-9ac91',
    authDomain: 'lineskip-9ac91.firebaseapp.com',
    storageBucket: 'lineskip-9ac91.firebasestorage.app',
    measurementId: 'G-R5H0BJ6746',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAw8561RjMY3tliWQDuUdYUcO99cGAnShA',
    appId: '1:958405383066:android:12e5c45c7d6995d3676023',
    messagingSenderId: '958405383066',
    projectId: 'lineskip-9ac91',
    storageBucket: 'lineskip-9ac91.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA4kmi5A4en7hzml80tQSnUU6PGlGCzoAg',
    appId: '1:958405383066:ios:7355f8a006e439e5676023',
    messagingSenderId: '958405383066',
    projectId: 'lineskip-9ac91',
    storageBucket: 'lineskip-9ac91.firebasestorage.app',
    iosBundleId: 'com.lineskip.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
    iosBundleId: 'com.example.nolineSkip',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WINDOWS_API_KEY',
    appId: 'YOUR_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );
}