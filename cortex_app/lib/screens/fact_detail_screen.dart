import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fact.dart';
import '../providers/data_provider.dart';
import '../services/embedding_service.dart';
import '../services/secure_storage_service.dart';
import '../widgets/linked_text.dart';
import '../widgets/related_facts_panel.dart';

class FactDetailScreen extends StatefulWidget {
  final Fact fact;

  const FactDetailScreen({super.key, required this.fact});

  @override
  State<FactDetailScreen> createState() => _FactDetailScreenState();
}

class _FactDetailScreenState extends State<FactDetailScreen> {
  List<RelatedFact> _relatedFacts = [];
  bool _isLoadingRelated = false;
  bool _isGeneratingEmbedding = false;

  @override
  void initState() {
    super.initState();
    _loadRelatedFacts();
  }

  void _loadRelatedFacts() {
    final provider = context.read<DataProvider>();
    final embeddingService = EmbeddingService();

    setState(() => _isLoadingRelated = true);

    // Find related facts
    final related = embeddingService.findRelatedFacts(
      widget.fact,
      provider.facts,
      limit: 5,
      threshold: 0.6,
    );

    setState(() {
      _relatedFacts = related;
      _isLoadingRelated = false;
    });
  }

  Future<void> _generateEmbedding() async {
    setState(() => _isGeneratingEmbedding = true);

    try {
      final apiKey = await SecureStorageService.getOpenAiApiKey();
      if (apiKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please configure OpenAI API key in Settings',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ),
          );
        }
        setState(() => _isGeneratingEmbedding = false);
        return;
      }

      final embeddingService = EmbeddingService(apiKey: apiKey);
      final embedding = await embeddingService.generateEmbedding(
        widget.fact.content,
      );

      if (embedding != null && mounted) {
        final provider = context.read<DataProvider>();
        final updatedFact = Fact(
          id: widget.fact.id,
          content: widget.fact.content,
          sourceId: widget.fact.sourceId,
          subjects: widget.fact.subjects,
          imageUrl: widget.fact.imageUrl,
          ocrText: widget.fact.ocrText,
          createdAt: widget.fact.createdAt,
          updatedAt: DateTime.now(),
          repetitions: widget.fact.repetitions,
          easeFactor: widget.fact.easeFactor,
          interval: widget.fact.interval,
          nextReviewAt: widget.fact.nextReviewAt,
          embedding: embedding,
        );

        await provider.updateFact(updatedFact);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Embedding generated successfully')),
          );
          _loadRelatedFacts();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate embedding')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingEmbedding = false);
      }
    }
  }

  Future<void> _showSimilarityChecker() async {
    final provider = context.read<DataProvider>();

    // Show dialog to select another fact
    final selectedFact = await showDialog<Fact>(
      context: context,
      builder: (context) => _FactSelectorDialog(
        facts: provider.facts.where((f) => f.id != widget.fact.id).toList(),
      ),
    );

    if (selectedFact == null || !mounted) return;

    // Calculate similarity
    if (widget.fact.embedding == null || selectedFact.embedding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Both facts need embeddings. Generate them first.'),
        ),
      );
      return;
    }

    final embeddingService = EmbeddingService();
    final similarity = embeddingService.cosineSimilarity(
      widget.fact.embedding!,
      selectedFact.embedding!,
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Strength'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Similarity: ${(similarity * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: similarity,
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                _getSimilarityDescription(similarity),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Comparing with:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  selectedFact.content,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FactDetailScreen(fact: selectedFact),
                  ),
                );
              },
              child: const Text('View Fact'),
            ),
          ],
        ),
      );
    }
  }

  String _getSimilarityDescription(double similarity) {
    if (similarity >= 0.9)
      return 'Extremely similar - nearly identical concepts';
    if (similarity >= 0.75) return 'Very similar - strong semantic connection';
    if (similarity >= 0.6) return 'Moderately similar - related topics';
    if (similarity >= 0.4) return 'Somewhat similar - loose connection';
    return 'Not similar - different topics';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    final source = provider.sources.firstWhere(
      (s) => s.id == widget.fact.sourceId,
      orElse: () => provider.sources.first,
    );

    final hasEmbedding = widget.fact.embedding != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fact'),
        actions: [
          // Similarity checker button
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: 'Check similarity with another fact',
            onPressed: hasEmbedding ? _showSimilarityChecker : null,
          ),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              // TODO: Navigate to edit screen
            },
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinkedText(
                    content: widget.fact.displayText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      height: 1.6,
                    ),
                    onLinkTap: (linkText) {
                      // Find and navigate to linked fact
                      final linkedFact = provider.facts.firstWhere(
                        (f) => f.content.toLowerCase().contains(
                          linkText.toLowerCase(),
                        ),
                        orElse: () => widget.fact,
                      );
                      if (linkedFact.id != widget.fact.id) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FactDetailScreen(fact: linkedFact),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // Embedding status banner
            if (!hasEmbedding)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Generate embedding to find related facts',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isGeneratingEmbedding
                          ? null
                          : _generateEmbedding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: _isGeneratingEmbedding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Generate'),
                    ),
                  ],
                ),
              ),

            // Metadata
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source
                  _MetadataRow(
                    icon: Icons.source_rounded,
                    label: 'Source',
                    value: source.name,
                  ),
                  const SizedBox(height: 12),

                  // Subjects
                  if (widget.fact.subjects.isNotEmpty) ...[
                    _MetadataRow(
                      icon: Icons.label_rounded,
                      label: 'Subjects',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: widget.fact.subjects.map((s) {
                          return Chip(
                            label: Text(s),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // SRS Info
                  _MetadataRow(
                    icon: Icons.schedule_rounded,
                    label: 'Review Status',
                    value: _getReviewStatus(),
                  ),
                  const SizedBox(height: 12),

                  // Created
                  _MetadataRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Created',
                    value: _formatDate(widget.fact.createdAt),
                  ),

                  // Embedding status
                  const SizedBox(height: 12),
                  _MetadataRow(
                    icon: hasEmbedding ? Icons.check_circle : Icons.pending,
                    label: 'Embedding',
                    value: hasEmbedding ? 'Generated' : 'Not generated',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Related facts
            RelatedFactsPanel(
              relatedFacts: _relatedFacts,
              isLoading: _isLoadingRelated,
              onFactTap: (fact) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FactDetailScreen(fact: fact),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getReviewStatus() {
    if (widget.fact.repetitions == 0) {
      return 'New (never reviewed)';
    } else if (widget.fact.isDueForReview) {
      return 'Due for review';
    } else {
      final daysUntil = widget.fact.nextReviewAt!
          .difference(DateTime.now())
          .inDays;
      return 'Next review in $daysUntil days';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fact?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<DataProvider>().deleteFact(widget.fact.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
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

class _MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  const _MetadataRow({
    required this.icon,
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 2),
              child ?? Text(value ?? '', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

// Dialog to select a fact for comparison
class _FactSelectorDialog extends StatefulWidget {
  final List<Fact> facts;

  const _FactSelectorDialog({required this.facts});

  @override
  State<_FactSelectorDialog> createState() => _FactSelectorDialogState();
}

class _FactSelectorDialogState extends State<_FactSelectorDialog> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredFacts = widget.facts.where((fact) {
      return fact.content.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      title: const Text('Select Fact to Compare'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search facts...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredFacts.isEmpty
                  ? const Center(child: Text('No facts found'))
                  : ListView.builder(
                      itemCount: filteredFacts.length,
                      itemBuilder: (context, index) {
                        final fact = filteredFacts[index];
                        final hasEmbedding = fact.embedding != null;

                        return ListTile(
                          title: Text(
                            fact.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: hasEmbedding
                              ? null
                              : const Text(
                                  'No embedding',
                                  style: TextStyle(color: Colors.orange),
                                ),
                          trailing: Icon(
                            hasEmbedding
                                ? Icons.check_circle
                                : Icons.warning_amber,
                            color: hasEmbedding ? Colors.green : Colors.orange,
                          ),
                          onTap: () => Navigator.pop(context, fact),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
