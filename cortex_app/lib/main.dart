import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/data_provider.dart';
import 'services/storage_service.dart';
import 'services/firebase_service.dart';
import 'services/deep_link_service.dart';
import 'models/source.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/review_screen.dart';
import 'screens/graph_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/capture_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Run app immediately - initialization happens in background
  runApp(const CortexApp());
}

class CortexApp extends StatefulWidget {
  const CortexApp({super.key});

  @override
  State<CortexApp> createState() => _CortexAppState();
}

class _CortexAppState extends State<CortexApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _showAuth = true;
  bool _isInitializing = true;
  
  late final HiveStorageService _storage;
  late final DataProvider _dataProvider;
  late final DeepLinkService _deepLinkService;
  
  // Pending capture request (waiting for auth)
  CaptureRequest? _pendingCapture;
  
  // Navigator key for showing dialogs
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();


  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize services in background
    await FirebaseService.init();
    
    _storage = HiveStorageService();
    await _storage.init();
    
    _dataProvider = DataProvider(_storage);
    await _dataProvider.init();
    
    // Initialize deep link service
    _deepLinkService = DeepLinkService();
    final initialCapture = await _deepLinkService.init();
    
    // Listen for capture requests
    _deepLinkService.captureStream.listen(_handleCaptureRequest);
    
    // Check auth state
    _showAuth = !FirebaseService.isSignedIn;
    
    // Handle initial capture (app opened via deep link)
    if (initialCapture != null) {
      if (FirebaseService.isSignedIn) {
        // Show dialog after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCaptureDialog(initialCapture);
        });
      } else {
        // Store for after auth
        _pendingCapture = initialCapture;
        await _savePendingCapture(initialCapture);
      }
    } else {
      // Check for pending capture from previous session
      await _loadPendingCapture();
    }
    
    // If signed in, start Firebase listeners
    if (FirebaseService.isSignedIn) {
      _dataProvider.startFirebaseListeners();
    }
    
    // Listen to future auth changes
    FirebaseService.authStateChanges.listen((user) {
      if (!mounted) return;
      if (user != null) {
        setState(() => _showAuth = false);
        _dataProvider.startFirebaseListeners();
        // Show pending capture after auth
        if (_pendingCapture != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showCaptureDialog(_pendingCapture!);
            _pendingCapture = null;
            _clearPendingCapture();
          });
        }
      } else {
        setState(() => _showAuth = true);
        _dataProvider.stopFirebaseListeners();
      }
    });
    
    setState(() => _isInitializing = false);
  }
  
  void _handleCaptureRequest(CaptureRequest request) {
    if (!mounted) return;
    
    if (FirebaseService.isSignedIn) {
      _showCaptureDialog(request);
    } else {
      _pendingCapture = request;
      _savePendingCapture(request);
    }
  }
  
  void _showCaptureDialog(CaptureRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        CaptureDialog.show(context, request);
      }
    });
  }
  
  Future<void> _savePendingCapture(CaptureRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_capture_text', request.text);
    if (request.sourceUrl != null) {
      await prefs.setString('pending_capture_url', request.sourceUrl!);
    }
    if (request.sourceTitle != null) {
      await prefs.setString('pending_capture_title', request.sourceTitle!);
    }
    await prefs.setString('pending_capture_type', request.suggestedType.name);
  }
  
  Future<void> _loadPendingCapture() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString('pending_capture_text');
    if (text != null && text.isNotEmpty && FirebaseService.isSignedIn) {
      _pendingCapture = CaptureRequest(
        text: text,
        sourceUrl: prefs.getString('pending_capture_url'),
        sourceTitle: prefs.getString('pending_capture_title'),
        suggestedType: _parseSourceType(prefs.getString('pending_capture_type')),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCaptureDialog(_pendingCapture!);
        _pendingCapture = null;
        _clearPendingCapture();
      });
    }
  }
  
  SourceType _parseSourceType(String? name) {
    if (name == null) return SourceType.other;
    return SourceType.values.firstWhere(
      (t) => t.name == name,
      orElse: () => SourceType.other,
    );
  }
  
  Future<void> _clearPendingCapture() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_capture_text');
    await prefs.remove('pending_capture_url');
    await prefs.remove('pending_capture_title');
    await prefs.remove('pending_capture_type');
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
    // Show splash while initializing
    if (_isInitializing) {
      return MaterialApp(
        title: 'Cortex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: const SplashScreen(),
      );
    }
    
    // Wrap with Provider once DataProvider is ready
    return ChangeNotifierProvider.value(
      value: _dataProvider,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Cortex',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        home: _showAuth
            ? AuthScreen(onSignedIn: () => setState(() => _showAuth = false))
            : MainNavigation(
                isDarkMode: _isDarkMode,
                onToggleTheme: _toggleTheme,
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
