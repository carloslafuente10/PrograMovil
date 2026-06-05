
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;// Proporciona la configuración necesaria para inicializar Firebase.
import 'package:flutter/foundation.dart'// Permite identificar la plataforma donde se ejecuta la aplicación.
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
// Contiene la configuración de Firebase para cada plataforma soportada.
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
// Configuración de Firebase para la versión web de la aplicación.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC-Gx4iSSCZIuuGBXRUvDTYII36E-B3jXA',
    appId: '1:260063702751:web:8600b6e110469c867ac36a',
    messagingSenderId: '260063702751',
    projectId: 'app-recetas-e5f12',
    authDomain: 'app-recetas-e5f12.firebaseapp.com',
    storageBucket: 'app-recetas-e5f12.firebasestorage.app',
    measurementId: 'G-M2BFTZKKTJ',
  );
// Configuración de Firebase para dispositivos Android.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAtAz5Qtz8Qgx25rlAFe2dqO5z4dGlHLyA',
    appId: '1:260063702751:android:2b54b7fd6526c29d7ac36a',
    messagingSenderId: '260063702751',
    projectId: 'app-recetas-e5f12',
    storageBucket: 'app-recetas-e5f12.firebasestorage.app',
  );
// Configuración de Firebase para dispositivos iOS.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDvFQbFGM57PqC-ASEDBbDNyxUUNnSeoSA',
    appId: '1:260063702751:ios:1382acf4cd12cfe57ac36a',
    messagingSenderId: '260063702751',
    projectId: 'app-recetas-e5f12',
    storageBucket: 'app-recetas-e5f12.firebasestorage.app',
    iosBundleId: 'com.example.programovil',
  );
// Configuración de Firebase para macOS.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDvFQbFGM57PqC-ASEDBbDNyxUUNnSeoSA',
    appId: '1:260063702751:ios:1382acf4cd12cfe57ac36a',
    messagingSenderId: '260063702751',
    projectId: 'app-recetas-e5f12',
    storageBucket: 'app-recetas-e5f12.firebasestorage.app',
    iosBundleId: 'com.example.programovil',
  );
// Configuración de Firebase para Windows.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC-Gx4iSSCZIuuGBXRUvDTYII36E-B3jXA',
    appId: '1:260063702751:web:26ea5d95d88760747ac36a',
    messagingSenderId: '260063702751',
    projectId: 'app-recetas-e5f12',
    authDomain: 'app-recetas-e5f12.firebaseapp.com',
    storageBucket: 'app-recetas-e5f12.firebasestorage.app',
    measurementId: 'G-TBRKKJ51HV',
  );
}
