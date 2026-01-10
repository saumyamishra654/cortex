import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fact.dart';
import '../providers/data_provider.dart';
import '../services/embedding_service.dart';
import '../widgets/linked_text.dart';
import '../widgets/related_facts_panel.dart';

class FactDetailScreen extends StatefulWidget {
  final Fact fact;

  const FactDetailScreen({
    super.key,
    required this.fact,
  });

  @override
  State<FactDetailScreen> createState() => _FactDetailScreenState();
}

class _FactDetailScreenState extends State<FactDetailScreen> {
  List<RelatedFact> _relatedFacts = [];
  bool _isLoadingRelated = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();
    final source = provider.sources.firstWhere(
      (s) => s.id == widget.fact.sourceId,
      orElse: () => provider.sources.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {
              // TODO: Navigate to edit screen
            },
          ),
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
                        (f) => f.content.toLowerCase().contains(linkText.toLowerCase()),
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
          .difference(DateTime.now()).inDays;
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
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.secondary,
        ),
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
              child ?? Text(
                value ?? '',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
