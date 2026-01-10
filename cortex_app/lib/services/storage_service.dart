import 'package:hive_flutter/hive_flutter.dart';
import '../models/source.dart';
import '../models/fact.dart';

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
}

/// Hive implementation of StorageService
class HiveStorageService implements StorageService {
  static const String _sourcesBox = 'sources';
  static const String _factsBox = 'facts';
  
  late Box<Source> _sources;
  late Box<Fact> _facts;
  
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
    
    // Open boxes
    _sources = await Hive.openBox<Source>(_sourcesBox);
    _facts = await Hive.openBox<Fact>(_factsBox);
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
}
