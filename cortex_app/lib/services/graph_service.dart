import 'dart:math';
import 'dart:ui' show Color, Offset, Size;
import 'package:flutter/painting.dart' show HSLColor;
import '../models/fact.dart';
import '../models/fact_link.dart';
import 'embedding_service.dart';

/// Service for building and managing the knowledge graph
class GraphService {
  final EmbeddingService? embeddingService;
  
  // Threshold for creating semantic edges
  static const double semanticEdgeThreshold = 0.75;
  
  GraphService([this.embeddingService]);
  
  /// Build graph data from facts and links
  GraphData buildGraph(
    List<Fact> facts,
    List<FactLink> links, {
    bool includeSemanticEdges = true,
  }) {
    final nodes = <GraphNode>[];
    final edges = <GraphEdge>[];
    
    // Create nodes for each fact
    for (final fact in facts) {
      final linkCount = _getLinkCount(fact.id, links);
      nodes.add(GraphNode(
        id: fact.id,
        fact: fact,
        linkCount: linkCount,
      ));
    }
    
    // Create edges from manual links
    for (final link in links) {
      edges.add(GraphEdge(
        sourceId: link.sourceFactId,
        targetId: link.targetFactId,
        type: EdgeType.manual,
        weight: 1.0,
        linkText: link.linkText,
      ));
    }
    
    // Create semantic edges from embeddings
    if (includeSemanticEdges && embeddingService != null) {
      final semanticEdges = _buildSemanticEdges(facts);
      edges.addAll(semanticEdges);
    }
    
    return GraphData(nodes: nodes, edges: edges);
  }
  
  List<GraphEdge> _buildSemanticEdges(List<Fact> facts) {
    final edges = <GraphEdge>[];
    if (embeddingService == null) return edges;
    
    for (int i = 0; i < facts.length; i++) {
      if (facts[i].embedding == null) continue;
      
      for (int j = i + 1; j < facts.length; j++) {
        if (facts[j].embedding == null) continue;
        
        final similarity = EmbeddingService.cosineSimilarity(
          facts[i].embedding!,
          facts[j].embedding!,
        );
        
        if (similarity >= semanticEdgeThreshold) {
          edges.add(GraphEdge(
            sourceId: facts[i].id,
            targetId: facts[j].id,
            type: EdgeType.semantic,
            weight: similarity,
          ));
        }
      }
    }
    
    return edges;
  }
  
  int _getLinkCount(String factId, List<FactLink> links) {
    return links.where((l) => 
        l.sourceFactId == factId || l.targetFactId == factId).length;
  }
  
  /// Calculate force-directed layout positions
  Map<String, Offset> calculateLayout(
    GraphData graph, {
    required Size size,
    int iterations = 50,
  }) {
    final positions = <String, Offset>{};
    final velocities = <String, Offset>{};
    final random = Random(42); // Reproducible layout
    
    // Initialize random positions
    for (final node in graph.nodes) {
      positions[node.id] = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      velocities[node.id] = Offset.zero;
    }
    
    // Force-directed simulation
    const repulsionStrength = 5000.0;
    const attractionStrength = 0.01;
    const damping = 0.85;
    const minDistance = 50.0;
    
    for (int iter = 0; iter < iterations; iter++) {
      // Apply repulsion between all nodes
      for (final node1 in graph.nodes) {
        var force = Offset.zero;
        
        for (final node2 in graph.nodes) {
          if (node1.id == node2.id) continue;
          
          final pos1 = positions[node1.id]!;
          final pos2 = positions[node2.id]!;
          final delta = pos1 - pos2;
          final distance = max(delta.distance, minDistance);
          
          // Repulsion force (inverse square)
          final repulsion = delta / distance * (repulsionStrength / (distance * distance));
          force = force + repulsion;
        }
        
        // Apply attraction for connected nodes
        for (final edge in graph.edges) {
          String? connectedId;
          if (edge.sourceId == node1.id) {
            connectedId = edge.targetId;
          } else if (edge.targetId == node1.id) {
            connectedId = edge.sourceId;
          }
          
          if (connectedId != null) {
            final pos1 = positions[node1.id]!;
            final pos2 = positions[connectedId]!;
            final delta = pos2 - pos1;
            
            // Attraction force (proportional to distance and edge weight)
            final attraction = delta * attractionStrength * edge.weight;
            force = force + attraction;
          }
        }
        
        // Update velocity and position
        velocities[node1.id] = (velocities[node1.id]! + force) * damping;
        positions[node1.id] = positions[node1.id]! + velocities[node1.id]!;
        
        // Keep within bounds
        positions[node1.id] = Offset(
          positions[node1.id]!.dx.clamp(20, size.width - 20),
          positions[node1.id]!.dy.clamp(20, size.height - 20),
        );
      }
    }
    
    return positions;
  }
  
  /// Get subgraph centered on a specific fact
  GraphData getSubgraph(
    String centerId,
    GraphData fullGraph, {
    int depth = 2,
  }) {
    final includedIds = <String>{centerId};
    var frontier = <String>{centerId};
    
    for (int d = 0; d < depth; d++) {
      final newFrontier = <String>{};
      
      for (final id in frontier) {
        for (final edge in fullGraph.edges) {
          if (edge.sourceId == id && !includedIds.contains(edge.targetId)) {
            newFrontier.add(edge.targetId);
          }
          if (edge.targetId == id && !includedIds.contains(edge.sourceId)) {
            newFrontier.add(edge.sourceId);
          }
        }
      }
      
      includedIds.addAll(newFrontier);
      frontier = newFrontier;
    }
    
    final nodes = fullGraph.nodes
        .where((n) => includedIds.contains(n.id))
        .toList();
    
    final edges = fullGraph.edges
        .where((e) => includedIds.contains(e.sourceId) && 
                      includedIds.contains(e.targetId))
        .toList();
    
    return GraphData(nodes: nodes, edges: edges);
  }
}

/// A node in the knowledge graph
class GraphNode {
  final String id;
  final Fact fact;
  final int linkCount;
  
  GraphNode({
    required this.id,
    required this.fact,
    required this.linkCount,
  });
  
  /// Node size based on connections
  double get size => 12.0 + (linkCount * 4).clamp(0, 20).toDouble();
}

/// Edge types in the graph
enum EdgeType { manual, semantic }

/// An edge in the knowledge graph
class GraphEdge {
  final String sourceId;
  final String targetId;
  final EdgeType type;
  final double weight; // 0-1 for semantic, 1.0 for manual
  final String? linkText; // The [[link]] text for manual links
  
  GraphEdge({
    required this.sourceId,
    required this.targetId,
    required this.type,
    required this.weight,
    this.linkText,
  });
  
  /// Generate a consistent color for a link text
  static Color colorForLinkText(String? text, bool isDark) {
    if (text == null || text.isEmpty) {
      return isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2);
    }
    // Generate a hash-based hue for consistent colors
    final hash = text.toLowerCase().hashCode;
    final hue = (hash % 360).abs().toDouble();
    final saturation = isDark ? 0.6 : 0.7;
    final lightness = isDark ? 0.65 : 0.45;
    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }
}

/// Complete graph data
class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  
  GraphData({
    required this.nodes,
    required this.edges,
  });
  
  bool get isEmpty => nodes.isEmpty;
}
