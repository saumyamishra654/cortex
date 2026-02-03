import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';
import '../widgets/fact_card.dart';
import 'add_source_screen.dart';
import 'edit_fact_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/quick_fact_widget.dart';
import '../services/macos_bookmark_service.dart';

class SourceDetailScreen extends StatefulWidget {
  final Source source;

  const SourceDetailScreen({
    super.key,
    required this.source,
  });

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  late final DataProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<DataProvider>();
    // Start session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.setActiveSource(widget.source.id);
    });
  }

  @override
  void dispose() {
    // Stop session when leaving
    _provider.clearActiveSource();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    
    // Get the latest source data (in case it was updated)
    final currentSource = provider.sources.cast<Source?>().firstWhere(
      (s) => s?.id == widget.source.id,
      orElse: () => widget.source,
    )!;
    
    final isSessionActive = provider.activeSourceId == currentSource.id;
    
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          debugPrint('🏠 SourceDetailScreen popped, clearing active source');
          provider.clearActiveSource();
        }
      },
      child: Scaffold(
        appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentSource.name),
            if (isSessionActive)
              Text(
                'Active Session',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        actions: [
          // Detach / Mini Window
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt_rounded),
            tooltip: 'Open Mini Cortex',
            onPressed: () async {
              try {
                final window = await WindowController.create(WindowConfiguration(
                  arguments: jsonEncode({
                    'sourceId': currentSource.id,
                    'sourceName': currentSource.name,
                    'showQuoteOptions': currentSource.filePath != null,
                  }),
                ));
                
                await window.show();
                
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mini Cortex opened')),
                  );
                }
              } catch (e) {
                debugPrint('Error creating window: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not open window: $e')),
                  );
                }
              }
            },
          ),
          if (currentSource.filePath != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Open PDF',
              onPressed: () => _openPdf(currentSource.filePath!),
            ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Source',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddSourceScreen(source: currentSource),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(context, currentSource);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded),
                    SizedBox(width: 8),
                    Text('Delete Source'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          final facts = provider.getFactsForSource(currentSource.id);
          
          return Column(
            children: [
              QuickFactWidget(
                sourceId: currentSource.id,
                showQuoteOptions: currentSource.filePath != null,
              ),
              Expanded(
                child: facts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_rounded,
                              size: 60,
                              color: theme.colorScheme.primary.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No facts yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 40),
                        itemCount: facts.length,
                        itemBuilder: (context, index) {
                          // Show newest first? Usually lists are appended. 
                          // If we want reverse chronological, we should sort or reverse here.
                          // For now, let's keep list order (insertion order typically).
                          final fact = facts[facts.length - 1 - index]; // Reverse order
                          return Dismissible(
                            key: Key(fact.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: theme.colorScheme.error,
                              child: const Icon(
                                Icons.delete_rounded,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Fact?'),
                                  content: const Text('This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: theme.colorScheme.error,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) {
                              provider.deleteFact(fact.id);
                            },
                            child: FactCard(
                              fact: fact,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditFactScreen(fact: fact),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      // Floating action button removed in favor of QuickFactWidget
    ),
  );
}

  Future<void> _openPdf(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkKey = 'pdfBookmark_${widget.source.id}';
    final storedBookmark = prefs.getString(bookmarkKey);

    String resolvedPath = path;
    String? activeBookmark = storedBookmark;

    if (Platform.isMacOS && storedBookmark != null) {
      final resolved = await MacosBookmarkService.resolveBookmark(storedBookmark);
      if (resolved != null) {
        resolvedPath = resolved.path;
        if (resolved.isStale) {
          final refreshed = await MacosBookmarkService.createBookmark(resolved.path);
          if (refreshed != null) {
            await prefs.setString(bookmarkKey, refreshed);
            activeBookmark = refreshed;
          }
        }
      }
    }

    final uri = Uri.file(resolvedPath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (Platform.isMacOS && activeBookmark != null) {
        await MacosBookmarkService.stopAccessing(activeBookmark);
      }
      if (mounted) {
        context.read<DataProvider>().setActiveSource(widget.source.id);
      }
      return;
    }

    // Fallback: prompt user to re-select PDF and store a new bookmark
    if (Platform.isMacOS) {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      final newPath = picked?.files.single.path;
      if (newPath != null) {
        final newBookmark = await MacosBookmarkService.createBookmark(newPath);
        if (newBookmark != null) {
          await prefs.setString(bookmarkKey, newBookmark);
        }

        widget.source.filePath = newPath;
        await context.read<DataProvider>().updateSource(widget.source);

        final newUri = Uri.file(newPath);
        if (await canLaunchUrl(newUri)) {
          await launchUrl(newUri);
        }
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open PDF: $path')),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, Source source) {
    final provider = context.read<DataProvider>();
    final factCount = provider.getFactCountForSource(source.id);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Source?'),
        content: Text(
          'This will delete "${source.name}" and all $factCount facts. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSource(source.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
