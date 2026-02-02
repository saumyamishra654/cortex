import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../widgets/source_card.dart';
import '../models/source.dart';
import 'source_detail_screen.dart';
import 'add_source_screen.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.psychology_rounded,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              'Cortex',
              style: theme.appBarTheme.titleTextStyle,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (details) => setState(() => _isDragging = true),
        onDragExited: (details) => setState(() => _isDragging = false),
        onDragDone: (details) => _handleFileDrop(context, details.files),
        child: Container(
          color: _isDragging 
              ? theme.colorScheme.primaryContainer.withOpacity(0.3) 
              : Colors.transparent,
          child: Stack(
            children: [
              Consumer<DataProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (provider.sources.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.library_books_rounded,
                            size: 80,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No sources yet',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add a book, article, or podcast to start\ncollecting knowledge',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => _showAddSourceDialog(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Source'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: provider.sources.length,
                    itemBuilder: (context, index) {
                      final source = provider.sources[index];
                      final factCount = provider.getFactCountForSource(source.id);
                      
                      return SourceCard(
                        source: source,
                        factCount: factCount,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SourceDetailScreen(source: source),
                            ),
                          );
                        },
                        onLongPress: () => _showOptionsSheet(context, source),
                      );
                    },
                  );
                },
              ),
              if (_isDragging)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 64,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Drop PDF to Add Source',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_add_source',
        onPressed: () => _showAddSourceDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Source'),
      ),
    );
  }
  
  void _showAddSourceDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddSourceScreen(),
      ),
    );
  }

  Future<void> _handleFileDrop(BuildContext context, List<XFile> files) async {
    setState(() => _isDragging = false);
    
    final pdfFiles = files.where((f) => f.name.toLowerCase().endsWith('.pdf')).toList();
    if (pdfFiles.isEmpty) return;

    final provider = context.read<DataProvider>();
    
    for (final file in pdfFiles) {
      final path = file.path;
      // Check if source exists
      var source = provider.findSourceByFilePath(path);
      
      if (source == null) {
        // Create new
        source = await provider.addSource(
          name: file.name.replaceAll('.pdf', ''),
          type: SourceType.document,
          filePath: path,
        );
      }
      
      if (mounted) {
        // Navigate to the last dropped file
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SourceDetailScreen(source: source!),
          ),
        );
      }
    }
  }
  
  void _showOptionsSheet(BuildContext context, Source source) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Source'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddSourceScreen(source: source),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Source',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(context, source);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Source source) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Source?'),
        content: Text(
          'This will delete "${source.name}" and all its facts. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<DataProvider>().deleteSource(source.id);
              Navigator.pop(context);
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
