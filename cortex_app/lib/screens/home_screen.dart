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
  SourceType? _selectedType;
  String _searchQuery = '';

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
        child: Stack(
          children: [
            Container(
              color: _isDragging 
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3) 
                  : Colors.transparent,
              child: Column(
                children: [
                  // Search & Filter Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      children: [
                        // Search Bar (Visual only for now, or real filtering)
                         TextField(
                          decoration: InputDecoration(
                            hintText: 'Search your second brain...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        // Filter Chips (Scrollable)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(null, 'All'),
                              const SizedBox(width: 8),
                              _buildFilterChip(SourceType.document, 'PDFs'),
                              const SizedBox(width: 8),
                              _buildFilterChip(SourceType.conversation, 'Conversations'),
                              const SizedBox(width: 8),
                              _buildFilterChip(SourceType.course, 'Courses'),
                              const SizedBox(width: 8),
                              _buildFilterChip(SourceType.video, 'Videos'),
                              const SizedBox(width: 8),
                              _buildFilterChip(SourceType.article, 'Articles'),
                              const SizedBox(width: 8),
                              _buildFilterChip(SourceType.book, 'Books'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Consumer<DataProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        // Apply Filters
                        var filteredSources = provider.sources;
                        
                        if (_selectedType != null) {
                          filteredSources = filteredSources.where((s) => s.type == _selectedType).toList();
                        }
                        
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          filteredSources = filteredSources.where((s) {
                            return s.name.toLowerCase().contains(q) || 
                                   s.defaultTags.any((t) => t.toLowerCase().contains(q));
                          }).toList();
                        }

                        if (filteredSources.isEmpty) {
                           if (provider.sources.isEmpty) {
                              // Truly empty state
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.library_books_rounded,
                                      size: 60,
                                      color: theme.colorScheme.primary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No sources yet',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    TextButton(
                                      onPressed: () => _showAddSourceDialog(context),
                                      child: const Text('Add your first source'),
                                    )
                                  ],
                                ),
                              );
                           } else {
                             // No matches
                             return Center(
                               child: Text(
                                 'No matching sources found',
                                 style: theme.textTheme.bodyLarge?.copyWith(
                                   color: theme.colorScheme.onSurfaceVariant,
                                 ),
                               ),
                             );
                           }
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 100),
                          itemCount: filteredSources.length,
                          itemBuilder: (context, index) {
                            final source = filteredSources[index];
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
                  ),
                ],
              ),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_add_source',
        onPressed: () => _showAddSourceDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Source'),
      ),
    );
  }

  Widget _buildFilterChip(SourceType? type, String label) {
    final isSelected = _selectedType == type;
    final theme = Theme.of(context);
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            _selectedType = type;
          } else {
             // Only allow deselecting if it's not the "All" equivalent (which is null)
             // Tapping selected chip clears filter (goes to All)
             _searchQuery = ''; // Clear search too? Maybe not.
             _selectedType = null;
          }
        });
      },
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 1,
        ),
      ),
      showCheckmark: false,
    );
  }
  
  void _showAddSourceDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSourceScreen(initialType: _selectedType),
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
      
      source ??= await provider.addSource(
          name: file.name.replaceAll('.pdf', ''),
          type: SourceType.document,
          filePath: path,
        );
      
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
