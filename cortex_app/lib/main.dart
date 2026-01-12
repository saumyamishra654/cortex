import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/data_provider.dart';
import 'services/storage_service.dart';
import 'services/firebase_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/review_screen.dart';
import 'screens/graph_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await FirebaseService.init();

  // Initialize local storage
  final storage = HiveStorageService();
  await storage.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => DataProvider(storage)..init(),
      child: const CortexApp(),
    ),
  );
}

class CortexApp extends StatefulWidget {
  const CortexApp({super.key});

  @override
  State<CortexApp> createState() => _CortexAppState();
}

class _CortexAppState extends State<CortexApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _showAuth = true;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();

    // Listen to auth changes
    FirebaseService.authStateChanges.listen((user) {
      if (user != null) {
        setState(() => _showAuth = false);
        // Use post-frame callback to access context safely
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onUserSignedIn();
        });
      } else {
        setState(() => _showAuth = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onUserSignedOut();
        });
      }
    });
  }

  void _checkAuthState() {
    setState(() {
      _showAuth = !FirebaseService.isSignedIn;
      _isCheckingAuth = false;
    });

    // If signed in, start listening to Firebase (use post-frame callback)
    if (FirebaseService.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onUserSignedIn();
      });
    }
  }

  void _onUserSignedIn() {
    debugPrint('User signed in: ${FirebaseService.currentUser?.email}');
    debugPrint('User ID: ${FirebaseService.userId}');

    // Start Firebase real-time listeners in DataProvider
    if (mounted) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.startFirebaseListeners();
    }
  }

  void _onUserSignedOut() {
    debugPrint('User signed out');

    // Stop Firebase listeners
    if (mounted) {
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.stopFirebaseListeners();
    }
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.light) {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.light;
      }
    });
  }

  bool get _isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cortex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _isCheckingAuth
          ? const _SplashScreen()
          : _showAuth
          ? AuthScreen(onSignedIn: () => setState(() => _showAuth = false))
          : MainNavigation(
              isDarkMode: _isDarkMode,
              onToggleTheme: _toggleTheme,
            ),
    );
  }
}

/// Branded splash screen shown during initialization
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F9FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hub_rounded,
              size: 80,
              color: isDark ? Colors.white70 : const Color(0xFF6C63FF),
            ),
            const SizedBox(height: 24),
            Text(
              'Cortex',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF2D3436),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Knowledge Network',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.white54 : const Color(0xFF6C63FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainNavigation({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const ReviewScreen(),
          const GraphScreen(),
          const CollectionsScreen(),
          SettingsScreen(
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.flip_rounded),
            selectedIcon: Icon(Icons.flip),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_rounded),
            selectedIcon: Icon(Icons.hub),
            label: 'Graph',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_rounded),
            selectedIcon: Icon(Icons.collections_bookmark),
            label: 'Collections',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
