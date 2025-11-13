import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Screens
import 'screens/auth/login.dart';
import 'screens/auth/register.dart';
import 'screens/fisherman/dashboard.dart';
import 'screens/buyer/map_view.dart';

// Models
import 'models/user_model.dart';

// Services
import 'services/auth_service.dart';

// Utils - removed non-existent imports

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    runApp(const FishOnApp());
  } catch (e) {
    // Handle Firebase initialization errors
    runApp(const FirebaseErrorApp());
  }
}

class FirebaseErrorApp extends StatelessWidget {
  const FirebaseErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Firebase initialization failed. Please restart the app.'),
        ),
      ),
    );
  }
}

class FishOnApp extends StatelessWidget {
  const FishOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        // Add more providers as needed
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const LoginScreen(),
        onGenerateRoute: AppRoutes.generateRoute,
        navigatorObservers: [AppNavigatorObserver()],
      ),
    );
  }
}

// Separate constants
class AppConstants {
  static const String appName = 'FishOn';
  static const double defaultButtonHeight = 48.0;
  static const EdgeInsets defaultContentPadding = 
      EdgeInsets.symmetric(horizontal: 12, vertical: 14);
}

// Separate theme configuration
class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.lightBlue,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Color(0xFFE3F2FD),
      foregroundColor: Color(0xFF0D47A1),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5FAFF),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: AppConstants.defaultContentPadding,
      filled: true,
      fillColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppConstants.defaultButtonHeight),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF0D47A1),
      ),
    ),
    switchTheme: const SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(Color(0xFF42A5F5)),
      trackColor: WidgetStatePropertyAll(Color(0xFFBBDEFB)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.lightBlue,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0B111A),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: AppConstants.defaultContentPadding,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppConstants.defaultButtonHeight),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        backgroundColor: Color(0xFF2196F3),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

// Separate route management
class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String fishermanDashboard = '/fishermanDashboard';
  static const String buyerDashboard = '/buyerDashboard';
  static const String buyerMap = '/buyerMap';
  static const String splash = '/splash';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case fishermanDashboard:
        final args = settings.arguments as Map<String, dynamic>?;
        print('Fisherman dashboard route args: $args'); // Debug print
        try {
          AppUser? user;
          if (args != null) {
            user = AppUser.fromMap(args);
            print('Created AppUser: ${user.name}, ${user.uid}'); // Debug print
          }
          return MaterialPageRoute(
            builder: (_) => FishermanDashboard(initialUser: user),
          );
        } catch (e) {
          print('Error creating AppUser: $e'); // Debug print
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error loading dashboard: $e'),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      case buyerMap:
        return MaterialPageRoute(builder: (_) => const MapViewScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

// Navigation observer for analytics or logging
class AppNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Add analytics or logging here
    debugPrint('Navigated to: ${route.settings.name}');
  }
}