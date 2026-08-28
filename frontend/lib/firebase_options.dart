// File generated for Firebase project sukaseafood-654b7.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
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
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCaKoDUrdII2cU5ud8Fa1o7gacIGwjh9rQ',
    appId: '1:147789152548:web:7dbc780d8d43abc02873b1',
    messagingSenderId: '147789152548',
    projectId: 'sukaseafood-654b7',
    authDomain: 'sukaseafood-654b7.firebaseapp.com',
    storageBucket: 'sukaseafood-654b7.firebasestorage.app',
    measurementId: 'G-YVT7R9PWLK',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDYNFULPc4h3GeDIne3Sb17uAQcTElk5O0',
    appId: '1:147789152548:android:ad0f6836a64509c52873b1',
    messagingSenderId: '147789152548',
    projectId: 'sukaseafood-654b7',
    storageBucket: 'sukaseafood-654b7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCDdnUP2UdU7yWNy4lF9LwydNDRwXBOofg',
    appId: '1:147789152548:ios:57d87cbf9380f6b72873b1',
    messagingSenderId: '147789152548',
    projectId: 'sukaseafood-654b7',
    storageBucket: 'sukaseafood-654b7.firebasestorage.app',
    iosBundleId: 'my.sukaseafood.sukaseafood',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCDdnUP2UdU7yWNy4lF9LwydNDRwXBOofg',
    appId: '1:147789152548:ios:57d87cbf9380f6b72873b1',
    messagingSenderId: '147789152548',
    projectId: 'sukaseafood-654b7',
    storageBucket: 'sukaseafood-654b7.firebasestorage.app',
    iosBundleId: 'my.sukaseafood.sukaseafood',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCaKoDUrdII2cU5ud8Fa1o7gacIGwjh9rQ',
    appId: '1:147789152548:web:7dbc780d8d43abc02873b1',
    messagingSenderId: '147789152548',
    projectId: 'sukaseafood-654b7',
    authDomain: 'sukaseafood-654b7.firebaseapp.com',
    storageBucket: 'sukaseafood-654b7.firebasestorage.app',
    measurementId: 'G-YVT7R9PWLK',
  );
}
