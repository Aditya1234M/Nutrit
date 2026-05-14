import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/meal_provider.dart';
import 'providers/profile_provider.dart';
import 'services/ml_service.dart';
import 'screens/main_navigation.dart';
import 'screens/goals/body_parameters_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ML service (loads TFLite model when available)
  await MlService.init();

  runApp(const NutritAIApp());
}

class NutritAIApp extends StatelessWidget {
  const NutritAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2D6A4F),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FBF9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFF1B4332),
            centerTitle: false,
            elevation: 0,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            selectedItemColor: Color(0xFF2D6A4F),
            unselectedItemColor: Color(0xFFB7B7B7),
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            color: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

/// Entry widget — auto-creates guest session, skips login screen.
/// Google Auth will be added later for deployment.
class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _loading = true;
  bool _needsOnboarding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final auth = context.read<AuthProvider>();

    // Step 1: Try existing session
    final loggedIn = await auth.tryAutoLogin();

    if (loggedIn) {
      // Existing session — load data and go to main screen
      if (mounted) {
        final profile = context.read<ProfileProvider>();
        await profile.loadAll();
        context.read<MealProvider>().refreshAll();

        // Check if profile is set up (has weight/height)
        _needsOnboarding = !profile.hasProfile;
      }
    } else {
      // No session — auto-create a guest account
      final success = await auth.signup(
        'Guest User',
        'guest_${DateTime.now().millisecondsSinceEpoch}@nutritai.local',
        'guest_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (success) {
        _needsOnboarding = true; // New user needs to set up profile
      } else {
        // Backend might be down
        _error = auth.error;
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FBF9),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF2D6A4F)),
              const SizedBox(height: 16),
              Text(
                'Setting up NutritAI...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FBF9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Could not connect to backend',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _initSession();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // New user → body parameters setup, returning user → main screen
    return _needsOnboarding
        ? const BodyParametersScreen()
        : const MainNavigation();
  }
}
