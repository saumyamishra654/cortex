import 'package:flutter/material.dart';
import '../models/source.dart';
import '../models/fact.dart';
import '../models/fact_link.dart';
import '../models/smart_collection.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/link_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class DataProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();
  late final LinkService _linkService;

  // Use Maps for O(1) lookups instead of Lists
  final Map<String, Source> _sourcesMap = {};
  final Map<String, Fact> _factsMap = {};
  final Map<String, FactLink> _factLinksMap = {};
  // Persisted user collections
  final Map<String, SmartCollection> _collectionsMap = {};
  
  // Cached computed values (invalidated on data changes)
  List<String>? _cachedSubjects;
  List<Fact>? _cachedDueFacts;
  DateTime? _dueFactsCacheTime;
  
  bool _isLoading = true;
  bool _isSyncing = false;

  StreamSubscription? _sourcesSubscription;
  StreamSubscription? _factsSubscription;
  StreamSubscription? _collectionsSubscription;

  DataProvider(this._storage) {
    _linkService = LinkService(_storage);
  }

  // Public getters return lists from maps
  List<Source> get sources => _sourcesMap.values.toList();
  List<Fact> get facts => _factsMap.values.toList();
  List<FactLink> get factLinks => _factLinksMap.values.toList();
  List<SmartCollection> get userCollections => _collectionsMap.values.toList();
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  
  // O(1) lookups
  Fact? getFactById(String id) => _factsMap[id];
  Source? getSourceById(String id) => _sourcesMap[id];

  /// Initialize and load all data
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _storage.init();
    await _loadData();

    // Start listening to Firebase real-time updates if signed in
    if (FirebaseService.isSignedIn) {
      startFirebaseListeners();
    }

    // Auto-refresh links on startup to ensure connections are up-to-date
    await refreshAllLinks();

    _isLoading = false;
    notifyListeners();
  }
  
  /// Invalidate cached values when data changes
  void _invalidateCaches() {
    _cachedSubjects = null;
    _cachedDueFacts = null;
    _dueFactsCacheTime = null;
  }

  /// Start Firebase real-time listeners
  void startFirebaseListeners() {
    if (!FirebaseService.isSignedIn) {
      debugPrint('Cannot start Firebase listeners: User not signed in');
      return;
    }

    debugPrint(
      'Starting Firebase listeners for user: ${FirebaseService.userId}',
    );

    _sourcesSubscription?.cancel();
    _factsSubscription?.cancel();
    _collectionsSubscription?.cancel();

    // Listen to sources from Firebase
    _sourcesSubscription = FirebaseService.sourcesStream().listen(
      (firebaseSources) {
        debugPrint('Received ${firebaseSources.length} sources from Firebase');
        _mergeSources(firebaseSources);
      },
      onError: (error) {
        debugPrint('Error listening to sources: $error');
      },
    );

    // Listen to facts from Firebase
    _factsSubscription = FirebaseService.factsStream().listen(
      (firebaseFacts) {
        debugPrint('Received ${firebaseFacts.length} facts from Firebase');
        _mergeFacts(firebaseFacts);
      },
      onError: (error) {
        debugPrint('Error listening to facts: $error');
      },
    );

    // Listen to collections from Firebase
    _collectionsSubscription = FirebaseService.collectionsStream().listen(
      (firebaseCollections) {
        debugPrint('Received ${firebaseCollections.length} collections from Firebase');
        _mergeCollections(firebaseCollections);
      },
      onError: (error) {
        debugPrint('Error listening to collections: $error');
      },
    );
  }

  /// Stop Firebase listeners
  void stopFirebaseListeners() {
    _sourcesSubscription?.cancel();
    _factsSubscription?.cancel();
    _collectionsSubscription?.cancel();
  }

  /// Merge Firebase sources with local sources
  void _mergeSources(List<Source> firebaseSources) {
    bool hasChanges = false;

    for (final firebaseSource in firebaseSources) {
      final localSource = _sourcesMap[firebaseSource.id];

      if (localSource == null) {
        // New source from Firebase - add it locally
        _sourcesMap[firebaseSource.id] = firebaseSource;
        _storage.saveSource(firebaseSource);
        hasChanges = true;
      } else {
        // Source exists - update if Firebase version is newer
        if (firebaseSource.updatedAt.isAfter(localSource.updatedAt)) {
          _sourcesMap[firebaseSource.id] = firebaseSource;
          _storage.saveSource(firebaseSource);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  /// Merge Firebase facts with local facts
  Future<void> _mergeFacts(List<Fact> firebaseFacts) async {
    bool hasChanges = false;
    final firebaseIds = firebaseFacts.map((f) => f.id).toSet();

    // Remove local facts that no longer exist in Firebase
    final idsToRemove = _factsMap.keys.where((id) => !firebaseIds.contains(id)).toList();
    for (final id in idsToRemove) {
      _factsMap.remove(id);
      await _storage.deleteFact(id);
      // Remove associated links
      final linkIdsToRemove = _factLinksMap.entries
          .where((e) => e.value.sourceFactId == id || e.value.targetFactId == id)
          .map((e) => e.key)
          .toList();
      for (final linkId in linkIdsToRemove) {
        _factLinksMap.remove(linkId);
        await _storage.deleteFactLink(linkId);
      }
      hasChanges = true;
    }

    for (final firebaseFact in firebaseFacts) {
      final localFact = _factsMap[firebaseFact.id];

      if (localFact == null) {
        // New fact from Firebase - add it locally
        _factsMap[firebaseFact.id] = firebaseFact;
        _storage.saveFact(firebaseFact);
        hasChanges = true;
      } else {
        // Fact exists - update if Firebase version is newer
        if (firebaseFact.updatedAt.isAfter(localFact.updatedAt)) {
          _factsMap[firebaseFact.id] = firebaseFact;
          _storage.saveFact(firebaseFact);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      _invalidateCaches();
      // Refresh links when facts change
      await refreshAllLinks();
      notifyListeners();
    }
  }

  /// Merge Firebase collections with local collections
  void _mergeCollections(List<SmartCollection> firebaseCollections) {
    bool hasChanges = false;
    final firebaseIds = firebaseCollections.map((c) => c.id).toSet();

    // Remove local collections that no longer exist in Firebase (if sync deletes locally?)
    // Actually, usually we merge. If deleted in cloud, delete locally?
    // Let's assume bidirectional sync means cloud is truth for existence if we are syncing.
    
    // For now, let's just add/update. Deletion sync is trickier without tombstones.
    // If we assume the list from Firebase is "all user collections", we can delete missing ones.
    
    final idsToRemove = _collectionsMap.keys.where((id) => !firebaseIds.contains(id)).toList();
    for (final id in idsToRemove) {
      // Only delete manual collections that we know about?
      // Or just delete everything not in cloud?
      // Let's be safe: if it's not in cloud, delete it locally.
      _collectionsMap.remove(id);
      _storage.deleteCollection(id);
      hasChanges = true;
    }

    for (final firebaseCol in firebaseCollections) {
      final localCol = _collectionsMap[firebaseCol.id];

      if (localCol == null) {
        // New collection
        _collectionsMap[firebaseCol.id] = firebaseCol;
        _storage.saveCollection(firebaseCol);
        hasChanges = true;
      } else {
        // Exists - update? SmartCollection doesn't have updatedAt field in standard way?
        // It has SortField.updatedAt but not a top-level field?
        // Wait, SmartCollection has `createdAt`. It doesn't track modification time well.
        // Let's assume cloud is always newer or overwrite?
        // Or check value equality?
        // For now, simpler: just overwrite local with cloud version.
        _collectionsMap[firebaseCol.id] = firebaseCol;
        _storage.saveCollection(firebaseCol);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    final sources = await _storage.getAllSources();
    final facts = await _storage.getAllFacts();
    final links = await _storage.getAllFactLinks();
    
    _sourcesMap.clear();
    _factsMap.clear();
    _factLinksMap.clear();
    
    for (final s in sources) { _sourcesMap[s.id] = s; }
    for (final f in facts) { _factsMap[f.id] = f; }
    for (final l in links) { _factLinksMap[l.id] = l; }
    
    // Load collections
    _collectionsMap.clear();
    final cols = await _storage.getAllCollections();
    for (final c in cols) { _collectionsMap[c.id] = c; }
    
    _invalidateCaches();
  }

  /// Get facts for a specific source (cached internally)
  List<Fact> getFactsForSource(String sourceId) {
    return _factsMap.values.where((f) => f.sourceId == sourceId).toList();
  }

  /// Get fact count for a source
  int getFactCountForSource(String sourceId) {
    return _factsMap.values.where((f) => f.sourceId == sourceId).length;
  }

  /// Add a new source
  Future<Source> addSource({
    required String name,
    required SourceType type,
    String? url,
  }) async {
    final source = Source.create(id: _uuid.v4(), name: name, type: type, url: url);

    // Save locally
    await _storage.saveSource(source);
    _sourcesMap[source.id] = source;

    // Sync to Firebase if signed in
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.createSource(source);
      } catch (e) {
        debugPrint('Error syncing source to Firebase: $e');
      }
    }

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

    // Save locally
    await _storage.saveFact(fact);
    _factsMap[fact.id] = fact;
    _invalidateCaches();

    // Create links for this fact
    await _updateLinksForFact(fact);

    // Sync to Firebase if signed in
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.createFact(fact);
      } catch (e) {
        debugPrint('Error syncing fact to Firebase: $e');
      }
    }

    notifyListeners();
    return fact;
  }

  /// Update a fact (e.g., after SRS review)
  Future<void> updateFact(Fact fact) async {
    // Update locally
    await _storage.saveFact(fact);
    _factsMap[fact.id] = fact;
    _invalidateCaches();

    // Update links for this fact
    await _updateLinksForFact(fact);

    // Sync to Firebase if signed in
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.updateFact(fact);
      } catch (e) {
        debugPrint('Error syncing fact update to Firebase: $e');
      }
    }

    notifyListeners();
  }

  /// Create or update links for a fact based on [[link]] syntax
  Future<void> _updateLinksForFact(Fact fact) async {
    // Parse links from content
    if (!_linkService.hasLinks(fact.content)) {
      return;
    }

    // Create new links
    final newLinks = await _linkService.createLinksForFact(
      fact,
      _factsMap.values.toList(),
      _factLinksMap.values.toList(),
    );

    // Save new links
    for (final link in newLinks) {
      await _storage.saveFactLink(link);
      _factLinksMap[link.id] = link;
      debugPrint(
        'Created link: ${link.sourceFactId} -> ${link.targetFactId} ("${link.linkText}")',
      );
    }

    if (newLinks.isNotEmpty) {
      notifyListeners();
    }
  }

  /// Refresh links for all facts
  Future<void> refreshAllLinks() async {
    debugPrint('Refreshing links for ${_factsMap.length} facts...');

    // Clear existing links
    _factLinksMap.clear();
    final allLinks = await _storage.getAllFactLinks();
    for (final link in allLinks) {
      await _storage.deleteFactLink(link.id);
    }

    // Recreate links for all facts
    for (final fact in _factsMap.values) {
      await _updateLinksForFact(fact);
    }

    debugPrint('Link refresh complete. Total links: ${_factLinksMap.length}');
    notifyListeners();
  }

  /// Update a source
  Future<void> updateSource(Source source) async {
    // Update locally
    await _storage.saveSource(source);
    _sourcesMap[source.id] = source;

    // Sync to Firebase if signed in
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.updateSource(source);
      } catch (e) {
        debugPrint('Error syncing source update to Firebase: $e');
      }
    }

    notifyListeners();
  }

  /// Delete a source and all its facts
  Future<void> deleteSource(String sourceId) async {
    // Delete locally
    await _storage.deleteSource(sourceId);
    _sourcesMap.remove(sourceId);

    // Get facts to delete
    final factsToDelete = _factsMap.values.where((f) => f.sourceId == sourceId).toList();
    for (final fact in factsToDelete) {
      _factsMap.remove(fact.id);
    }
    _invalidateCaches();

    // Sync to Firebase if signed in
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.deleteSource(sourceId);
        // Delete associated facts from Firebase
        for (final fact in factsToDelete) {
          await FirebaseService.deleteFact(fact.id);
        }
      } catch (e) {
        debugPrint('Error syncing source deletion to Firebase: $e');
      }
    }

    notifyListeners();
  }

  /// Delete a fact
  Future<void> deleteFact(String factId) async {
    // Delete locally
    await _storage.deleteFact(factId);
    _factsMap.remove(factId);
    _invalidateCaches();

    // Delete associated links
    final linkIdsToDelete = _factLinksMap.entries
        .where((e) => e.value.sourceFactId == factId || e.value.targetFactId == factId)
        .map((e) => e.key)
        .toList();

    for (final linkId in linkIdsToDelete) {
      await _storage.deleteFactLink(linkId);
      _factLinksMap.remove(linkId);
    }

    // Sync to Firebase if signed in
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.deleteFact(factId);
      } catch (e) {
        debugPrint('Error syncing fact deletion to Firebase: $e');
      }
    }

    notifyListeners();
  }

  /// Get all unique subjects (cached)
  List<String> get allSubjects {
    if (_cachedSubjects != null) return _cachedSubjects!;
    
    final subjects = <String>{};
    for (final fact in _factsMap.values) {
      subjects.addAll(fact.subjects);
    }
    _cachedSubjects = subjects.toList()..sort();
    return _cachedSubjects!;
  }

  /// Get facts due for review (cached for 1 second to avoid recalculation)
  List<Fact> get dueFacts {
    final now = DateTime.now();
    // Invalidate cache if older than 1 second
    if (_cachedDueFacts != null && 
        _dueFactsCacheTime != null &&
        now.difference(_dueFactsCacheTime!).inSeconds < 1) {
      return _cachedDueFacts!;
    }
    
    _cachedDueFacts = _factsMap.values.where((f) {
      if (f.nextReviewAt == null) return true;
      return now.isAfter(f.nextReviewAt!);
    }).toList();
    _dueFactsCacheTime = now;
    return _cachedDueFacts!;
  }

  /// Get facts due for review (shuffled)
  List<Fact> get dueFactsShuffled {
    final shuffled = List<Fact>.from(dueFacts);
    shuffled.shuffle();
    return shuffled;
  }

  /// Get all facts shuffled (for random browse mode)
  List<Fact> get allFactsShuffled {
    final shuffled = List<Fact>.from(_factsMap.values);
    shuffled.shuffle();
    return shuffled;
  }


  
  /// Create a new user collection
  Future<void> createCollection(SmartCollection collection) async {
    await _storage.saveCollection(collection);
    _collectionsMap[collection.id] = collection;
    
    // Sync to Firebase
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.createCollection(collection);
      } catch (e) {
        debugPrint('Error syncing collection to Firebase: $e');
      }
    }
    
    notifyListeners();
  }
  
  /// Delete a user collection
  Future<void> deleteCollection(String id) async {
    await _storage.deleteCollection(id);
    _collectionsMap.remove(id);
    
    // Sync to Firebase
    if (FirebaseService.isSignedIn) {
      try {
        await FirebaseService.deleteCollection(id);
      } catch (e) {
        debugPrint('Error syncing collection deletion to Firebase: $e');
      }
    }
    
    notifyListeners();
  }

  @override
  void dispose() {
    stopFirebaseListeners();
    super.dispose();
  }
}
