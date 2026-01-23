import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/fact.dart';
import '../models/graph_settings.dart';
import '../models/source.dart';
import '../services/graph_service.dart';
import '../theme/app_theme.dart';

/// Interactive knowledge graph visualization widget
class KnowledgeGraph extends StatefulWidget {
  final GraphData graphData;
  final Map<String, Source> sources;
  final GraphSettings settings;
  final String? highlightedId;
  final Function(Fact)? onNodeTap;
  final bool showLabels;

  const KnowledgeGraph({
    super.key,
    required this.graphData,
    required this.sources,
    this.settings = GraphSettings.defaults,
    this.highlightedId,
    this.onNodeTap,
    this.showLabels = true,
  });

  @override
  State<KnowledgeGraph> createState() => _KnowledgeGraphState();
}

class _KnowledgeGraphState extends State<KnowledgeGraph> {
  Map<String, Offset> _positions = {};
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  String? _hoveredNodeId;
  
  @override
  void initState() {
    super.initState();
    _calculateLayout();
  }
  
  @override
  void didUpdateWidget(KnowledgeGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate on node count change OR settings change
    if (oldWidget.graphData.nodes.length != widget.graphData.nodes.length ||
        oldWidget.settings != widget.settings) {
      _calculateLayout();
    }
  }
  
  void _calculateLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderSize = context.size;
      if (renderSize == null) return;
      
      final graphService = GraphService();
      final positions = graphService.calculateLayout(
        widget.graphData,
        size: Size(renderSize.width, renderSize.height),
        iterations: 100,
        settings: widget.settings,
      );
      
      setState(() {
        _positions = positions;
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (widget.graphData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hub_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No connections yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add more facts and links to build your graph',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        GestureDetector(
          onScaleUpdate: (details) {
            setState(() {
              _scale = (_scale * details.scale).clamp(0.3, 3.0);
              _panOffset = _panOffset + details.focalPointDelta;
            });
          },
          child: MouseRegion(
            onHover: (event) {
              final hoveredNode = _findNodeAt(event.localPosition);
              setState(() {
                _hoveredNodeId = hoveredNode?.id;
              });
            },
            onExit: (_) {
              setState(() {
                _hoveredNodeId = null;
              });
            },
            child: ClipRect(
              child: CustomPaint(
                painter: _GraphPainter(
                  nodes: widget.graphData.nodes,
                  edges: widget.graphData.edges,
                  positions: _positions.map((k, v) => MapEntry(k, 
                      Offset(v.dx * _scale + _panOffset.dx, 
                             v.dy * _scale + _panOffset.dy))),
                  sources: widget.sources,
                  highlightedId: widget.highlightedId,
                  hoveredId: _hoveredNodeId,
                  isDark: isDark,
                  showLabels: widget.showLabels,
                  scale: _scale,
                ),
                child: GestureDetector(
                  onTapUp: (details) {
                    final tappedNode = _findNodeAt(details.localPosition);
                    if (tappedNode != null && widget.onNodeTap != null) {
                      widget.onNodeTap!(tappedNode.fact);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        // Hover Tooltip
        if (_hoveredNodeId != null) _buildTooltip(theme),
      ],
    );
  }

  Widget _buildTooltip(ThemeData theme) {
    if (_hoveredNodeId == null || _positions[_hoveredNodeId] == null) return const SizedBox();

    final node = widget.graphData.nodes.firstWhere((n) => n.id == _hoveredNodeId);
    final rawPos = _positions[_hoveredNodeId]!;
    final screenPos = Offset(
      rawPos.dx * _scale + _panOffset.dx,
      rawPos.dy * _scale + _panOffset.dy,
    );
    
    final source = widget.sources[node.fact.sourceId];

    return Positioned(
      left: screenPos.dx + 15,
      top: screenPos.dy + 15,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Source Type Badge
              if (source != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSourceIcon(source.type),
                        size: 14, 
                        color: theme.colorScheme.onSecondaryContainer
                      ),
                      const SizedBox(width: 6),
                      Text(
                        source.typeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
              // Fact Content
              Text(
                node.fact.displayText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
              ),
              
              // Tags
              if (node.fact.subjects.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: node.fact.subjects.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontSize: 10,
                      ),
                    ),
                  )).toList(),
                ),
                if (node.fact.subjects.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${node.fact.subjects.length - 3} more',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  GraphNode? _findNodeAt(Offset position) {
    for (final node in widget.graphData.nodes) {
      final nodePos = _positions[node.id];
      if (nodePos == null) continue;
      
      final scaledPos = Offset(
        nodePos.dx * _scale + _panOffset.dx,
        nodePos.dy * _scale + _panOffset.dy,
      );
      
      final distance = (position - scaledPos).distance;
      if (distance <= node.size * _scale) {
        return node;
      }
    }
    return null;
  }
  IconData _getSourceIcon(SourceType type) {
    switch (type) {
      case SourceType.book:
        return Icons.menu_book;
      case SourceType.article:
        return Icons.article;
      case SourceType.podcast:
        return Icons.mic;
      case SourceType.video:
        return Icons.videocam;
      case SourceType.conversation:
        return Icons.forum;
      case SourceType.course:
        return Icons.school;
      case SourceType.research_paper:
        return Icons.science;
      case SourceType.audiobook:
        return Icons.headset;
      case SourceType.reels:
        return Icons.ondemand_video;
      case SourceType.social_post:
        return Icons.public;
      case SourceType.document:
        return Icons.description;
      case SourceType.other:
      default:
        return Icons.link;
    }
  }
}

class _GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final Map<String, Source> sources;
  final String? highlightedId;
  final String? hoveredId;
  final bool isDark;
  final bool showLabels;
  final double scale;

  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.sources,
    this.highlightedId,
    this.hoveredId,
    required this.isDark,
    required this.showLabels,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges first (behind nodes)
    for (final edge in edges) {
      final start = positions[edge.sourceId];
      final end = positions[edge.targetId];
      if (start == null || end == null) continue;
      
      final paint = Paint()
        ..strokeWidth = edge.type == EdgeType.manual ? 2.5 : 1
        ..style = PaintingStyle.stroke;
      
      if (edge.type == EdgeType.manual) {
        // Use distinct color based on link text
        paint.color = GraphEdge.colorForLinkText(edge.linkText, isDark)
            .withValues(alpha: 0.8);
      } else {
        paint.color = (isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary)
            .withValues(alpha: edge.weight * 0.5);
      }
      
      canvas.drawLine(start, end, paint);
      
      // Draw arrowhead for manual links
      if (edge.type == EdgeType.manual) {
        _drawArrowhead(canvas, start, end, paint.color);
      }
    }
    
    // Draw nodes
    for (final node in nodes) {
      final pos = positions[node.id];
      if (pos == null) continue;
      
      final isHighlighted = node.id == highlightedId;
      final isHovered = node.id == hoveredId;
      final nodeSize = node.size * scale;
      
      // Get color based on specific source (unique color per source)
      final baseColor = _getColorForSourceId(node.fact.sourceId, isDark);
      
      // Draw glow for highlighted/hovered
      if (isHighlighted || isHovered) {
        final glowPaint = Paint()
          ..color = baseColor.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(pos, nodeSize * 1.5, glowPaint);
      }
      
      // Draw node
      final nodePaint = Paint()
        ..color = isHighlighted ? baseColor : baseColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, nodeSize, nodePaint);
      
      // Draw border
      final borderPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(pos, nodeSize, borderPaint);
    }
  }
  
  /// Generate a consistent unique color for a source ID
  Color _getColorForSourceId(String? sourceId, bool isDark) {
    if (sourceId == null || sourceId.isEmpty) {
      return isDark ? AppTheme.darkPrimary : AppTheme.lightPrimary;
    }
    
    // Generate a hash-based hue for consistent colors per source
    final hash = sourceId.hashCode;
    final hue = (hash % 360).abs().toDouble();
    final saturation = isDark ? 0.6 : 0.7;
    final lightness = isDark ? 0.65 : 0.45;
    
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
  
  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Color color) {
    final direction = (end - start);
    final length = direction.distance;
    if (length < 20) return; // Too short for arrow
    
    final unitDir = direction / length;
    // Position arrowhead slightly before the end (account for node size)
    final arrowTip = end - unitDir * 15;
    
    final arrowSize = 8.0;
    final angle = math.atan2(unitDir.dy, unitDir.dx);
    
    final path = Path();
    path.moveTo(arrowTip.dx, arrowTip.dy);
    path.lineTo(
      arrowTip.dx - arrowSize * math.cos(angle - 0.5),
      arrowTip.dy - arrowSize * math.sin(angle - 0.5),
    );
    path.lineTo(
      arrowTip.dx - arrowSize * math.cos(angle + 0.5),
      arrowTip.dy - arrowSize * math.sin(angle + 0.5),
    );
    path.close();
    
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.positions != positions ||
           oldDelegate.highlightedId != highlightedId ||
           oldDelegate.hoveredId != hoveredId;
  }
}
