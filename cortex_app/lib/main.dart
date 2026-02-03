import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/data_provider.dart';
import 'services/storage_service.dart';
import 'services/firebase_service.dart';
import 'services/deep_link_service.dart';
import 'services/automation_service.dart';
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

import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart' as window_manager;
import 'screens/mini_mode_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (args.firstOrNull == 'multi_window') {
    final windowId = args[1];
    final arguments = args.length > 2 ? jsonDecode(args[2]) as Map<String, dynamic> : null;
    runApp(MiniModeScreen(windowId: windowId, arguments: arguments));
  } else {
    // Initialize window_manager only for main window
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      await window_manager.windowManager.ensureInitialized();
    }
    runApp(const CortexApp());
  }
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
        // Store for after auth (memory only!)
        _pendingCapture = initialCapture;
      }
    }
    
    // If signed in, start Firebase listeners
    if (FirebaseService.isSignedIn) {
      _dataProvider.startFirebaseListeners();
    }

    // Automatic macOS Automation Setup (First run only)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      _setupMacosAutomation();
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
          });
        }
      } else {
        setState(() => _showAuth = true);
        _dataProvider.stopFirebaseListeners();
      }
    });

    // Handle messages from Mini Mode window
    WindowController.fromCurrentEngine().then((controller) {
      controller.setWindowMethodHandler((call) async {
        debugPrint('--- [MAIN APP] UI Handler: ${call.method} ---');
        if (call.method == 'saveFact') {
          final args = call.arguments as Map;
          debugPrint('[MAIN APP] Saving fact from mini window. SourceID: ${args['sourceId']}');
          try {
            if (args['content'] == null || args['content'].toString().trim().isEmpty) {
              debugPrint('[MAIN APP] Warning: Received empty content for fact');
            }
            
            await _dataProvider.addFact(
              content: args['content'] ?? 'Quick Note',
              sourceId: args['sourceId'],
              quote: args['quote'],
              pageNumber: args['pageNumber'],
              subjects: args['subjects'] != null ? List<String>.from(args['subjects']) : null,
            );
            debugPrint('[MAIN APP] Fact saved successfully via DataProvider');
            return true; // Return success to mini window
          } catch (e, stack) {
            debugPrint('[MAIN APP] ERROR saving fact from mini window: $e');
            debugPrint('[MAIN APP] Stacktrace: $stack');
            return false;
          }
        }
        return null;
      });
    });
    
    // Listen to DataProvider active source changes to update Mini Window?
    // DataProvider doesn't easily expose "listener" for specific field changes here without attaching a listener manualy.
    // We can add a listener to _dataProvider.
    _dataProvider.addListener(_syncActiveSourceToMiniWindow);

    setState(() => _isInitializing = false);
  }

  void _syncActiveSourceToMiniWindow() async {
    final activeId = _dataProvider.activeSourceId;
    if (activeId != null) {
      final source = _dataProvider.getSourceById(activeId);
      if (source != null) {
        // Broadcast to all sub-windows
        final windows = await WindowController.getAll();
        for (final window in windows) {
          if (window.windowId == '0') continue;
          await window.invokeMethod('updateSource', {
            'sourceId': activeId,
            'sourceName': source.name,
            'showQuoteOptions': source.filePath != null,
          });
        }
      }
    } else {
      // Clear mini window source
      final windows = await WindowController.getAll();
      for (final window in windows) {
        if (window.windowId == '0') continue;
        await window.invokeMethod('updateSource', {
          'sourceId': null,
          'sourceName': null,
          'showQuoteOptions': false,
        });
      }
    }
  }

  Future<void> _setupMacosAutomation() async {
    final prefs = await SharedPreferences.getInstance();
    final isInstalled = prefs.getBool('macos_service_installed_v1') ?? false;

    if (!isInstalled) {
      debugPrint('Main: First launch on macOS. Running automatic service installation...');
      // Run silently in background
      final result = await AutomationService.installMacosService();
      if (result.success) {
        debugPrint('Main: Automatic service installation successful.');
        await prefs.setBool('macos_service_installed_v1', true);
      } else {
        debugPrint('Main: Automatic service installation failed: ${result.error}');
      }
    }
  }
  
  void _handleCaptureRequest(CaptureRequest request) {
    if (!mounted) return;
    
    if (FirebaseService.isSignedIn) {
      final activeSourceId = _dataProvider.activeSourceId; // Updated to universal source ID
      
      // If silent is requested OR it allows auto-save
      // We prioritize silent auto-save if an active session exists.
      // Or if the request specifically targets the active source (future improvement).
      
      bool shouldAutoSave = false;
      
      if (activeSourceId != null) {
        // If we have an active source, and the request is silent, we assume it's for this source.
        // OR if it's a "pdf" type request (legacy logic).
        final isPdfApp = request.suggestedType == SourceType.document || 
                        _isPdfAppRequest(request);
        
        if (request.isSilent || isPdfApp) {
          shouldAutoSave = true;
        }
      }

      if (shouldAutoSave && activeSourceId != null) {
        _autoSaveToActiveSession(request, activeSourceId);
      } else {
        if (request.isSilent) {
           // Silent request but no active source to save to?
           // For now, we unfortunately must show the dialog or fail.
           // Let's show dialog but maybe minimal? 
           // Standard behavior: Fallback to dialog.
           _showCaptureDialog(request);
        } else {
           _showCaptureDialog(request);
        }
      }
    } else {
      _pendingCapture = request;
    }
  }

  bool _isPdfAppRequest(CaptureRequest request) {
    // Check if the URL is empty (often true for PDF expert logs) 
    // or if the suggests type is document
    return request.sourceUrl == null || request.sourceUrl!.isEmpty;
  }

  Future<void> _autoSaveToActiveSession(CaptureRequest request, String sourceId) async {
    try {
      await _dataProvider.addFact(
        content: request.text, // Text is now Thought
        quote: request.quote,
        pageNumber: request.pageNumber,
        sourceId: sourceId,
        url: request.sourceUrl,
      );
      
      if (mounted) {
        // Only show snackbar if NOT silent? 
        // User asked for "streaming... without app aggressively popping to front".
        // Keep snackbar if window is visible, but don't force window focus (we can't control focus easily here anyway).
        if (!request.isSilent) {
          final context = _navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Fact captured to active session')),
                  ],
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error in auto-save: $e');
      if (mounted && !request.isSilent) _showCaptureDialog(request);
    }
  }
  
  void _showCaptureDialog(CaptureRequest request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        // We might want to pass the new fields to CaptureDialog too
        CaptureDialog.show(context, request);
      }
    });
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
