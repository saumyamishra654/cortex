import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fact.dart';
import '../providers/data_provider.dart';
import '../widgets/fact_card.dart';
import 'fact_detail_screen.dart';

/// Screen showing all facts that reference a specific [[link]] text
class LinkReferencesScreen extends StatelessWidget {
  final String linkText;

  const LinkReferencesScreen({
    super.key,
    required this.linkText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DataProvider>();

    // Find all facts that contain this link text (either in [[]] or as content)
    final referencingFacts = _findReferencingFacts(linkText, provider.facts);
    final linkedFacts = _findLinkedFacts(linkText, provider.facts);

    return Scaffold(
      appBar: AppBar(
        title: Text('[[$linkText]]'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Facts that match this link
          if (linkedFacts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.link_rounded,
              title: 'Linked Facts',
              subtitle: 'Facts matching "$linkText"',
            ),
            const SizedBox(height: 12),
            ...linkedFacts.map((fact) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FactCard(
                fact: fact,
                sourceName: _getSourceName(fact.sourceId, provider),
                onTap: () => _navigateToFact(context, fact),
              ),
            )),
            const SizedBox(height: 24),
          ],

          // Section: Facts that use this link
          if (referencingFacts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.format_quote_rounded,
              title: 'References',
              subtitle: 'Facts containing [[$linkText]]',
            ),
            const SizedBox(height: 12),
            ...referencingFacts.map((fact) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FactCard(
                fact: fact,
                sourceName: _getSourceName(fact.sourceId, provider),
                onTap: () => _navigateToFact(context, fact),
              ),
            )),
          ],

          // Empty state
          if (linkedFacts.isEmpty && referencingFacts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No facts found',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No facts match or reference "$linkText"',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Find facts that contain [[linkText]] in their content
  List<Fact> _findReferencingFacts(String linkText, List<Fact> allFacts) {
    final pattern = RegExp(r'\[\[' + RegExp.escape(linkText) + r'\]\]', caseSensitive: false);
    return allFacts.where((fact) => pattern.hasMatch(fact.content)).toList();
  }

  /// Find facts that match the link text (are being linked TO)
  List<Fact> _findLinkedFacts(String linkText, List<Fact> allFacts) {
    final searchText = linkText.toLowerCase().trim();
    return allFacts.where((fact) {
      return fact.content.toLowerCase().contains(searchText);
    }).toList();
  }

  String? _getSourceName(String sourceId, DataProvider provider) {
    try {
      return provider.sources.firstWhere((s) => s.id == sourceId).name;
    } catch (_) {
      return null;
    }
  }

  void _navigateToFact(BuildContext context, Fact fact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FactDetailScreen(fact: fact),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
