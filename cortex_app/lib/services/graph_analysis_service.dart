import '../models/fact.dart';
import '../models/fact_link.dart';
import 'embedding_service.dart';

/// Analysis result representing a cluster of facts
class FactCluster {
  final String id;
  final String label; // e.g. "Space & Astronomy" or "Cluster #1"
  final List<String> factIds;
  final double cohesion; // 0.0 to 1.0, how tightly connected/similar it is
  
  FactCluster({
    required this.id,
    required this.label,
    required this.factIds,
    this.cohesion = 1.0,
  });
}

/// Service for advanced graph analysis (clustering, islands, etc.)
class GraphAnalysisService {
  final EmbeddingService _embeddingService;
  
  GraphAnalysisService(this._embeddingService);
  
  /// Find connected components in the graph (Islands)
  /// Returns a list of clusters, where each cluster is a connected component
  List<FactCluster> findConnectedComponents(
    List<Fact> facts, 
    List<FactLink> links, {
    int minSize = 2,
  }) {
    if (facts.isEmpty) return [];
    
    // Build adjacency list (manual links only for structural components)
    final adj = <String, Set<String>>{};
    for (final f in facts) {
      adj[f.id] = {};
    }
    
    for (final link in links) {
      if (adj.containsKey(link.sourceFactId) && adj.containsKey(link.targetFactId)) {
        adj[link.sourceFactId]!.add(link.targetFactId);
        adj[link.targetFactId]!.add(link.sourceFactId);
      }
    }
    
    final visited = <String>{};
    final components = <FactCluster>[];
    int clusterIndex = 1;
    
    for (final fact in facts) {
      if (visited.contains(fact.id)) continue;
      
      final componentIds = <String>[];
      final stack = [fact.id];
      visited.add(fact.id);
      
      while (stack.isNotEmpty) {
        final current = stack.removeLast();
        componentIds.add(current);
        
        for (final neighbor in adj[current]!) {
          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            stack.add(neighbor);
          }
        }
      }
      
      // Filter out singletons if requested, or keep them
      // For "Islands", we usually want small isolated components (size 2-5)
      // For general components, we return everything
      if (componentIds.length >= minSize) {
        // Simple label heuristic: use the subject of the most connected node
        // For now, just "Island #X"
        components.add(FactCluster(
          id: 'island_$clusterIndex',
          label: 'Island #$clusterIndex',
          factIds: componentIds,
          cohesion: 1.0, // Structural components are by definition 100% connected in their world
        ));
        clusterIndex++;
      }
    }
    
    return components;
  }
  
  /// Find semantic clusters based on embedding similarity
  Future<List<FactCluster>> findSemanticClusters(
    List<Fact> facts, {
    double threshold = 0.85,
    int minSize = 3,
  }) async {
    final clusters = <FactCluster>[];
    final validFacts = facts.where((f) => f.embedding != null).toList();
    if (validFacts.isEmpty) return [];
    
    final visited = <String>{};
    int clusterIndex = 1;
    
    for (int i = 0; i < validFacts.length; i++) {
      final seed = validFacts[i];
      if (visited.contains(seed.id)) continue;
      
      // Grow cluster from seed
      // This is a simplified density-based clustering
      final clusterMembers = <Fact>[seed];
      final frontier = [seed];
      visited.add(seed.id);
      
      while (frontier.isNotEmpty) {
        final current = frontier.removeLast();
        
        for (int j = 0; j < validFacts.length; j++) {
          final candidate = validFacts[j];
          if (visited.contains(candidate.id)) continue;
          
          final sim = EmbeddingService.cosineSimilarity(
            current.embedding!,
            candidate.embedding!,
          );
          
          if (sim >= threshold) {
            visited.add(candidate.id);
            clusterMembers.add(candidate);
            frontier.add(candidate);
          }
        }
      }
      
      if (clusterMembers.length >= minSize) {
        // Generate label from most common subject
        final subjects = <String, int>{};
        for (final f in clusterMembers) {
          for (final s in f.subjects) {
            subjects[s] = (subjects[s] ?? 0) + 1;
          }
        }
        
        String label = 'Semantic Cluster #$clusterIndex';
        if (subjects.isNotEmpty) {
          final sortedSubjects = subjects.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          label = sortedSubjects.first.key;
          if (sortedSubjects.length > 1) {
             // If the top subject doesn't cover mostly everyone, maybe combine?
             // For now simple is fine.
          }
        }
        
        clusters.add(FactCluster(
          id: 'cluster_$clusterIndex',
          label: label,
          factIds: clusterMembers.map((f) => f.id).toList(),
          cohesion: 0.9, // Approximation
        ));
        clusterIndex++;
      }
    }
    
    return clusters;
  }
  
  /// Find isolated singletons (facts with NO manual links)
  List<Fact> findOrphans(List<Fact> facts, List<FactLink> links) {
    final linkedIds = <String>{};
    for (final l in links) {
      linkedIds.add(l.sourceFactId);
      linkedIds.add(l.targetFactId);
    }
    return facts.where((f) => !linkedIds.contains(f.id)).toList();
  }
}
