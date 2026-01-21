import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/smart_collection.dart';

import '../providers/data_provider.dart';
import '../services/collection_service.dart';
import '../widgets/fact_card.dart';
import '../widgets/create_collection_dialog.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final CollectionService _collectionService = CollectionService();
  List<SmartCollection> _dynamicCollections = [];
  bool _isLoadingDynamic = true;
  SmartCollection? _selectedCollection;

  @override
  void initState() {
    super.initState();
    _loadDynamicCollections();
  }

  Future<void> _loadDynamicCollections() async {
    final provider = context.read<DataProvider>();
    // Wait for provider to be ready if needed
    if (provider.isLoading) return;

    setState(() => _isLoadingDynamic = true);
    
    try {
      final dynamicCols = await _collectionService.generateDynamicCollections(
        provider.facts, 
        provider.factLinks
      );
      if (mounted) {
        setState(() {
          _dynamicCollections = dynamicCols;
          _isLoadingDynamic = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating dynamic collections: $e');
      if (mounted) {
        setState(() => _isLoadingDynamic = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCollection != null) {
      return _buildCollectionDetail(_selectedCollection!);
    }

    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    final userCollections = provider.userCollections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.secondary),
            onPressed: () {
              _loadDynamicCollections();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing insights...')),
              );
            },
            tooltip: 'Refresh Insights',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Section: Smart Insights (Dynamic)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Smart Insights',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (_isLoadingDynamic)
            const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              )),
            )
          else if (_dynamicCollections.isEmpty)
             SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No insights found yet. Add more connected facts!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final collection = _dynamicCollections[index];
                  final count = collection.dynamicParams['factCount'] ?? '?';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        _getIcon(collection.icon), 
                        color: theme.colorScheme.onPrimaryContainer
                      ),
                    ),
                    title: Text(collection.name),
                    subtitle: Text('$count facts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _selectedCollection = collection),
                  );
                },
                childCount: _dynamicCollections.length,
              ),
            ),

          // Section: Your Collections (Manual)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.folder_special, size: 20, color: theme.colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Your Collections',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (userCollections.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No custom collections yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final collection = userCollections[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(Icons.folder, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    title: Text(collection.name),
                    subtitle: Text('${collection.filters.length} filters'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _selectedCollection = collection),
                    onLongPress: () => _confirmDeleteCollection(collection),
                  );
                },
                childCount: userCollections.length,
              ),
            ),
            
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Collection'),
      ),
    );
  }

  Widget _buildCollectionDetail(SmartCollection collection) {
    final provider = context.watch<DataProvider>();
    final theme = Theme.of(context);
    
    final facts = _collectionService.executeCollection(
      collection, 
      provider.facts, 
      provider.factLinks
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedCollection = null),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(collection.name),
            Text(
              '${facts.length} facts',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          if (!collection.isBuiltIn && collection.type == CollectionType.manual)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _confirmDeleteCollection(collection);
                setState(() => _selectedCollection = null);
              },
            ),
        ],
      ),
      body: facts.isEmpty
          ? Center(
              child: Text(
                'No facts match these filters.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: facts.length,
              itemBuilder: (context, index) {
                return FactCard(
                  fact: facts[index],
                  onTap: () {
                    Navigator.pushNamed(
                      context, 
                      '/fact_detail', 
                      arguments: facts[index]
                    );
                  },
                );
              },
            ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'bubble_chart': return Icons.bubble_chart;
      case 'share': return Icons.share;
      case 'folder': return Icons.folder;
      case 'schedule': return Icons.schedule;
      case 'new_releases': return Icons.new_releases;
      case 'hub': return Icons.hub;
      case 'link_off': return Icons.link_off;
      case 'auto_awesome': return Icons.auto_awesome;
      default: return Icons.folder;
    }
  }
  
  Future<void> _showCreateDialog() async {
    final result = await showDialog<SmartCollection>(
      context: context, 
      builder: (_) => const CreateCollectionDialog(),
    );
    
    if (result != null && mounted) {
      context.read<DataProvider>().createCollection(result);
    }
  }

  Future<void> _confirmDeleteCollection(SmartCollection collection) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text('Delete "${collection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancel')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete')
          ),
        ],
      ),
    );
    
    if (confirm == true && mounted) {
      context.read<DataProvider>().deleteCollection(collection.id);
    }
  }
}
