import 'package:flutter/material.dart';
import '../models/source.dart';
import '../models/fact.dart';
import '../models/fact_link.dart';
import '../services/storage_service.dart';
import '../services/firebase_service.dart';
import '../services/link_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class DataProvider extends ChangeNotifier {
  final StorageService _storage;
  final Uuid _uuid = const Uuid();
  late final LinkService _linkService;

  List<Source> _sources = [];
  List<Fact> _facts = [];
  List<FactLink> _factLinks = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  StreamSubscription? _sourcesSubscription;
  StreamSubscription? _factsSubscription;

  DataProvider(this._storage) {
    _linkService = LinkService(_storage);
  }

  List<Source> get sources => _sources;
  List<Fact> get facts => _facts;
  List<FactLink> get factLinks => _factLinks;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;

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
  }

  /// Stop Firebase listeners
  void stopFirebaseListeners() {
    _sourcesSubscription?.cancel();
    _factsSubscription?.cancel();
  }

  /// Merge Firebase sources with local sources
  void _mergeSources(List<Source> firebaseSources) {
    bool hasChanges = false;

    for (final firebaseSource in firebaseSources) {
      final localIndex = _sources.indexWhere((s) => s.id == firebaseSource.id);

      if (localIndex == -1) {
        // New source from Firebase - add it locally
        _sources.add(firebaseSource);
        _storage.saveSource(firebaseSource);
        hasChanges = true;
      } else {
        // Source exists - update if Firebase version is newer
        final localSource = _sources[localIndex];
        if (firebaseSource.updatedAt.isAfter(localSource.updatedAt)) {
          _sources[localIndex] = firebaseSource;
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
    final factsToRemove = _facts.where((f) => !firebaseIds.contains(f.id)).toList();
    for (final fact in factsToRemove) {
      _facts.removeWhere((f) => f.id == fact.id);
      await _storage.deleteFact(fact.id);
      // Remove associated links
      final linksToRemove = _factLinks.where((l) => 
        l.sourceFactId == fact.id || l.targetFactId == fact.id
      ).toList();
      for (final link in linksToRemove) {
        _factLinks.removeWhere((l) => l.id == link.id);
        await _storage.deleteFactLink(link.id);
      }
      hasChanges = true;
    }

    for (final firebaseFact in firebaseFacts) {
      final localIndex = _facts.indexWhere((f) => f.id == firebaseFact.id);

      if (localIndex == -1) {
        // New fact from Firebase - add it locally
        _facts.add(firebaseFact);
        _storage.saveFact(firebaseFact);
        hasChanges = true;
      } else {
        // Fact exists - update if Firebase version is newer
        final localFact = _facts[localIndex];
        if (firebaseFact.updatedAt.isAfter(localFact.updatedAt)) {
          _facts[localIndex] = firebaseFact;
          _storage.saveFact(firebaseFact);
          hasChanges = true;
        }
      }
    }

    if (hasChanges) {
      // Refresh links when facts change
      await refreshAllLinks();
      notifyListeners();
    }
  }

  Future<void> _loadData() async {
    _sources = await _storage.getAllSources();
    _facts = await _storage.getAllFacts();
    _factLinks = await _storage.getAllFactLinks();
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
    final source = Source.create(id: _uuid.v4(), name: name, type: type);

    // Save locally
    await _storage.saveSource(source);
    _sources.add(source);

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
    _facts.add(fact);

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
    final index = _facts.indexWhere((f) => f.id == fact.id);
    if (index != -1) {
      _facts[index] = fact;
    }

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
      _facts,
      _factLinks,
    );

    // Save new links
    for (final link in newLinks) {
      await _storage.saveFactLink(link);
      _factLinks.add(link);
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
    debugPrint('Refreshing links for ${_facts.length} facts...');

    // Clear existing links
    _factLinks.clear();
    final allLinks = await _storage.getAllFactLinks();
    for (final link in allLinks) {
      await _storage.deleteFactLink(link.id);
    }

    // Recreate links for all facts
    for (final fact in _facts) {
      await _updateLinksForFact(fact);
    }

    debugPrint('Link refresh complete. Total links: ${_factLinks.length}');
    notifyListeners();
  }

  /// Update a source
  Future<void> updateSource(Source source) async {
    // Update locally
    await _storage.saveSource(source);
    final index = _sources.indexWhere((s) => s.id == source.id);
    if (index != -1) {
      _sources[index] = source;
    }

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
    _sources.removeWhere((s) => s.id == sourceId);

    // Get facts to delete
    final factsToDelete = _facts.where((f) => f.sourceId == sourceId).toList();
    _facts.removeWhere((f) => f.sourceId == sourceId);

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
    _facts.removeWhere((f) => f.id == factId);

    // Delete associated links
    final linksToDelete = _factLinks.where((link) {
      return link.sourceFactId == factId || link.targetFactId == factId;
    }).toList();

    for (final link in linksToDelete) {
      await _storage.deleteFactLink(link.id);
      _factLinks.removeWhere((l) => l.id == link.id);
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

  @override
  void dispose() {
    stopFirebaseListeners();
    super.dispose();
  }
}
