import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/graph_settings.dart';
import '../providers/data_provider.dart';
import '../services/graph_service.dart';
import '../services/embedding_service.dart';
import '../widgets/knowledge_graph.dart';
import '../widgets/graph_settings_panel.dart';
import 'fact_detail_screen.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  bool _showSemanticEdges = true;
  String? _filterSourceId;
  String? _filterSubject;
  GraphSettings _settings = GraphSettings.defaults;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final settings = await GraphSettings.load();
    if (mounted) {
      setState(() => _settings = settings);
    }
  }
  
  void _updateSettings(GraphSettings newSettings) {
    setState(() => _settings = newSettings);
    newSettings.save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge Graph'),
        actions: [
          IconButton(
            icon: Icon(
              _showSemanticEdges ? Icons.link_rounded : Icons.link_off_rounded,
            ),
            tooltip: _showSemanticEdges
                ? 'Hide semantic connections'
                : 'Show semantic connections',
            onPressed: () {
              setState(() {
                _showSemanticEdges = !_showSemanticEdges;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: Badge(
              isLabelVisible: _filterSourceId != null || _filterSubject != null,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter by source or tag',
            onSelected: (value) {
              if (value == 'clear') {
                setState(() {
                  _filterSourceId = null;
                  _filterSubject = null;
                });
              } else if (value.startsWith('source_')) {
                setState(() {
                  _filterSourceId = value.substring(7);
                  _filterSubject = null;
                });
              } else if (value.startsWith('subject_')) {
                setState(() {
                  _filterSubject = value.substring(8);
                  _filterSourceId = null;
                });
              }
            },
            itemBuilder: (context) {
              final provider = context.read<DataProvider>();
              return [
                PopupMenuItem(
                  value: 'clear',
                  enabled: _filterSourceId != null || _filterSubject != null,
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded, 
                        color: (_filterSourceId != null || _filterSubject != null) 
                            ? null : Colors.grey),
                      const SizedBox(width: 12),
                      Text('Clear Filters',
                        style: TextStyle(
                          color: (_filterSourceId != null || _filterSubject != null) 
                              ? null : Colors.grey)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                // Sources section
                const PopupMenuItem(
                  enabled: false,
                  height: 32,
                  child: Text('SOURCES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                ...provider.sources.map(
                  (source) => PopupMenuItem(
                    value: 'source_${source.id}',
                    child: Row(
                      children: [
                        if (_filterSourceId == source.id)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(source.name)),
                        Text('${provider.facts.where((f) => f.sourceId == source.id).length}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                if (provider.allSubjects.isNotEmpty) ...[
                  const PopupMenuDivider(),
                  // Tags section
                  const PopupMenuItem(
                    enabled: false,
                    height: 32,
                    child: Text('TAGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  ...provider.allSubjects.take(15).map(
                    (subject) => PopupMenuItem(
                      value: 'subject_$subject',
                      child: Row(
                        children: [
                          if (_filterSubject == subject)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(subject)),
                          Text('${provider.facts.where((f) => f.subjects.contains(subject)).length}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.facts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.hub_rounded,
                    size: 80,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 24),
                  Text('No facts yet', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Add facts to build your knowledge graph',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          // Filter facts
          var facts = provider.facts;
          if (_filterSourceId != null) {
            facts = facts.where((f) => f.sourceId == _filterSourceId).toList();
          }
          if (_filterSubject != null) {
            facts = facts
                .where((f) => f.subjects.contains(_filterSubject))
                .toList();
          }

          // Get fact IDs for filtering links
          final factIds = facts.map((f) => f.id).toSet();
          
          // Filter links to only include those between visible facts
          final links = provider.factLinks.where((link) {
            return factIds.contains(link.sourceFactId) && 
                   factIds.contains(link.targetFactId);
          }).toList();
          
          // Debug: print link info
          debugPrint('Graph: ${facts.length} facts, ${provider.factLinks.length} total links, ${links.length} filtered links');
          for (final link in links) {
            debugPrint('  Link: ${link.sourceFactId.substring(0, 8)} -> ${link.targetFactId.substring(0, 8)} ("${link.linkText}")');
          }

          // Build graph data
          final graphService = GraphService(EmbeddingService());
          final graphData = graphService.buildGraph(
            facts,
            links,
            includeSemanticEdges: _showSemanticEdges,
          );
          
          debugPrint('GraphData: ${graphData.nodes.length} nodes, ${graphData.edges.length} edges');

          final sources = {for (final s in provider.sources) s.id: s};

          return Column(
            children: [
              // Stats bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.surface,
                child: Row(
                  children: [
                    _StatChip(
                      icon: Icons.circle,
                      label: '${graphData.nodes.length} facts',
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      icon: Icons.link,
                      label:
                          '${graphData.edges.where((e) => e.type == EdgeType.manual).length} links',
                      color: theme.colorScheme.secondary,
                    ),
                    if (_showSemanticEdges) ...[
                      const SizedBox(width: 12),
                      _StatChip(
                        icon: Icons.hub,
                        label:
                            '${graphData.edges.where((e) => e.type == EdgeType.semantic).length} semantic',
                        color: theme.colorScheme.tertiary,
                      ),
                    ],
                  ],
                ),
              ),

              // Graph with settings panel overlay
              Expanded(
                child: Stack(
                  children: [
                    KnowledgeGraph(
                      graphData: graphData,
                      sources: sources,
                      settings: _settings,
                      onNodeTap: (fact) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FactDetailScreen(fact: fact),
                          ),
                        );
                      },
                    ),
                    GraphSettingsPanel(
                      settings: _settings,
                      onSettingsChanged: _updateSettings,
                    ),
                  ],
                ),
              ),

              // Legend
              Container(
                padding: const EdgeInsets.all(12),
                color: theme.colorScheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(
                      color: theme.colorScheme.primary,
                      label: 'Manual link',
                      isSolid: true,
                    ),
                    const SizedBox(width: 24),
                    _LegendItem(
                      color: theme.colorScheme.secondary,
                      label: 'Semantic similarity',
                      isSolid: false,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSolid;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.isSolid,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 2,
          decoration: BoxDecoration(
            color: isSolid ? color : Colors.transparent,
            border: isSolid
                ? null
                : Border(
                    bottom: BorderSide(
                      color: color,
                      width: 1,
                      style: BorderStyle.solid,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
