import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/source.dart';
import '../providers/data_provider.dart';
import '../widgets/fact_card.dart';
import 'add_fact_screen.dart';
import 'edit_source_screen.dart';
import 'edit_fact_screen.dart';

class SourceDetailScreen extends StatelessWidget {
  final Source source;

  const SourceDetailScreen({
    super.key,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    
    // Get the latest source data (in case it was updated)
    final currentSource = provider.sources.firstWhere(
      (s) => s.id == source.id,
      orElse: () => source,
    );
    
    return Scaffold(
      appBar: AppBar(
        title: Text(currentSource.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit Source',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditSourceScreen(source: currentSource),
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
          final facts = provider.getFactsForSource(source.id);
          
          if (facts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_add_rounded,
                    size: 80,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No facts yet',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first fact from this source',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToAddFact(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Fact'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            itemCount: facts.length,
            itemBuilder: (context, index) {
              final fact = facts[index];
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'source_detail_add_fact',
        onPressed: () => _navigateToAddFact(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _navigateToAddFact(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddFactScreen(source: source),
      ),
    );
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
