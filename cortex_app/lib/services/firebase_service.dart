import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/source.dart' as models;
import '../models/fact.dart';
import '../firebase_options.dart';

/// Service for Firebase authentication and Firestore database operations
class FirebaseService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Initialize Firebase
  static Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // ============ AUTH ============

  /// Get current user
  static User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  static bool get isSignedIn => currentUser != null;

  /// Get current user ID
  static String? get userId => currentUser?.uid;

  /// Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use Firebase's signInWithPopup directly
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // On mobile, use google_sign_in package
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print('Google sign-in error: $e');
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  /// Listen to auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ============ FIRESTORE REFERENCES ============

  static CollectionReference<Map<String, dynamic>> get _sourcesCollection =>
      _firestore.collection('users').doc(userId).collection('sources');

  static CollectionReference<Map<String, dynamic>> get _factsCollection =>
      _firestore.collection('users').doc(userId).collection('facts');

  // ============ SOURCES ============

  /// Fetch all sources for current user
  static Future<List<Map<String, dynamic>>> getSources() async {
    if (!isSignedIn) return [];

    final snapshot = await _sourcesCollection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Create a source
  static Future<void> createSource(
    models.Source source, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!isSignedIn) return;

    await _sourcesCollection.doc(source.id).set({
      'name': source.name,
      'type': source.type.name,
      'metadata': metadata ?? {},
      'createdAt': Timestamp.fromDate(source.createdAt),
      'updatedAt': Timestamp.fromDate(source.updatedAt),
    });
  }

  /// Update a source
  static Future<void> updateSource(
    models.Source source, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!isSignedIn) return;

    final updateData = {
      'name': source.name,
      'type': source.type.name,
      'updatedAt': Timestamp.now(),
    };

    if (metadata != null) {
      updateData['metadata'] = metadata;
    }

    await _sourcesCollection.doc(source.id).update(updateData);
  }

  /// Delete a source
  static Future<void> deleteSource(String id) async {
    if (!isSignedIn) return;

    await _sourcesCollection.doc(id).delete();
  }

  // ============ FACTS ============

  /// Fetch all facts for current user
  static Future<List<Map<String, dynamic>>> getFacts() async {
    if (!isSignedIn) return [];

    final snapshot = await _factsCollection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Create a fact
  static Future<void> createFact(Fact fact) async {
    if (!isSignedIn) return;

    await _factsCollection.doc(fact.id).set({
      'sourceId': fact.sourceId,
      'content': fact.content,
      'subjects': fact.subjects,
      'imageUrl': fact.imageUrl,
      'ocrText': fact.ocrText,
      'repetitions': fact.repetitions,
      'easeFactor': fact.easeFactor,
      'interval': fact.interval,
      'nextReviewAt': fact.nextReviewAt != null
          ? Timestamp.fromDate(fact.nextReviewAt!)
          : null,
      'createdAt': Timestamp.fromDate(fact.createdAt),
      'updatedAt': Timestamp.fromDate(fact.updatedAt),
      'embedding': fact.embedding,
    });
  }

  /// Update a fact
  static Future<void> updateFact(Fact fact) async {
    if (!isSignedIn) return;

    await _factsCollection.doc(fact.id).update({
      'content': fact.content,
      'subjects': fact.subjects,
      'repetitions': fact.repetitions,
      'easeFactor': fact.easeFactor,
      'interval': fact.interval,
      'nextReviewAt': fact.nextReviewAt != null
          ? Timestamp.fromDate(fact.nextReviewAt!)
          : null,
      'updatedAt': Timestamp.now(),
      'embedding': fact.embedding,
    });
  }

  /// Delete a fact
  static Future<void> deleteFact(String id) async {
    if (!isSignedIn) return;

    await _factsCollection.doc(id).delete();
  }

  // ============ SYNC ============

  /// Sync local data to cloud (full push)
  static Future<void> syncToCloud(
    List<models.Source> sources,
    List<Fact> facts,
  ) async {
    if (!isSignedIn) return;

    final batch = _firestore.batch();

    // Upsert all sources
    for (final source in sources) {
      final docRef = _sourcesCollection.doc(source.id);
      batch.set(docRef, {
        'name': source.name,
        'type': source.type.name,
        'metadata': {}, // Empty metadata for sources created in Flutter app
        'createdAt': Timestamp.fromDate(source.createdAt),
        'updatedAt': Timestamp.fromDate(source.updatedAt),
      }, SetOptions(merge: true));
    }

    // Upsert all facts
    for (final fact in facts) {
      final docRef = _factsCollection.doc(fact.id);
      batch.set(docRef, {
        'sourceId': fact.sourceId,
        'content': fact.content,
        'subjects': fact.subjects,
        'imageUrl': fact.imageUrl,
        'ocrText': fact.ocrText,
        'repetitions': fact.repetitions,
        'easeFactor': fact.easeFactor,
        'interval': fact.interval,
        'nextReviewAt': fact.nextReviewAt != null
            ? Timestamp.fromDate(fact.nextReviewAt!)
            : null,
        'createdAt': Timestamp.fromDate(fact.createdAt),
        'updatedAt': Timestamp.fromDate(fact.updatedAt),
        'embedding': fact.embedding,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Sync from cloud to local (full pull)
  static Future<({List<models.Source> sources, List<Fact> facts})>
  syncFromCloud() async {
    if (!isSignedIn) return (sources: <models.Source>[], facts: <Fact>[]);

    // Fetch sources
    final sourcesData = await getSources();
    final sources = sourcesData.map((data) {
      return models.Source(
        id: data['id'],
        name: data['name'],
        type: models.SourceType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => models.SourceType.other,
        ),
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      );
      // Note: metadata field is ignored in Flutter app's Source model
    }).toList();

    // Fetch facts
    final factsData = await getFacts();
    final facts = factsData.map((data) {
      return Fact(
        id: data['id'],
        content: data['content'] ?? '',
        sourceId: data['sourceId'] ?? '',
        subjects: List<String>.from(data['subjects'] ?? []),
        imageUrl: data['imageUrl'],
        ocrText: data['ocrText'],
        repetitions: data['repetitions'] ?? 0,
        easeFactor: (data['easeFactor'] ?? 2.5).toDouble(),
        interval: data['interval'] ?? 0,
        nextReviewAt: data['nextReviewAt'] != null
            ? (data['nextReviewAt'] as Timestamp).toDate()
            : null,
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        updatedAt: (data['updatedAt'] as Timestamp).toDate(),
        embedding: data['embedding'] != null
            ? List<double>.from((data['embedding'] as List).map((e) => (e as num).toDouble()))
            : null,
      );
    }).toList();

    return (sources: sources, facts: facts);
  }

  /// Real-time listener for sources
  static Stream<List<models.Source>> sourcesStream() {
    if (!isSignedIn) {
      debugPrint('[FirebaseService] sourcesStream: User not signed in');
      return Stream.value([]);
    }

    debugPrint(
      '[FirebaseService] sourcesStream: Listening to sources for user $userId',
    );

    return _sourcesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '[FirebaseService] sourcesStream: Received ${snapshot.docs.length} documents',
          );
          return snapshot.docs.map((doc) {
            final data = doc.data();
            debugPrint(
              '[FirebaseService] Source doc: ${doc.id} - ${data['name']}',
            );
            return models.Source(
              id: doc.id,
              name: data['name'],
              type: models.SourceType.values.firstWhere(
                (t) => t.name == data['type'],
                orElse: () => models.SourceType.other,
              ),
              createdAt: (data['createdAt'] as Timestamp).toDate(),
              updatedAt: (data['updatedAt'] as Timestamp).toDate(),
            );
            // Note: metadata field is ignored in Flutter app's Source model
          }).toList();
        });
  }

  /// Real-time listener for facts
  static Stream<List<Fact>> factsStream() {
    if (!isSignedIn) {
      debugPrint('[FirebaseService] factsStream: User not signed in');
      return Stream.value([]);
    }

    debugPrint(
      '[FirebaseService] factsStream: Listening to facts for user $userId',
    );

    return _factsCollection.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      debugPrint(
        '[FirebaseService] factsStream: Received ${snapshot.docs.length} documents',
      );
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final content = data['content']?.toString() ?? '';
        final preview = content.length > 50
            ? content.substring(0, 50)
            : content;
        debugPrint('[FirebaseService] Fact doc: ${doc.id} - $preview...');
        return Fact(
          id: doc.id,
          content: data['content'] ?? '',
          sourceId: data['sourceId'] ?? '',
          subjects: List<String>.from(data['subjects'] ?? []),
          imageUrl: data['imageUrl'],
          ocrText: data['ocrText'],
          repetitions: data['repetitions'] ?? 0,
          easeFactor: (data['easeFactor'] ?? 2.5).toDouble(),
          interval: data['interval'] ?? 0,
          nextReviewAt: data['nextReviewAt'] != null
              ? (data['nextReviewAt'] as Timestamp).toDate()
              : null,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          updatedAt: (data['updatedAt'] as Timestamp).toDate(),
          embedding: data['embedding'] != null
              ? List<double>.from((data['embedding'] as List).map((e) => (e as num).toDouble()))
              : null,
        );
      }).toList();
    });
  }
}
