import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/fact.dart';

/// Service for generating embeddings and finding related facts
class EmbeddingService {
  final String? apiKey;
  final String baseUrl;
  final String model;
  
  // Similarity threshold for considering facts "related"
  static const double similarityThreshold = 0.7;
  
  EmbeddingService({
    this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'text-embedding-3-small',
  });
  
  /// Check if API is configured
  bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;
  
  /// Generate embedding for a single text
  Future<List<double>?> generateEmbedding(String text) async {
    if (!isConfigured) return null;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/embeddings'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
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
        print('Embedding API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Embedding generation failed: $e');
      return null;
    }
  }
  
  /// Generate embeddings for multiple texts (batch)
  Future<List<List<double>?>> generateEmbeddingsBatch(List<String> texts) async {
    if (!isConfigured) return List.filled(texts.length, null);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/embeddings'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'input': texts,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final embeddings = (data['data'] as List).map((item) {
          return (item['embedding'] as List)
              .map((e) => (e as num).toDouble())
              .toList();
        }).toList();
        return embeddings;
      }
    } catch (e) {
      print('Batch embedding generation failed: $e');
    }
    
    return List.filled(texts.length, null);
  }
  
  /// Calculate cosine similarity between two embeddings
  double cosineSimilarity(List<double> a, List<double> b) {
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
  List<RelatedFact> findRelatedFacts(
    Fact targetFact,
    List<Fact> allFacts, {
    int limit = 5,
    double threshold = similarityThreshold,
  }) {
    if (targetFact.embedding == null) return [];
    
    final results = <RelatedFact>[];
    
    for (final fact in allFacts) {
      // Skip self
      if (fact.id == targetFact.id) continue;
      // Skip facts without embeddings
      if (fact.embedding == null) continue;
      
      final similarity = cosineSimilarity(
        targetFact.embedding!,
        fact.embedding!,
      );
      
      if (similarity >= threshold) {
        results.add(RelatedFact(
          fact: fact,
          similarity: similarity,
        ));
      }
    }
    
    // Sort by similarity descending
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    
    // Return top N
    return results.take(limit).toList();
  }
  
  /// Find all facts without embeddings
  List<Fact> findFactsWithoutEmbeddings(List<Fact> facts) {
    return facts.where((f) => f.embedding == null).toList();
  }
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
