import 'package:flutter/material.dart';
import '../models/fact.dart';
import '../theme/app_theme.dart';
import 'linked_text.dart';
import '../screens/link_references_screen.dart';

class FactCard extends StatelessWidget {
  final Fact fact;
  final String? sourceName;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const FactCard({
    super.key,
    required this.fact,
    this.sourceName,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isDark
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.darkPrimary.withValues(alpha: 0.08),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinkedText(
                content: fact.displayText,
                style: theme.textTheme.bodyLarge,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                onLinkTap: (linkText) {
                  // Navigate to link references screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LinkReferencesScreen(linkText: linkText),
                    ),
                  );
                },
              ),
              if (fact.url != null && fact.url!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fact.url!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary.withValues(alpha: 0.7),
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (fact.subjects.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: fact.subjects.map((subject) {
                    return Chip(
                      label: Text(subject),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
              if (sourceName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.source_rounded,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sourceName!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
