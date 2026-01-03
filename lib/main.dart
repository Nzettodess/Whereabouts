import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'home.dart';

// Global analytics instance for use throughout the app
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env file might not exist in production/web builds
    debugPrint("Note: .env file not found. Relying on --dart-define variables.");
  }
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firebase App Check for API Security with Resilience
  // Debug mode is enabled via FIREBASE_APPCHECK_DEBUG_TOKEN in index.html (for localhost only)
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('6LecyDcsAAAAAH1E16_m85mrrAodiAdM9nWWfGRu'),
    );
    debugPrint("Firebase App Check initialized");
  } catch (e) {
    debugPrint("Warning: Firebase App Check failed to initialize (possibly blocked): $e");
  }

  // Enable Firebase Performance Monitoring
  try {
    FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
  } catch (e) {
    debugPrint("Warning: Firebase Performance Monitoring failed to initialize: $e");
  }

  // Enable Firebase Analytics
  try {
    await analytics.setAnalyticsCollectionEnabled(true);
  } catch (e) {
    debugPrint("Warning: Firebase Analytics failed to initialize: $e");
  }

  // Enable offline persistence with 15MB cache for PWA support
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 15 * 1024 * 1024, // 15MB
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  double _textScaleFactor = 1.0; // Default text scale (1.0 = 100%)
  StreamSubscription? _userSubscription;

  @override
  void initState() {
    super.initState();
    _listenToThemeChanges();
  }

  void _listenToThemeChanges() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _userSubscription?.cancel();
      if (user != null) {
        _userSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data();
            final mode = data?['themeMode'] as String?;
            final textScale = data?['textScaleFactor'] as double?;
            print('[Main] Received user update. ThemeMode: $mode, TextScale: $textScale');
            
            setState(() {
              // Update theme mode
              if (mode != null) {
                switch (mode) {
                  case 'light':
                    _themeMode = ThemeMode.light;
                    break;
                  case 'dark':
                    _themeMode = ThemeMode.dark;
                    break;
                  default:
                    _themeMode = ThemeMode.system;
                }
              }
              
              // Update text scale factor (clamped between 0.8 and 1.5)
              if (textScale != null) {
                _textScaleFactor = textScale.clamp(0.8, 1.5);
              }
            });
          }
        }, onError: (e) => print('[Main] Error listening to user: $e'));
      } else {
        setState(() {
          _themeMode = ThemeMode.system;
          _textScaleFactor = 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      builder: (context, child) {
        // Apply custom text scale factor for accessibility
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_textScaleFactor),
          ),
          child: child!,
        );
      },
      home: const HomeWithLogin(),
    );
  }
}

