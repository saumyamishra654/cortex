import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart' as window_manager;
import '../widgets/quick_fact_widget.dart';
import '../theme/app_theme.dart';
import '../models/fact.dart';
import '../services/storage_service.dart';

class MiniModeScreen extends StatefulWidget {
  final String windowId;
  final Map<String, dynamic>? arguments;

  const MiniModeScreen({
    super.key,
    required this.windowId,
    this.arguments,
  });

  @override
  State<MiniModeScreen> createState() => _MiniModeScreenState();
}

class _MiniModeScreenState extends State<MiniModeScreen> {
  String? _sourceId;
  String? _sourceName;
  bool _showQuoteOptions = true;
  WindowController? _controller;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  HiveStorageService? _storage;
  bool _isStorageReady = false;
  bool _isLoadingFacts = false;
  List<Fact> _facts = [];

  @override
  void initState() {
    super.initState();
    _ensureWindowManager();
    _initWindowController();
    _initStorage();
  }

  Future<void> _ensureWindowManager() async {
    try {
      await window_manager.windowManager.ensureInitialized();
    } catch (_) {
      // Ignore if window_manager is not available in this engine
    }
  }

  Future<void> _initWindowController() async {
    debugPrint('[MINI] Initializing Window Controller...');
    if (widget.arguments != null) {
      debugPrint('[MINI] Received arguments: ${widget.arguments}');
      setState(() {
        _sourceId = widget.arguments!['sourceId'] as String?;
        _sourceName = widget.arguments!['sourceName'] as String?;
        _showQuoteOptions = widget.arguments!['showQuoteOptions'] ?? true;
      });
    }

    _controller = await WindowController.fromCurrentEngine();
    debugPrint('[MINI] Controller initialized: $_controller');

    _controller?.setWindowMethodHandler((call) async {
      debugPrint('[MINI] Received method call: ${call.method}');
      if (call.method == 'updateSource') {
        final args = call.arguments as Map;
        debugPrint('[MINI] Updating source to: ${args['sourceId']} (${args['sourceName']})');
        if (mounted) {
          setState(() {
            _sourceId = args['sourceId'];
            _sourceName = args['sourceName'];
            _showQuoteOptions = args['showQuoteOptions'] ?? true;
          });
          _loadFacts();
        }
      }
      return null;
    });
  }

  Future<void> _initStorage() async {
    debugPrint('[MINI] Initializing Hive Storage...');
    final storage = HiveStorageService();
    try {
      await storage.init();
      debugPrint('[MINI] Hive Storage initialized.');
      if (!mounted) return;
      setState(() {
        _storage = storage;
        _isStorageReady = true;
      });
      await _loadFacts();
    } catch (e) {
      debugPrint('[MINI] ERROR initializing storage: $e');
    }
  }

  Future<void> _loadFacts() async {
    if (!_isStorageReady || _storage == null) {
      debugPrint('[MINI] LoadFacts aborted: Storage not ready.');
      return;
    }
    
    if (_sourceId == null) {
      debugPrint('[MINI] LoadFacts: No active source ID.');
      if (mounted) {
        setState(() {
          _facts = [];
          _isLoadingFacts = false;
        });
      }
      return;
    }

    debugPrint('[MINI] Loading facts for source: $_sourceId');
    setState(() => _isLoadingFacts = true);
    try {
      final facts = await _storage!.getFactsBySource(_sourceId!);
      debugPrint('[MINI] Found ${facts.length} facts for source.');
      facts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _facts = facts;
          _isLoadingFacts = false;
        });
      }
    } catch (e) {
      debugPrint('[MINI] ERROR loading facts: $e');
      if (mounted) {
        setState(() => _isLoadingFacts = false);
      }
    }
  }

  Future<void> _saveFact({
    required String content,
    String? quote,
    int? pageNumber,
    List<String>? subjects,
  }) async {
    debugPrint('[MINI] _saveFact called. Content length: ${content.length}');
    if (_controller == null) {
      debugPrint('[MINI] ERROR: WindowController is null, cannot invoke saveFact');
      return;
    }
    
    if (_sourceId == null) {
      debugPrint('[MINI] ERROR: _sourceId is null, cannot save fact');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('No active source to save to')),
      );
      return;
    }

    debugPrint('[MINI] Invoking saveFact on main engine. Source: $_sourceId');
    try {
      final success = await _controller!.invokeMethod('saveFact', {
        'content': content,
        'quote': quote,
        'pageNumber': pageNumber,
        'sourceId': _sourceId,
        'subjects': subjects,
      });
      debugPrint('[MINI] saveFact invoke result: $success');

      if (success == true) {
        debugPrint('[MINI] Save successful, refreshing list...');
        await _loadFacts();
      } else {
        debugPrint('[MINI] saveFact returned false (failed)');
      }

      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(success == true ? 'Fact saved' : 'Failed to save fact'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[MINI] CRITICAL ERROR during invokeMethod(saveFact): $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: ScaffoldMessenger(
        key: _scaffoldMessengerKey,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.psychology, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _sourceName ?? 'Mini Cortex',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => window_manager.windowManager.close(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: _sourceId == null
                              ? Center(
                                  child: Text(
                                    'No active source',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                )
                              : Column(
                                  children: [
                                    QuickFactWidget(
                                      sourceId: _sourceId!,
                                      showQuoteOptions: _showQuoteOptions,
                                      isMiniMode: true,
                                      onSave: ({required content, quote, pageNumber, subjects}) =>
                                          _saveFact(
                                        content: content,
                                        quote: quote,
                                        pageNumber: pageNumber,
                                        subjects: subjects,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: _buildRecentFacts(theme),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFacts(ThemeData theme) {
    if (_isLoadingFacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_facts.isEmpty) {
      return Center(
        child: Text(
          'No saved facts yet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final recentFacts = _facts.take(20).toList();

    return ListView.separated(
      itemCount: recentFacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fact = recentFacts[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fact.displayText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              if (fact.quote != null && fact.quote!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '“${fact.quote}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (fact.subjects.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: fact.subjects.take(4).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$tag',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
