import 'package:flutter/material.dart';
import '../models/fact.dart';
import '../services/embedding_service.dart';
import '../theme/app_theme.dart';

/// Panel showing semantically related facts based on embeddings
class RelatedFactsPanel extends StatelessWidget {
  final List<RelatedFact> relatedFacts;
  final Function(Fact)? onFactTap;
  final bool isLoading;

  const RelatedFactsPanel({
    super.key,
    required this.relatedFacts,
    this.onFactTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (isLoading) {
      return _buildSection(
        context,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    if (relatedFacts.isEmpty) {
      return _buildSection(
        context,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 12),
              Text(
                'No related facts found',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    
    return _buildSection(
      context,
      child: Column(
        children: relatedFacts.map((related) {
          return InkWell(
            onTap: () => onFactTap?.call(related.fact),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Similarity badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getSimilarityColor(related.similarity, isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${related.similarityPercent}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Fact content preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          related.fact.displayText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (related.fact.subjects.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: related.fact.subjects.take(3).map((s) {
                              return Text(
                                '#$s',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildSection(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.hub_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Related Facts',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
  
  Color _getSimilarityColor(double similarity, bool isDark) {
    if (similarity >= 0.9) {
      return isDark ? AppTheme.darkSuccess : AppTheme.lightSuccess;
    } else if (similarity >= 0.8) {
      return isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    } else {
      return isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary;
    }
  }
}
