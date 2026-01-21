import 'package:hive_flutter/hive_flutter.dart';
import '../models/source.dart';
import '../models/fact.dart';
import '../models/fact_link.dart';
import '../models/smart_collection.dart';
// Note: Adapters for SmartCollection are assumed to be generated in 'smart_collection.g.dart'
// and should be registered similarly if not already.


/// Abstract storage interface for future backend swapping
abstract class StorageService {
  Future<void> init();

  // Sources
  Future<List<Source>> getAllSources();
  Future<Source?> getSource(String id);
  Future<void> saveSource(Source source);
  Future<void> deleteSource(String id);

  // Facts
  Future<List<Fact>> getAllFacts();
  Future<List<Fact>> getFactsBySource(String sourceId);
  Future<Fact?> getFact(String id);
  Future<void> saveFact(Fact fact);
  Future<void> deleteFact(String id);
  Future<int> getFactCountForSource(String sourceId);
  Future<List<Fact>> getDueFacts();

  // FactLinks
  Future<List<FactLink>> getAllFactLinks();
  Future<FactLink?> getFactLink(String id);
  Future<void> saveFactLink(FactLink link);
  Future<void> deleteFactLink(String id);
  Future<List<FactLink>> getFactLinksForFact(String factId);
  
  // Collections
  Future<List<SmartCollection>> getAllCollections();
  Future<void> saveCollection(SmartCollection collection);
  Future<void> deleteCollection(String id);
}

/// Hive implementation of StorageService
class HiveStorageService implements StorageService {
  static const String _sourcesBox = 'sources';
  static const String _factsBox = 'facts';
  static const String _factLinksBox = 'factLinks';
  static const String _collectionsBox = 'collections';

  late Box<Source> _sources;
  late Box<Fact> _facts;
  late Box<FactLink> _factLinks;
  late Box<SmartCollection> _collections;

  @override
  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SourceTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SourceAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(FactAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(FactLinkAdapter());
    }
    // Register SmartCollection adapters (Ids 4-9) if available
    try {
      if (!Hive.isAdapterRegistered(8)) {
        Hive.registerAdapter(SmartCollectionAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(FilterFieldAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(FilterOperatorAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(SortFieldAdapter());
      }
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(CollectionFilterAdapter());
      }
      if (!Hive.isAdapterRegistered(9)) {
        Hive.registerAdapter(CollectionTypeAdapter());
      }
    } catch (e) {
      // Ignore registration errors if adapters are missing (during dev)
      print('Warning: SmartCollection adapters might be missing: $e');
    }

    // Open boxes
    _sources = await Hive.openBox<Source>(_sourcesBox);
    _facts = await Hive.openBox<Fact>(_factsBox);
    _factLinks = await Hive.openBox<FactLink>(_factLinksBox);
    _collections = await Hive.openBox<SmartCollection>(_collectionsBox);
  }

  // Sources
  @override
  Future<List<Source>> getAllSources() async {
    return _sources.values.toList();
  }

  @override
  Future<Source?> getSource(String id) async {
    return _sources.get(id);
  }

  @override
  Future<void> saveSource(Source source) async {
    await _sources.put(source.id, source);
  }

  @override
  Future<void> deleteSource(String id) async {
    await _sources.delete(id);
    // Also delete all facts for this source
    final factsToDelete = _facts.values.where((f) => f.sourceId == id).toList();
    for (final fact in factsToDelete) {
      await _facts.delete(fact.id);
    }
  }

  // Facts
  @override
  Future<List<Fact>> getAllFacts() async {
    return _facts.values.toList();
  }

  @override
  Future<List<Fact>> getFactsBySource(String sourceId) async {
    return _facts.values.where((f) => f.sourceId == sourceId).toList();
  }

  @override
  Future<Fact?> getFact(String id) async {
    return _facts.get(id);
  }

  @override
  Future<void> saveFact(Fact fact) async {
    await _facts.put(fact.id, fact);
  }

  @override
  Future<void> deleteFact(String id) async {
    await _facts.delete(id);
  }

  @override
  Future<int> getFactCountForSource(String sourceId) async {
    return _facts.values.where((f) => f.sourceId == sourceId).length;
  }

  @override
  Future<List<Fact>> getDueFacts() async {
    final now = DateTime.now();
    return _facts.values.where((f) {
      if (f.nextReviewAt == null) return true;
      return now.isAfter(f.nextReviewAt!);
    }).toList();
  }

  // FactLinks
  @override
  Future<List<FactLink>> getAllFactLinks() async {
    return _factLinks.values.toList();
  }

  @override
  Future<FactLink?> getFactLink(String id) async {
    return _factLinks.get(id);
  }

  @override
  Future<void> saveFactLink(FactLink link) async {
    await _factLinks.put(link.id, link);
  }

  @override
  Future<void> deleteFactLink(String id) async {
    await _factLinks.delete(id);
  }

  @override
  Future<List<FactLink>> getFactLinksForFact(String factId) async {
    return _factLinks.values.where((link) {
      return link.sourceFactId == factId || link.targetFactId == factId;
    }).toList();
  }
  
  // Collections implementation
  @override
  Future<List<SmartCollection>> getAllCollections() async {
    return _collections.values.toList();
  }
  
  @override
  Future<void> saveCollection(SmartCollection collection) async {
    await _collections.put(collection.id, collection);
  }
  
  @override
  Future<void> deleteCollection(String id) async {
    await _collections.delete(id);
  }
}
