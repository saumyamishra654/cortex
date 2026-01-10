import 'package:flutter/material.dart';
import '../models/source.dart';
import '../models/fact.dart';
import '../services/storage_service.dart';
import 'package:uuid/uuid.dart';

class DataProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();
  
  List<Source> _sources = [];
  List<Fact> _facts = [];
  bool _isLoading = true;
  
  DataProvider(this._storage);
  
  List<Source> get sources => _sources;
  List<Fact> get facts => _facts;
  bool get isLoading => _isLoading;
  
  /// Initialize and load all data
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    
    await _storage.init();
    await _loadData();
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> _loadData() async {
    _sources = await _storage.getAllSources();
    _facts = await _storage.getAllFacts();
  }
  
  /// Get facts for a specific source
  List<Fact> getFactsForSource(String sourceId) {
    return _facts.where((f) => f.sourceId == sourceId).toList();
  }
  
  /// Get fact count for a source
  int getFactCountForSource(String sourceId) {
    return _facts.where((f) => f.sourceId == sourceId).length;
  }
  
  /// Add a new source
  Future<Source> addSource({
    required String name,
    required SourceType type,
  }) async {
    final source = Source.create(
      id: _uuid.v4(),
      name: name,
      type: type,
    );
    
    await _storage.saveSource(source);
    _sources.add(source);
    notifyListeners();
    
    return source;
  }
  
  /// Add a new fact
  Future<Fact> addFact({
    required String content,
    required String sourceId,
    List<String>? subjects,
    String? imageUrl,
    String? ocrText,
  }) async {
    final fact = Fact.create(
      id: _uuid.v4(),
      content: content,
      sourceId: sourceId,
      subjects: subjects,
      imageUrl: imageUrl,
      ocrText: ocrText,
    );
    
    await _storage.saveFact(fact);
    _facts.add(fact);
    notifyListeners();
    
    return fact;
  }
  
  /// Update a fact (e.g., after SRS review)
  Future<void> updateFact(Fact fact) async {
    await _storage.saveFact(fact);
    final index = _facts.indexWhere((f) => f.id == fact.id);
    if (index != -1) {
      _facts[index] = fact;
    }
    notifyListeners();
  }
  
  /// Update a source
  Future<void> updateSource(Source source) async {
    await _storage.saveSource(source);
    final index = _sources.indexWhere((s) => s.id == source.id);
    if (index != -1) {
      _sources[index] = source;
    }
    notifyListeners();
  }
  
  /// Delete a source and all its facts
  Future<void> deleteSource(String sourceId) async {
    await _storage.deleteSource(sourceId);
    _sources.removeWhere((s) => s.id == sourceId);
    _facts.removeWhere((f) => f.sourceId == sourceId);
    notifyListeners();
  }
  
  /// Delete a fact
  Future<void> deleteFact(String factId) async {
    await _storage.deleteFact(factId);
    _facts.removeWhere((f) => f.id == factId);
    notifyListeners();
  }
  
  /// Get all unique subjects
  List<String> get allSubjects {
    final subjects = <String>{};
    for (final fact in _facts) {
      subjects.addAll(fact.subjects);
    }
    return subjects.toList()..sort();
  }
  
  /// Get facts due for review (unshuffled)
  List<Fact> get dueFacts {
    final now = DateTime.now();
    return _facts.where((f) {
      if (f.nextReviewAt == null) return true;
      return now.isAfter(f.nextReviewAt!);
    }).toList();
  }
  
  /// Get facts due for review (shuffled)
  List<Fact> get dueFactsShuffled {
    final shuffled = List<Fact>.from(dueFacts);
    shuffled.shuffle();
    return shuffled;
  }
  
  /// Get all facts shuffled (for random browse mode)
  List<Fact> get allFactsShuffled {
    final shuffled = List<Fact>.from(_facts);
    shuffled.shuffle();
    return shuffled;
  }
}
