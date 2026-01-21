import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, compute;
import 'package:http/http.dart' as http;
import '../models/fact.dart';
import 'secure_storage_service.dart';

/// Service for generating embeddings and finding related facts
class EmbeddingService {
  final String? apiKey;
  final EmbeddingProvider provider;
  
  // OpenAI settings
  static const String _openAiBaseUrl = 'https://api.openai.com/v1';
  static const String _openAiModel = 'text-embedding-3-small';
  
  // Hugging Face settings
  static const String _huggingFaceBaseUrl = 'https://api-inference.huggingface.co/models';
  static const String _huggingFaceModel = 'sentence-transformers/all-MiniLM-L6-v2';
  
  // CORS proxy for web (needed because HuggingFace doesn't support CORS)
  static const String _corsProxy = 'https://corsproxy.io/?';
  
  // Similarity threshold for considering facts "related"
  static const double similarityThreshold = 0.7;
  
  EmbeddingService({
    this.apiKey,
    this.provider = EmbeddingProvider.huggingface,
  });
  
  /// Check if API is configured
  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;
  
  /// Check if running on web (CORS limitations)
  bool get isWeb => kIsWeb;
  
  /// Generate embedding for a single text
  Future<List<double>?> generateEmbedding(String text) async {
    if (!isConfigured) return null;
    
    // Info message for web users
    if (isWeb && provider == EmbeddingProvider.huggingface) {
      print('ℹ️ Using CORS proxy for Hugging Face on web');
    }
    
    switch (provider) {
      case EmbeddingProvider.openai:
        return _generateOpenAiEmbedding(text);
      case EmbeddingProvider.huggingface:
        return _generateHuggingFaceEmbedding(text);
    }
  }
  
  /// Generate embedding using OpenAI API
  Future<List<double>?> _generateOpenAiEmbedding(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_openAiBaseUrl/embeddings'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _openAiModel,
          'input': text,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embedding = (data['data'][0]['embedding'] as List)
            .map((e) => (e as num).toDouble())
            .toList();
        return embedding;
      } else {
        print('OpenAI Embedding API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('OpenAI embedding generation failed: $e');
      return null;
    }
  }
  
  /// Generate embedding using Hugging Face Inference API
  Future<List<double>?> _generateHuggingFaceEmbedding(String text) async {
    try {
      // Use CORS proxy on web to bypass browser restrictions
      final baseUrl = '$_huggingFaceBaseUrl/$_huggingFaceModel';
      final url = isWeb 
          ? '$_corsProxy${Uri.encodeComponent(baseUrl)}'
          : baseUrl;
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': text,
          'options': {'wait_for_model': true},
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // HuggingFace returns the embedding directly as a list
        // For sentence-transformers, it returns a 2D array where we need the first element
        if (data is List && data.isNotEmpty) {
          if (data[0] is List) {
            // Handle nested array (sentence embedding)
            return (data[0] as List).map((e) => (e as num).toDouble()).toList();
          } else {
            // Direct array of numbers
            return data.map((e) => (e as num).toDouble()).toList();
          }
        }
        return null;
      } else if (response.statusCode == 503) {
        // Model is loading, wait and retry
        print('HuggingFace model loading, waiting...');
        await Future.delayed(const Duration(seconds: 2));
        return _generateHuggingFaceEmbedding(text);
      } else {
        print('HuggingFace Embedding API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      // Check if it's a CORS error on web
      if (isWeb && e.toString().contains('Failed to fetch')) {
        print('❌ CORS proxy error. The proxy service may be temporarily unavailable. Try again later or use OpenAI.');
      } else {
        print('HuggingFace embedding generation failed: $e');
      }
      return null;
    }
  }
  
  /// Generate embeddings for multiple texts (batch)
  /// Runs with minimal delay to avoid rate limits
  Future<List<List<double>?>> generateEmbeddingsBatch(List<String> texts) async {
    if (!isConfigured) return List.filled(texts.length, null);
    
    final results = <List<double>?>[];
    for (final text in texts) {
      final embedding = await generateEmbedding(text);
      results.add(embedding);
      // Minimal delay for rate limiting (reduced from 100ms)
      if (texts.length > 1) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
    return results;
  }
  
  /// Calculate cosine similarity between two embeddings (static for isolate use)
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0.0 || normB == 0.0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
  
  /// Find related facts based on embedding similarity
  /// Runs heavy computation in background isolate on non-web platforms
  Future<List<RelatedFact>> findRelatedFacts(
    Fact targetFact,
    List<Fact> allFacts, {
    int limit = 5,
    double threshold = similarityThreshold,
  }) async {
    if (targetFact.embedding == null) return [];
    
    // Use compute() on non-web platforms for background processing
    if (!kIsWeb) {
      return compute(
        _findRelatedFactsIsolate,
        _FindRelatedFactsParams(
          targetEmbedding: targetFact.embedding!,
          targetId: targetFact.id,
          factsData: allFacts
              .where((f) => f.embedding != null && f.id != targetFact.id)
              .map((f) => _FactEmbeddingData(id: f.id, embedding: f.embedding!, fact: f))
              .toList(),
          limit: limit,
          threshold: threshold,
        ),
      );
    }
    
    // Fallback for web (no isolate support)
    return _findRelatedFactsSync(
      targetFact.embedding!,
      targetFact.id,
      allFacts,
      limit,
      threshold,
    );
  }
  
  /// Synchronous version for web fallback
  List<RelatedFact> _findRelatedFactsSync(
    List<double> targetEmbedding,
    String targetId,
    List<Fact> allFacts,
    int limit,
    double threshold,
  ) {
    final results = <RelatedFact>[];
    
    for (final fact in allFacts) {
      if (fact.id == targetId) continue;
      if (fact.embedding == null) continue;
      
      final similarity = cosineSimilarity(targetEmbedding, fact.embedding!);
      
      if (similarity >= threshold) {
        results.add(RelatedFact(fact: fact, similarity: similarity));
      }
    }
    
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(limit).toList();
  }
  
  /// Find all facts without embeddings
  List<Fact> findFactsWithoutEmbeddings(List<Fact> facts) {
    return facts.where((f) => f.embedding == null).toList();
  }
}

/// Top-level function for compute() isolate
List<RelatedFact> _findRelatedFactsIsolate(_FindRelatedFactsParams params) {
  final results = <RelatedFact>[];
  
  for (final factData in params.factsData) {
    final similarity = EmbeddingService.cosineSimilarity(
      params.targetEmbedding,
      factData.embedding,
    );
    
    if (similarity >= params.threshold) {
      results.add(RelatedFact(fact: factData.fact, similarity: similarity));
    }
  }
  
  results.sort((a, b) => b.similarity.compareTo(a.similarity));
  return results.take(params.limit).toList();
}

/// Parameters for isolate function
class _FindRelatedFactsParams {
  final List<double> targetEmbedding;
  final String targetId;
  final List<_FactEmbeddingData> factsData;
  final int limit;
  final double threshold;
  
  _FindRelatedFactsParams({
    required this.targetEmbedding,
    required this.targetId,
    required this.factsData,
    required this.limit,
    required this.threshold,
  });
}

/// Lightweight data class for passing to isolate
class _FactEmbeddingData {
  final String id;
  final List<double> embedding;
  final Fact fact;
  
  _FactEmbeddingData({
    required this.id,
    required this.embedding,
    required this.fact,
  });
}

/// A fact with its similarity score
class RelatedFact {
  final Fact fact;
  final double similarity;
  
  RelatedFact({
    required this.fact,
    required this.similarity,
  });
  
  /// Similarity as percentage (0-100)
  int get similarityPercent => (similarity * 100).round();
}
