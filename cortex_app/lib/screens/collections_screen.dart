import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fact_link.dart';
import '../models/smart_collection.dart';
import '../providers/data_provider.dart';
import '../services/collection_service.dart';
import '../widgets/fact_card.dart';
import 'fact_detail_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final CollectionService _collectionService = CollectionService();
  SmartCollection? _selectedCollection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builtInCollections = _collectionService.getBuiltInCollections();

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCollection?.name ?? 'Collections'),
        leading: _selectedCollection != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _selectedCollection = null);
                },
              )
            : null,
      ),
      body: _selectedCollection != null
          ? _buildCollectionDetail(_selectedCollection!)
          : _buildCollectionList(builtInCollections),
      floatingActionButton: _selectedCollection == null
          ? FloatingActionButton.extended(
              heroTag: 'collections_new',
              onPressed: () {
                // TODO: Open create collection dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Custom collections coming soon!'),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Collection'),
            )
          : null,
    );
  }

  Widget _buildCollectionList(List<SmartCollection> collections) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: collections.length,
      itemBuilder: (context, index) {
        final collection = collections[index];
        final provider = context.read<DataProvider>();
        final factCount = _collectionService
            .executeCollection(collection, provider.facts, <FactLink>[])
            .length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconData(collection.icon),
                color: theme.colorScheme.primary,
              ),
            ),
            title: Text(
              collection.name,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: Text(
              '$factCount facts',
              style: theme.textTheme.bodyMedium,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              setState(() => _selectedCollection = collection);
            },
          ),
        );
      },
    );
  }

  Widget _buildCollectionDetail(SmartCollection collection) {
    final theme = Theme.of(context);

    return Consumer<DataProvider>(
      builder: (context, provider, child) {
        final facts = _collectionService.executeCollection(
          collection,
          provider.facts,
          <FactLink>[],
        );

        if (facts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getIconData(collection.icon),
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No matching facts',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _getEmptyMessage(collection),
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: facts.length,
          itemBuilder: (context, index) {
            final fact = facts[index];
            final source = provider.sources.firstWhere(
              (s) => s.id == fact.sourceId,
              orElse: () => provider.sources.first,
            );

            return FactCard(
              fact: fact,
              sourceName: source.name,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FactDetailScreen(fact: fact),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _getEmptyMessage(SmartCollection collection) {
    switch (collection.id) {
      case 'builtin_due':
        return 'All caught up! No cards due for review.';
      case 'builtin_connected':
        return 'Add links between facts to see highly connected ones.';
      case 'builtin_unlinked':
        return 'All your facts have connections!';
      default:
        return 'No facts match this collection\'s filters.';
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'schedule':
        return Icons.schedule_rounded;
      case 'new_releases':
        return Icons.new_releases_rounded;
      case 'hub':
        return Icons.hub_rounded;
      case 'link_off':
        return Icons.link_off_rounded;
      case 'folder':
        return Icons.folder_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}
