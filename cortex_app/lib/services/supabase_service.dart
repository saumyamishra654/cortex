import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/source.dart';
import '../models/fact.dart';

/// Service for Supabase authentication and database operations
class SupabaseService {
  static const String supabaseUrl = 'https://xbwlndlgvfjnnhyxotzz.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_nKkjdTBIDPsU8x5_GZd34g_ybqjLEzQ';
  
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Initialize Supabase
  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  // ============ AUTH ============
  
  /// Get current user
  static User? get currentUser => client.auth.currentUser;
  
  /// Check if user is signed in
  static bool get isSignedIn => currentUser != null;
  
  /// Sign in with Google
  static Future<bool> signInWithGoogle() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'https://saumyamishra654.github.io/cortex/',
    );
  }
  
  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
  
  // ============ SOURCES ============
  
  /// Fetch all sources for current user
  static Future<List<Map<String, dynamic>>> getSources() async {
    final response = await client
        .from('sources')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Create a source
  static Future<Map<String, dynamic>> createSource(Source source) async {
    final response = await client.from('sources').insert({
      'id': source.id,
      'user_id': currentUser!.id,
      'name': source.name,
      'type': source.type.name,
      'created_at': source.createdAt.toIso8601String(),
      'updated_at': source.updatedAt.toIso8601String(),
    }).select().single();
    return response;
  }
  
  /// Update a source
  static Future<void> updateSource(Source source) async {
    await client.from('sources').update({
      'name': source.name,
      'type': source.type.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', source.id);
  }
  
  /// Delete a source
  static Future<void> deleteSource(String id) async {
    await client.from('sources').delete().eq('id', id);
  }
  
  // ============ FACTS ============
  
  /// Fetch all facts for current user
  static Future<List<Map<String, dynamic>>> getFacts() async {
    final response = await client
        .from('facts')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Create a fact
  static Future<Map<String, dynamic>> createFact(Fact fact) async {
    final response = await client.from('facts').insert({
      'id': fact.id,
      'user_id': currentUser!.id,
      'source_id': fact.sourceId,
      'content': fact.content,
      'subjects': fact.subjects,
      'image_url': fact.imageUrl,
      'ocr_text': fact.ocrText,
      'repetitions': fact.repetitions,
      'ease_factor': fact.easeFactor,
      'interval': fact.interval,
      'next_review_at': fact.nextReviewAt?.toIso8601String(),
      'created_at': fact.createdAt.toIso8601String(),
      'updated_at': fact.updatedAt.toIso8601String(),
    }).select().single();
    return response;
  }
  
  /// Update a fact
  static Future<void> updateFact(Fact fact) async {
    await client.from('facts').update({
      'content': fact.content,
      'subjects': fact.subjects,
      'repetitions': fact.repetitions,
      'ease_factor': fact.easeFactor,
      'interval': fact.interval,
      'next_review_at': fact.nextReviewAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', fact.id);
  }
  
  /// Delete a fact
  static Future<void> deleteFact(String id) async {
    await client.from('facts').delete().eq('id', id);
  }
  
  // ============ SYNC ============
  
  /// Sync local data to cloud (full push)
  static Future<void> syncToCloud(List<Source> sources, List<Fact> facts) async {
    if (!isSignedIn) return;
    
    // Upsert all sources
    for (final source in sources) {
      await client.from('sources').upsert({
        'id': source.id,
        'user_id': currentUser!.id,
        'name': source.name,
        'type': source.type.name,
        'created_at': source.createdAt.toIso8601String(),
        'updated_at': source.updatedAt.toIso8601String(),
      });
    }
    
    // Upsert all facts
    for (final fact in facts) {
      await client.from('facts').upsert({
        'id': fact.id,
        'user_id': currentUser!.id,
        'source_id': fact.sourceId,
        'content': fact.content,
        'subjects': fact.subjects,
        'image_url': fact.imageUrl,
        'ocr_text': fact.ocrText,
        'repetitions': fact.repetitions,
        'ease_factor': fact.easeFactor,
        'interval': fact.interval,
        'next_review_at': fact.nextReviewAt?.toIso8601String(),
        'created_at': fact.createdAt.toIso8601String(),
        'updated_at': fact.updatedAt.toIso8601String(),
      });
    }
  }
}
