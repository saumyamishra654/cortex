import '../models/fact.dart';
import '../models/fact_link.dart';
import '../models/smart_collection.dart';
import 'embedding_service.dart';
import 'graph_analysis_service.dart';

/// Service for executing smart collection filters
class CollectionService {
  final GraphAnalysisService _analysisService;
  
  CollectionService() : _analysisService = GraphAnalysisService(EmbeddingService());

  /// Generate dynamic collections based on graph analysis
  Future<List<SmartCollection>> generateDynamicCollections(
    List<Fact> facts, 
    List<FactLink> links,
  ) async {
    final collections = <SmartCollection>[];
    
    // 1. Semantic Clusters
    final semanticClusters = await _analysisService.findSemanticClusters(facts, threshold: 0.8);
    for (final cluster in semanticClusters) {
      collections.add(SmartCollection.dynamic(
        id: cluster.id,
        name: cluster.label,
        type: CollectionType.cluster,
        icon: 'bubble_chart',
        params: {'factCount': cluster.factIds.length.toString()},
        filters: [
          CollectionFilter(
            field: FilterField.id,
            operator: FilterOperator.isIn,
            value: cluster.factIds.join(','),
          ),
        ],
      ));
    }
    
    // 2. Structural Islands
    final islands = _analysisService.findConnectedComponents(facts, links);
    for (final island in islands) {
      if (island.factIds.length < 2) continue; // Skip singletons
      
      collections.add(SmartCollection.dynamic(
        id: island.id,
        name: island.label,
        type: CollectionType.structure,
        icon: 'share',
        params: {'factCount': island.factIds.length.toString()},
        filters: [
          CollectionFilter(
            field: FilterField.id,
            operator: FilterOperator.isIn,
            value: island.factIds.join(','),
          ),
        ],
      ));
    }
    
    return collections;
  }
  /// Execute filters on a list of facts
  List<Fact> executeFilters(
    List<Fact> facts,
    List<CollectionFilter> filters,
    List<FactLink> allLinks,
  ) {
    var results = List<Fact>.from(facts);
    
    for (final filter in filters) {
      results = results.where((fact) => _matchesFilter(fact, filter, allLinks)).toList();
    }
    
    return results;
  }
  
  /// Sort facts by the specified field
  List<Fact> sortFacts(
    List<Fact> facts,
    SortField field,
    bool descending,
    List<FactLink> allLinks,
  ) {
    final sorted = List<Fact>.from(facts);
    
    sorted.sort((a, b) {
      int comparison;
      switch (field) {
        case SortField.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SortField.updatedAt:
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
        case SortField.linkCount:
          final aLinks = _getLinkCount(a.id, allLinks);
          final bLinks = _getLinkCount(b.id, allLinks);
          comparison = aLinks.compareTo(bLinks);
          break;
        case SortField.nextReviewAt:
          final aDate = a.nextReviewAt ?? DateTime(2100);
          final bDate = b.nextReviewAt ?? DateTime(2100);
          comparison = aDate.compareTo(bDate);
          break;
      }
      return descending ? -comparison : comparison;
    });
    
    return sorted;
  }
  
  /// Execute a smart collection and return matching facts
  List<Fact> executeCollection(
    SmartCollection collection,
    List<Fact> allFacts,
    List<FactLink> allLinks,
  ) {
    var results = executeFilters(allFacts, collection.filters, allLinks);
    results = sortFacts(results, collection.sortField, collection.sortDescending, allLinks);
    return results;
  }
  
  bool _matchesFilter(Fact fact, CollectionFilter filter, List<FactLink> allLinks) {
    switch (filter.field) {
      case FilterField.source:
        if (filter.operator == FilterOperator.isIn) {
          final sources = filter.value.split(',');
          return sources.contains(fact.sourceId);
        }
        return _matchString(fact.sourceId, filter.operator, filter.value);
      
      case FilterField.subject:
        if (filter.operator == FilterOperator.isIn) {
          final tags = filter.value.split(',').map((t) => t.toLowerCase()).toSet();
          // Match if fact has ANY of the selected tags
          return fact.subjects.any((s) => tags.contains(s.toLowerCase()));
        }
        switch (filter.operator) {
          case FilterOperator.contains:
            return fact.subjects.any((s) => 
                s.toLowerCase().contains(filter.value.toLowerCase()));
          case FilterOperator.equals:
            return fact.subjects.any((s) => 
                s.toLowerCase() == filter.value.toLowerCase());
          default:
            return false;
        }
      
      case FilterField.createdAt:
        return _matchDate(fact.createdAt, filter.operator, filter.value);
      
      case FilterField.linkCount:
        final count = _getLinkCount(fact.id, allLinks);
        return _matchNumber(count, filter.operator, int.tryParse(filter.value) ?? 0);
      
      case FilterField.hasEmbedding:
        final hasEmbedding = fact.embedding != null;
        return filter.operator == FilterOperator.isTrue ? hasEmbedding : !hasEmbedding;
      
      case FilterField.isDue:
        final isDue = fact.isDueForReview;
        return filter.operator == FilterOperator.isTrue ? isDue : !isDue;
      
      case FilterField.content:
        return _matchString(fact.content, filter.operator, filter.value);
        
      case FilterField.id:
        if (filter.operator == FilterOperator.isIn) {
          final ids = filter.value.split(',');
          return ids.contains(fact.id);
        }
        return _matchString(fact.id, filter.operator, filter.value);
    }
  }
  
  bool _matchString(String value, FilterOperator operator, String target) {
    final valueLower = value.toLowerCase();
    final targetLower = target.toLowerCase();
    
    switch (operator) {
      case FilterOperator.equals:
        return valueLower == targetLower;
      case FilterOperator.notEquals:
        return valueLower != targetLower;
      case FilterOperator.contains:
        return valueLower.contains(targetLower);
      default:
        return false;
    }
  }
  
  bool _matchNumber(int value, FilterOperator operator, int target) {
    switch (operator) {
      case FilterOperator.equals:
        return value == target;
      case FilterOperator.notEquals:
        return value != target;
      case FilterOperator.greaterThan:
        return value > target;
      case FilterOperator.lessThan:
        return value < target;
      default:
        return false;
    }
  }
  
  bool _matchDate(DateTime value, FilterOperator operator, String targetStr) {
    // Parse relative dates like "7d" (7 days ago)
    final now = DateTime.now();
    DateTime target;
    
    if (targetStr.endsWith('d')) {
      final days = int.tryParse(targetStr.substring(0, targetStr.length - 1)) ?? 0;
      target = now.subtract(Duration(days: days));
    } else if (targetStr.endsWith('h')) {
      final hours = int.tryParse(targetStr.substring(0, targetStr.length - 1)) ?? 0;
      target = now.subtract(Duration(hours: hours));
    } else {
      target = DateTime.tryParse(targetStr) ?? now;
    }
    
    switch (operator) {
      case FilterOperator.greaterThan:
        return value.isAfter(target);
      case FilterOperator.lessThan:
        return value.isBefore(target);
      default:
        return false;
    }
  }
  
  int _getLinkCount(String factId, List<FactLink> allLinks) {
    return allLinks.where((l) => 
        l.sourceFactId == factId || l.targetFactId == factId).length;
  }
  
  /// Get built-in collections
  List<SmartCollection> getBuiltInCollections() {
    return [
      SmartCollection.create(
        id: 'builtin_due',
        name: 'Due for Review',
        icon: 'schedule',
        filters: [
          CollectionFilter(
            field: FilterField.isDue,
            operator: FilterOperator.isTrue,
            value: '',
          ),
        ],
        sortField: SortField.nextReviewAt,
        sortDescending: false,
        isBuiltIn: true,
      ),
      SmartCollection.create(
        id: 'builtin_new',
        name: 'New Facts',
        icon: 'new_releases',
        filters: [],
        sortField: SortField.createdAt,
        sortDescending: true,
        isBuiltIn: true,
      ),
      SmartCollection.create(
        id: 'builtin_connected',
        name: 'Highly Connected',
        icon: 'hub',
        filters: [
          CollectionFilter(
            field: FilterField.linkCount,
            operator: FilterOperator.greaterThan,
            value: '2',
          ),
        ],
        sortField: SortField.linkCount,
        sortDescending: true,
        isBuiltIn: true,
      ),
      SmartCollection.create(
        id: 'builtin_unlinked',
        name: 'Unlinked Facts',
        icon: 'link_off',
        filters: [
          CollectionFilter(
            field: FilterField.linkCount,
            operator: FilterOperator.equals,
            value: '0',
          ),
        ],
        sortField: SortField.createdAt,
        sortDescending: true,
        isBuiltIn: true,
      ),
    ];
  }
}
